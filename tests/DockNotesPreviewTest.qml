pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/components"
import "root:/config"
import "root:/modules/dock"
import "root:/modules/widgets"
import "root:/services"

Item {
    id: root

    Check { id: check }
    Until { id: ready }
    readonly property Rectangle progressRing: button.children.find(child => child.objectName === "notesProgressRing") as Rectangle

    Surface {
        id: surface

        DockNotesButton {
            id: button
            panel: surface
            screen: Quickshell.screens[0]
        }
    }

    Repeater {
        model: ScriptModel { values: DailyNotes.document.notes.map(note => note.id) }

        DailyNoteRow {
            required property string modelData

            note: DailyNotes.find(this.modelData)
        }
    }

    function pinVisible(id: string): bool {
        const row = root.children.find(child => child instanceof DailyNoteRow && child.note?.id === id);
        return row?.children.find(child => child instanceof Icon && child.name === "pin")?.visible ?? false;
    }

    function expectCaughtUp(label: string, progress: real): void {
        check.equal(label + " uses the empty title", button.summary, "No tasks");
        check.equal(label + " uses the empty subtitle", button.progressText, "All caught up");
        check.near(label + " shows the expected progress arc", button.progress, progress);
        check.equal(label + " describes the empty state", button.tipText, "No tasks · All caught up");
    }

    function addNote(day: string, title: string): string {
        check.equal("task saves: " + title, DailyNotes.save(day, "", title, "", "Tasks"), true);
        return DailyNotes.document.notes[0].id;
    }

    function exercise(): void {
        const today = DailyNotes.today;
        const earlier = "2001-01-02";
        root.expectCaughtUp("an empty day", 0);
        check.equal("an empty day leaves the right circle unfilled", root.progressRing.color.a, 0);
        DailyNotes.addCategory(today, "Tasks");
        DailyNotes.addCategory(earlier, "Tasks");
        const historical = root.addNote(earlier, "Earlier task");
        check.equal("the service can still preview other dates", DailyNotes.preview?.id, historical);
        root.expectCaughtUp("a day with only an unfinished historical task", 0);
        check.equal("a task absent from the miniature has no pin", root.pinVisible(historical), false);

        const first = root.addNote(today, "First task");
        const second = root.addNote(today, "Second task");
        check.equal("the latest task in today's category appears in the miniature", button.summary, "Second task");
        check.equal("the selected category suppresses the task pin", root.pinVisible(second), false);
        DailyNotes.toggleDone(first);
        check.equal("an unfinished day still shows its checklist count", button.progressText, "1 of 2 done");
        check.near("an unfinished day still shows its progress arc", button.progress, 0.5);

        DailyNotes.toggleDone(second);
        root.expectCaughtUp("a completed day", 1);
        check.equal("a completed day leaves the center of the ring unfilled", root.progressRing.color.a, 0);
        check.sameColor("the fill uses the system accent hue", Qt.alpha(button.completionFill, 1), Appearance.c.accent, 0);
        check.equal("the accent fill is translucent", button.completionFill.a > 0 && button.completionFill.a < 1, true);
        check.equal("the pin is hidden when the miniature has no task", root.pinVisible(second), false);
        DailyNotes.toggleDone(first);
        check.equal("reopening a task restores the task title", button.summary, "First task");
        check.near("reopening a task restores the arc", button.progress, 0.5);
        DailyNotes.remove(first);
        root.expectCaughtUp("a day after removing the last unfinished task", 1);
        root.exerciseCategory(today);
    }

    function exerciseCategory(today: string): void {
        const current = root.addNote(today, "Task in the selected category");
        DailyNotes.addCategory(today, "Other");
        check.equal("task saves in another category", DailyNotes.save(today, "", "Newest task in another category", "", "Other"), true);
        const other = DailyNotes.document.notes[0].id;
        check.equal("adding another category preserves the selected category", DailyNotes.targetCategory(today), "Tasks");
        check.equal("the miniature stays with the selected category", button.note?.id, current);
        check.equal("the selected category's preview has no pin", root.pinVisible(current), false);
        check.equal("a newer task outside the selected category has no pin", root.pinVisible(other), false);

        DailyNotes.selectCategory(today, "Other");
        check.equal("changing the category changes the miniature", button.note?.id, other);
        check.equal("the new category's preview also has no pin", root.pinVisible(other), false);
        DailyNotes.toggleDone(other);
        check.equal("completing the selected category restores the general preview", button.note?.id, current);
        check.equal("the pin stays hidden while the completed category remains selected", root.pinVisible(current), false);

        check.equal("removing the selected category succeeds", DailyNotes.removeCategory(today, "Other"), true);
        check.equal("without a selected category the preview has a pin", root.pinVisible(current), true);
        DailyNotes.toggleDone(current);
        root.expectCaughtUp("a completed day without a selected category", 1);
        check.equal("the pin disappears with the preview", root.pinVisible(current), false);
    }

    Component.onCompleted: {
        if (Quickshell.env("TEST_BIN") === "") {
            check.report("isolated test runner required", false, "run tools/test.sh DockNotesPreviewTest");
            check.done();
            return;
        }
        ready.until(DailyNotes.readyChanged, () => DailyNotes.ready, ok => {
            check.equal("notes are loaded", ok, true);
            if (ok)
                check.attempt("dock notes preview", root.exercise);
            check.done();
        });
    }
}
