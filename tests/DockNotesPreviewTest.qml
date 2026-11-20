pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/components"
import "root:/modules/dock"
import "root:/services"

Item {
    id: root

    Check { id: check }
    Until { id: ready }

    Surface {
        id: surface

        DockNotesButton {
            id: button
            panel: surface
            screen: Quickshell.screens[0]
        }
    }

    function expectEmpty(label: string): void {
        check.equal(label + " uses the empty title", button.summary, "No tasks");
        check.equal(label + " uses the empty subtitle", button.progressText, "All caught up");
        check.equal(label + " has no progress arc", button.progress, 0);
        check.equal(label + " describes the empty state", button.tipText, "No tasks · All caught up");
    }

    function addNote(day: string, title: string): string {
        check.equal("task saves: " + title, DailyNotes.save(day, "", title, "", "", "Tasks"), true);
        return DailyNotes.document.notes[0].id;
    }

    function exercise(): void {
        const today = DailyNotes.today;
        const earlier = "2001-01-02";
        root.expectEmpty("an empty day");
        DailyNotes.addCategory(today, "Tasks");
        DailyNotes.addCategory(earlier, "Tasks");
        const historical = root.addNote(earlier, "Earlier task");
        check.equal("the service can still preview other dates", DailyNotes.preview?.id, historical);
        root.expectEmpty("a day with only an unfinished historical task");
        DailyNotes.toggleTracking(historical);
        root.expectEmpty("a day with a tracked historical task");

        const first = root.addNote(today, "First task");
        const second = root.addNote(today, "Second task");
        check.equal("a day with unfinished tasks honors manual tracking", button.summary, "Earlier task");
        DailyNotes.toggleTracking(historical);
        check.equal("the latest task appears in the miniature", button.summary, "Second task");
        DailyNotes.toggleDone(first);
        check.equal("an unfinished day still shows its checklist count", button.progressText, "1 of 2 done");
        check.near("an unfinished day still shows its progress arc", button.progress, 0.5);

        DailyNotes.toggleDone(second);
        root.expectEmpty("a completed day");
        DailyNotes.toggleDone(first);
        check.equal("reopening a task restores the task title", button.summary, "First task");
        check.near("reopening a task restores the arc", button.progress, 0.5);
        DailyNotes.remove(first);
        root.expectEmpty("a day after removing the last unfinished task");
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
