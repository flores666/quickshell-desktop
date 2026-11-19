pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/services"

Item {
    id: root

    Check { id: check }
    Until { id: ready }
    FileWait { id: written }
    Command { id: mode }

    readonly property string path: Quickshell.statePath("daily-notes.json")
    readonly property string past: "2024-06-01"
    readonly property string later: "2024-06-02"
    property string survivor: ""

    Component.onCompleted: {
        if (Quickshell.env("TEST_BIN") === "") {
            check.report("isolated runner required", false, "run tools/test.sh DailyNotesClearTest");
            check.done();
            return;
        }
        ready.until(DailyNotes.readyChanged, () => DailyNotes.ready, ok => {
            check.equal("clear service becomes ready", ok, true);
            if (ok)
                check.attempt("remove all categories", root.start);
            else
                check.done();
        });
    }

    function add(day: string, title: string, category: string): string {
        check.equal("fixture saves: " + title, DailyNotes.save(day, "", title, "", "", category), true);
        return DailyNotes.document.notes[0].id;
    }

    function start(): void {
        const empty = DailyNotes.document;
        check.equal("removing a missing category is rejected", DailyNotes.removeCategory("Work"), false);
        check.equal("rejected removal does not publish replacement state", DailyNotes.document, empty);
        DailyNotes.addCategory("Work");
        DailyNotes.addCategory("Temporary");
        DailyNotes.addCategory("Empty");
        root.add(root.past, "Old temporary task", "Temporary");
        const completed = root.add(root.later, "Completed temporary task", "Temporary");
        DailyNotes.toggleDone(completed);
        root.survivor = root.add(root.later, "Keep Work task", "Work");
        DailyNotes.toggleTracking(root.survivor);
        const nextId = DailyNotes.document.nextId;
        check.equal("category removal succeeds", DailyNotes.removeCategory("Temporary"), true);
        check.equal("removal preserves other tasks", DailyNotes.document.notes.map(note => note.id).join(","), root.survivor);
        check.equal("removal preserves surviving tracking", DailyNotes.trackedId, root.survivor);
        check.equal("removal preserves other categories", JSON.stringify(DailyNotes.categories), '["Work","Empty"]');
        check.equal("removal preserves identity counter", DailyNotes.document.nextId, nextId);
        const before = DailyNotes.document;
        check.equal("repeated removal is rejected", DailyNotes.removeCategory("Temporary"), false);
        check.equal("repeated removal preserves other task state", DailyNotes.document, before);
        root.failWrite();
    }

    function failWrite(): void {
        const before = JSON.stringify(DailyNotes.document);
        mode.run('chmod u-w "$1" && printf locked', [root.path], locked => {
            check.equal("clear fixture can be made read-only", locked, "locked");
            if (locked !== "locked") { check.done(); return; }
            check.equal("failed removal returns false", DailyNotes.removeCategory("Work"), false);
            check.equal("failed removal preserves history and tracking", JSON.stringify(DailyNotes.document), before);
            check.equal("failed removal leaves a visible error", DailyNotes.error !== "", true);
            Qt.callLater(() => mode.run('chmod u+w "$1" && printf unlocked', [root.path], unlocked => {
                check.equal("clear fixture is writable again", unlocked, "unlocked");
                check.attempt("remove retry", root.retry);
            }));
        });
    }

    function retry(): void {
        const nextId = DailyNotes.document.nextId;
        check.equal("removal succeeds on retry", DailyNotes.removeCategory("Work"), true);
        check.equal("removal clears tracking of a deleted task", DailyNotes.trackedId, "");
        check.equal("removed task no longer resolves", DailyNotes.find(root.survivor), null);
        check.equal("removal retry clears save error", DailyNotes.error, "");
        check.equal("no history remains after removing the last tasks", DailyNotes.days.length, 0);
        check.equal("no preview remains after removing the last tasks", DailyNotes.preview, null);
        check.equal("named empty category remains", JSON.stringify(DailyNotes.categories), '["Empty"]');
        check.equal("removing the last category succeeds", DailyNotes.removeCategory("Empty"), true);
        check.equal("no implicit category remains after removing the last one", DailyNotes.categories.length, 0);
        check.equal("no implicit card remains today", DailyNotes.todayChecklist.groups.length, 0);
        check.equal("cleared document remains valid", DailyNotes.validDocument(DailyNotes.document), true);
        const expected = JSON.stringify(DailyNotes.document);
        written.until(root.path, text => text === expected, text => {
            check.equal("cleared history, categories and tracking persist together", text, expected);
            check.equal("a task cannot recreate the retired category", DailyNotes.save(root.later, "", "Retry", "", ""), false);
            check.equal("a new category can be made after clearing", DailyNotes.addCategory("Work"), "Work");
            check.equal("new task uses the new named category", DailyNotes.save(root.later, "", "After clearing", "", "", "Work"), true);
            check.equal("clearing never reuses deleted identities", DailyNotes.document.notes[0].id, String(nextId));
            check.done();
        });
    }
}
