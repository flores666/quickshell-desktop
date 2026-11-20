pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Quickshell
import "root:/components"
import "root:/config"
import "root:/modules/common"
import "root:/modules/widgets"
import "root:/services"

Item {
    id: root

    Check { id: check }
    Until { id: until }
    TestEvent { id: input }

    OverlaySurface {
        DailyNotesPanel { id: notes }
    }

    readonly property InputField entry: root.find(notes.cardItem, item => item.objectName === "quickNote") as InputField
    readonly property DailyNoteCategory work: root.find(notes.cardItem, item =>
        item instanceof DailyNoteCategory && item.category === "Work") as DailyNoteCategory
    readonly property DailyNotesScroll scroll: root.find(notes.cardItem, item => item instanceof DailyNotesScroll) as DailyNotesScroll
    readonly property bool readyForInput: notes.cardItem.rolled === 1 && (root.entry?.input.activeFocus ?? false)
    property real peak

    function find(item: Item, matches: var): Item {
        if (!item || matches(item)) return item;
        for (const child of item.children) {
            const found = root.find(child, matches);
            if (found) return found;
        }
        return null;
    }

    function row(title: string): DailyNoteRow {
        return root.find(notes.cardItem, item => item instanceof DailyNoteRow && item.note?.title === title) as DailyNoteRow;
    }

    function paintedScale(row: DailyNoteRow): real {
        return (row.mapToItem(row.parent, row.width, 0).x - row.mapToItem(row.parent, 0, 0).x) / row.width;
    }

    function submit(title: string): void {
        root.entry.text = title;
        input.keyClick(Qt.Key_Return, Qt.NoModifier, -1);
    }

    function start(): void {
        const previous = root.row("Previous task");
        const y = previous.y;
        root.submit("New task");
        check.equal("Return saves the task in the selected category", DailyNotes.document.notes[0]?.title, "New task");
        until.until(root.work.insertionProgressChanged, () => root.work.insertionRow !== null
            && root.work.insertionProgress >= root.work.insertionRise, ok => {
            check.equal("the insertion reaches its peak", ok, true);
            if (!ok) { check.done(); return; }
            const added = root.row("New task");
            const far = root.row("Earlier task");
            root.peak = root.paintedScale(added);
            check.equal("the saved row is the center of the destination category's lens", root.work.insertionRow, added);
            check.equal("the peak magnifies the added row most",
                root.peak > root.paintedScale(previous) && root.paintedScale(previous) > root.paintedScale(far), true);
            const distance = (added.y + added.height / 2 - previous.y - previous.height / 2) / Appearance.m.dailyNotesInsertionSpread;
            check.near("neighbor magnification follows the Gaussian", (root.paintedScale(previous) - 1) / (root.peak - 1),
                Math.exp(-distance * distance / 2));
            check.near("the other category stays unscaled", root.paintedScale(root.row("Other task")), 1);
            check.near("the existing task keeps its layout position", previous.y, y);
            check.near("a compact board stays at the top during the resize", root.scroll.viewport.contentY, root.scroll.viewport.originY);
            check.equal("the composer keeps focus", root.entry.input.activeFocus, true);
            root.measureTail(added);
        });
    }

    function measureTail(added: DailyNoteRow): void {
        until.until(root.work.insertionProgressChanged, () => root.work.insertionProgress >= 0.7, ok => {
            const scale = root.paintedScale(added);
            check.equal("the scale settles with no overshoot", ok && scale >= 1 && scale < root.peak, true);
            until.until(root.work.insertionRowChanged, () => root.work.insertionRow === null, settled => {
                check.equal("the effect releases the row", settled, true);
                check.near("the saved row returns to its natural scale", root.paintedScale(added), 1);
                Qt.callLater(root.rapidInsert);
            });
        });
    }

    function rapidInsert(): void {
        root.submit("Rapid first");
        root.submit("Rapid second");
        const id = DailyNotes.document.notes[0].id;
        Qt.callLater(() => {
            check.equal("successive submissions center on the latest task", root.work.insertionRow?.note?.id, id);
            DailyNotes.remove(id);
            check.equal("deleting the new task clears its animation", root.work.insertionRow, null);
            Settings.setOverride("hyprAnimations", 0);
            root.submit("Without motion");
            Qt.callLater(() => {
                check.equal("disabling animation leaves the added task at rest", root.work.insertionRow, null);
                check.near("the task still appears at its natural scale", root.paintedScale(root.row("Without motion")), 1);
                check.done();
            });
        });
    }

    Component.onCompleted: {
        if (Quickshell.env("TEST_BIN") === "") {
            check.report("isolated runner required", false, "run tools/test.sh DailyNotesInsertionTest");
            check.done();
            return;
        }
        until.until(DailyNotes.readyChanged, () => DailyNotes.ready, ok => {
            check.equal("daily notes becomes ready", ok, true);
            if (!ok) { check.done(); return; }
            const day = DailyNotes.today;
            DailyNotes.addCategory(day, "Work");
            DailyNotes.addCategory(day, "Other");
            for (const title of ["Earlier task", "Previous task"])
                DailyNotes.save(day, "", title, "", "Work");
            DailyNotes.save(day, "", "Other task", "", "Other");
            DailyNotes.selectCategory(day, "Work");
            const screen = Quickshell.screens[0];
            Overlay.open(Overlay.dailyNotes, screen, screen.width / 2);
            until.until(root.readyForInputChanged, () => root.readyForInput, ready => {
                check.equal("the notes panel is ready for input", ready, true);
                if (ready) Qt.callLater(root.start);
                else check.done();
            });
        });
    }
}
