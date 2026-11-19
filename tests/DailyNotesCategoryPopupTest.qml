pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"
import "root:/modules/common"
import "root:/modules/widgets"

Item {
    id: root

    Check { id: check }
    TestEvent { id: input }
    Until { id: ready }

    OverlaySurface {
        id: surface
        DailyNotesPanel { id: notes }
    }

    readonly property InputField entry: root.named("quickNote") as InputField
    readonly property Label destination: root.named("quickNoteDestination") as Label
    readonly property DailyNotesBoard board: root.find(notes.cardItem, item => item instanceof DailyNotesBoard) as DailyNotesBoard
    property int compactHeight: 0
    property var unscaledBoxes: []
    property real unscaledBoardHeight: 0
    Timer {
        id: settle
        property var then
        interval: Appearance.t.popupFade + Appearance.t.popupResize + Appearance.t.grace
        onTriggered: settle.then()
    }
    function afterLayout(then: var): void {
        settle.then = then;
        settle.restart();
    }

    function find(item: Item, matches: var): Item {
        if (!item || matches(item)) return item;
        for (const child of item.children) {
            const found = root.find(child, matches);
            if (found) return found;
        }
        return null;
    }
    function named(name: string): Item {
        return root.find(notes.cardItem, item => item.objectName === name);
    }
    function tile(category: string): DailyNoteCategory {
        return root.find(notes.cardItem, item => item instanceof DailyNoteCategory && item.category === category) as DailyNoteCategory;
    }
    function action(category: string, name: string): Item {
        return root.find(root.tile(category), item => item.objectName === name);
    }
    function click(item: Item): void {
        input.mouseClick(item, item.width / 2, item.height / 2, Qt.LeftButton, Qt.NoModifier, -1);
    }
    function focusWithin(item: Item): bool {
        for (let focus = item.Window.activeFocusItem; focus; focus = focus.parent) {
            if (focus === item) return true;
        }
        return false;
    }
    function paintedScale(card: Item): real {
        return (card.mapToItem(root.board, card.width, 0).x - card.mapToItem(root.board, 0, 0).x) / card.width;
    }
    function boxes(): var {
        return root.board.groups.map(group => {
            const card = root.tile(group.category);
            return [card.category, card.x, card.y, card.width, card.height];
        });
    }
    function emptyBoard(): void {
        check.equal("a fresh board is empty and asks for a category",
            root.board.keys.length === 0 && root.destination.text === "Create a category", true);
        root.entry.text = "First task";
        input.keyClick(Qt.Key_Return, Qt.NoModifier, -1);
        check.equal("Return without a category only preserves the draft",
            root.entry.text === "First task" && DailyNotes.document.notes.length === 0, true);
        root.click(root.named("newNoteCategory"));
        Qt.callLater(() => {
            const name = root.named("newNoteCategoryName") as DailyNoteComposer;
            name.text = "Inbox";
            check.equal("the retired category name cannot be created", name.canSave, false);
            name.text = "Project 0";
            input.keyClick(Qt.Key_Return, Qt.NoModifier, -1);
            check.equal("creating the first category does not select it", notes.targetCategory, "");
            check.equal("no destination label before the first selection", root.destination.visible, false);
            input.keyClick(Qt.Key_Return, Qt.NoModifier, -1);
            check.equal("an unselected first category creates no task", DailyNotes.document.notes.length, 0);
            root.afterLayout(() => {
                root.click(root.action("Project 0", "selectNoteDestination"));
                input.keyClick(Qt.Key_Return, Qt.NoModifier, -1);
                const first = DailyNotes.document.notes[0];
                check.equal("choosing the first category submits the retained draft", first?.title, "First task");
                if (first) DailyNotes.toggleDone(first.id);
                for (const category of ["Project 2", "Project 1"]) DailyNotes.addCategory(category);
                root.afterLayout(root.start);
            });
        });
    }
    function start(): void {
        check.equal("quick entry has no category dropdown", root.named("quickNoteCategory"), null);
        check.equal("the main notes card has no Clear All action", root.named("clearAllNotes"), null);
        check.equal("input is confined to the notes card", surface.mask.item, notes.cardItem);
        check.equal("the chosen category remains selected after adding and completing a task", root.destination.text, "To Project 0");
        check.equal("task entry has the requested placeholder", root.entry.placeholder, "Type to add new task");
        check.equal("the destination label is muted", root.destination.muted, true);
        check.equal("compact content leaves screen room", notes.cardHeight < notes.height, true);
        root.compactHeight = notes.cardHeight;
        check.equal("category cards have no add button", root.named("addNoteInCategory"), null);
        const target = root.action("Project 2", "selectNoteDestination") as IconButton;
        check.equal("card, header and target use the default arrow", [root.tile("Project 2"),
            root.action("Project 2", "dragNoteCategory") as Clickable, target].every(control => control.cursorShape === Qt.ArrowCursor), true);
        root.click(target);
        Overlay.close();
        root.afterLayout(() => {
            Overlay.open(Overlay.dailyNotes, Overlay.screen, Overlay.anchorXOf[Overlay.dailyNotes]);
            root.afterLayout(root.emptySelected);
        });
    }
    function emptySelected(): void {
        check.equal("reopening preserves the category selected with an empty draft", notes.targetCategory, "Project 2");
        check.equal("the static destination label follows selection", root.destination.text, "To Project 2");
        check.equal("only the chosen target is accented", (root.action("Project 2", "selectNoteDestination") as IconButton).accented
            && !(root.action("Project 0", "selectNoteDestination") as IconButton).accented, true);
        check.equal("empty entry has no scaled destination", root.board.focusedCategory, null);
        check.near("chosen card stays unscaled before typing", root.paintedScale(root.tile("Project 2")), 1);
        check.near("other cards stay unscaled before typing", root.paintedScale(root.tile("Project 1")), 1);
        root.unscaledBoxes = root.boxes();
        root.unscaledBoardHeight = root.board.height;
        input.keyClick(Qt.Key_K, Qt.NoModifier, -1);
        root.afterLayout(root.selected);
    }
    function selected(): void {
        check.equal("the first key leaves card geometry unchanged", JSON.stringify(root.boxes()), JSON.stringify(root.unscaledBoxes));
        check.near("typing leaves board height unchanged", root.board.height, root.unscaledBoardHeight);
        check.equal("typing leaves popup height unchanged", notes.cardHeight, root.compactHeight);
        check.equal("the board follows the selected destination", root.board.focusedCategory, "Project 2");
        check.equal("the selected card grows", root.paintedScale(root.tile("Project 2")) > 1, true);
        check.equal("other cards shrink", root.paintedScale(root.tile("Project 1")) < 1, true);
        check.equal("typing reaches the focused task input", root.entry.text.toLowerCase() === "k" && root.entry.input.activeFocus, true);
        root.entry.text = "Keep my typed draft";
        root.click(root.action("Project 2", "dragNoteCategory"));
        root.afterLayout(() => {
            check.equal("choosing the same card keeps the selection", notes.targetCategory, "Project 2");
            check.equal("typing still scales the selected destination", root.board.focusedCategory, "Project 2");
            root.click(root.action("Project 1", "dragNoteCategory"));
            root.afterLayout(() => {
                check.equal("the bottom card scales in place", root.paintedScale(root.tile("Project 1")) > 1, true);
                check.near("zooming the bottom card keeps the popup height", notes.cardHeight, root.compactHeight);
                input.keyClick(Qt.Key_Return, Qt.NoModifier, -1);
                check.equal("Enter saves in the selected category", DailyNotes.document.notes[0].category, "Project 1");
                check.equal("successful save clears only the task text", root.entry.text, "");
                root.createCategory();
            });
        });
    }
    function createCategory(): void {
        root.entry.text = "Category task";
        root.click(root.named("newNoteCategory"));
        Qt.callLater(() => {
            const name = root.named("newNoteCategoryName") as InputField;
            check.equal("new category opens a focused name field", name?.input.activeFocus, true);
            check.equal("category creation has no category list",
                root.find(notes.cardItem, item => item instanceof DailyNoteCategoryPicker), null);
            if (!name) { check.done(); return; }
            input.keyClick(Qt.Key_Tab, Qt.NoModifier, -1);
            check.equal("Tab stays in an empty category name", name.input.activeFocus, true);
            name.text = "  Work  ";
            let contained = true;
            let reachedSave = false;
            for (let i = 0; i < 8; ++i) {
                const tab = i < 4;
                input.keyClick(tab ? Qt.Key_Tab : Qt.Key_Backtab, tab ? Qt.NoModifier : Qt.ShiftModifier, -1);
                contained = contained && root.focusWithin(name);
                reachedSave = reachedSave || (tab && !name.input.activeFocus);
            }
            check.equal("Tab and Backtab stay within category name and save", contained && reachedSave, true);
            name.input.forceActiveFocus();
            input.keyClick(Qt.Key_Enter, Qt.KeypadModifier, -1);
            check.equal("Enter creates the trimmed category without changing destination", DailyNotes.categories.includes("Work")
                && DailyNotes.document.quickCategory === "Project 1" && root.destination.text === "To Project 1", true);
            check.equal("creation restores task draft and focus", Overlay.menu === null
                && root.entry.text === "Category task" && root.entry.input.activeFocus, true);
            root.afterLayout(() => {
                root.click(root.action("Work", "dragNoteCategory"));
                input.keyClick(Qt.Key_Return, Qt.NoModifier, -1);
                check.equal("explicitly choosing the new category routes the task", DailyNotes.document.notes[0].category, "Work");
                root.afterLayout(root.deleteEmpty);
            });
        });
    }
    function deleteEmpty(): void {
        root.entry.text = "Keep my typed draft";
        root.click(root.action("Project 2", "dragNoteCategory"));
        root.click(root.action("Project 2", "deleteNoteCategory"));
        check.equal("one click removes an empty category", DailyNotes.categories.includes("Project 2"), false);
        check.equal("category deletion has no confirmation", Overlay.menu, null);
        check.equal("deleting a chosen category returns to the last addition", notes.targetCategory, "Work");
        check.equal("deletion keeps the draft and task focus", root.entry.text === "Keep my typed draft"
            && root.entry.input.activeFocus, true);
        const day = "2024-06-01";
        DailyNotes.save(day, "", "Older Work task", "", "", "Work");
        const id = DailyNotes.document.notes[0].id;
        DailyNotes.toggleTracking(id);
        notes.showDay(day);
        root.afterLayout(() => {
            root.click(root.action("Work", "deleteNoteCategory"));
            check.equal("one click removes category tasks across dates",
                DailyNotes.document.notes.some(note => note.category === "Work"), false);
            check.equal("deleting its latest task restores the previous destination", notes.targetCategory, "Project 1");
            check.equal("deletion preserves the current date", notes.day, day);
            check.equal("the emptied date remains navigable", notes.days.includes(day), true);
            check.equal("deletion releases historical tracking", DailyNotes.find(id) === null && DailyNotes.trackedId === "", true);
            root.editDraft();
        });
    }

    function editDraft(): void {
        DailyNotes.addCategory("Draft category");
        DailyNotes.save(notes.day, "", "Keep editing", "", "", "Project 1");
        const id = DailyNotes.document.notes[0].id;
        notes.editTask(id);
        root.afterLayout(() => {
            const title = root.named("noteTitle") as InputField;
            title.text = "Keep my unsaved edit";
            root.click(root.named("editNoteCategory"));
            Qt.callLater(() => {
                const picker = root.find(notes.cardItem, item => item instanceof DailyNoteCategoryPicker) as DailyNoteCategoryPicker;
                check.equal("the editor lists only real categories", JSON.stringify(picker?.matches),
                    JSON.stringify(DailyNotes.categories));
                Overlay.dismissOnEscape();
                check.equal("closing the editor picker returns title focus", title.input.activeFocus, true);
                root.click(root.named("editNoteCategory"));
                Qt.callLater(() => root.removeEditCategory(id, title));
            });
        });
    }

    function removeEditCategory(id: string, title: InputField): void {
        const search = root.named("noteCategorySearch") as InputField;
        search.text = "Draft category";
        input.keyClick(Qt.Key_Return, Qt.NoModifier, -1);
        check.equal("the editor can choose another category", notes.editCategory, "Draft category");
        DailyNotes.removeCategory("Draft category");
        check.equal("deleting an edit destination returns to the saved category", notes.editCategory, "Project 1");
        check.equal("unsaved edits survive unrelated category deletion", notes.draft?.id === id
            && title.text === "Keep my unsaved edit" && title.input.activeFocus, true);
        DailyNotes.addCategory("Remove edited task");
        DailyNotes.save(notes.day, id, "Keep editing", "", "", "Remove edited task");
        DailyNotes.removeCategory("Remove edited task");
        check.equal("removed edited task releases its stale draft", notes.draft, null);
        root.afterLayout(() => {
            check.equal("removing an edited task restores the composer's draft and focus", Overlay.menu === null && notes.shown
                && root.entry.input.activeFocus && root.entry.text === "Keep my typed draft", true);
            notes.showDay(DailyNotes.today);
            root.afterLayout(root.grow);
        });
    }

    function grow(): void {
        root.compactHeight = notes.cardHeight;
        DailyNotes.addCategory("Long category");
        const text = "Review the release plan and complete all remaining documentation before the meeting. ".repeat(8);
        for (let i = 0; i < 24; ++i)
            DailyNotes.save(notes.day, "", text + i, "", "", "Long category");
        root.afterLayout(() => {
            check.equal("task content grows the popup", notes.cardHeight > root.compactHeight, true);
            check.near("overflow is capped only at available screen height", notes.cardHeight, notes.height);
            const scroll = root.find(notes.cardItem, item => item instanceof DailyNotesScroll && item.visible) as DailyNotesScroll;
            check.equal("screen-limited content remains scrollable", scroll.contentHeight > scroll.height, true);
            const top = notes.cardItem.mapToItem(notes, 0, 0).y;
            check.equal("the capped card remains inside the available screen", top >= -0.001
                && top + notes.cardItem.height <= notes.height + 0.001, true);
            DailyNotes.removeCategory("Long category");
            root.afterLayout(() => {
                check.near("shrinking restores the content height", notes.cardHeight, root.compactHeight);
                check.done();
            });
        });
    }
    Component.onCompleted: {
        if (Quickshell.env("TEST_BIN") === "") {
            check.report("isolated runner required", false, "run tools/test.sh DailyNotesCategoryPopupTest");
            check.done();
            return;
        }
        ready.until(DailyNotes.readyChanged, () => DailyNotes.ready, ok => {
            check.equal("daily notes becomes ready", ok, true);
            if (!ok) { check.done(); return; }
            const screen = Quickshell.screens[0];
            Overlay.open(Overlay.dailyNotes, screen, screen.width / 2);
            root.afterLayout(root.emptyBoard);
        });
    }
}
