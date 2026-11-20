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
        check.equal("fixture saves: " + title, DailyNotes.save(day, "", title, "", category), true);
        return DailyNotes.document.notes[0].id;
    }

    function start(): void {
        const empty = DailyNotes.document;
        check.equal("removing a missing category is rejected", DailyNotes.removeCategory(root.later, "Work"), false);
        check.equal("rejected removal does not publish replacement state", DailyNotes.document, empty);
        DailyNotes.addCategory(root.later, "Work");
        DailyNotes.addCategory(root.later, "Temporary");
        DailyNotes.addCategory(root.later, "Empty");
        DailyNotes.addCategory(root.past, "Temporary");
        root.add(root.past, "Old temporary task", "Temporary");
        const completed = root.add(root.later, "Completed temporary task", "Temporary");
        DailyNotes.toggleDone(completed);
        root.survivor = root.add(root.later, "Keep Work task", "Work");
        const nextId = DailyNotes.document.nextId;
        check.equal("category removal succeeds", DailyNotes.removeCategory(root.later, "Temporary"), true);
        check.equal("removal preserves other tasks", DailyNotes.forDay(root.later).map(note => note.id).join(","), root.survivor);
        check.equal("removal preserves the selected category", DailyNotes.boardFor(root.later).quickCategory, "Work");
        check.equal("removal preserves other categories", JSON.stringify(DailyNotes.boardFor(root.later).categories), '["Work","Empty"]');
        check.equal("removal preserves identity counter", DailyNotes.document.nextId, nextId);
        const before = DailyNotes.document;
        check.equal("repeated removal is rejected", DailyNotes.removeCategory(root.later, "Temporary"), false);
        check.equal("repeated removal preserves other task state", DailyNotes.document, before);
        root.failWrite();
    }

    function failWrite(): void {
        const before = JSON.stringify(DailyNotes.document);
        mode.run('chmod u-w "$1" && printf locked', [root.path], locked => {
            check.equal("clear fixture can be made read-only", locked, "locked");
            if (locked !== "locked") { check.done(); return; }
            check.equal("failed removal returns false", DailyNotes.removeCategory(root.later, "Work"), false);
            check.equal("failed removal preserves history and selection", JSON.stringify(DailyNotes.document), before);
            check.equal("failed removal leaves a visible error", DailyNotes.error !== "", true);
            Qt.callLater(() => mode.run('chmod u+w "$1" && printf unlocked', [root.path], unlocked => {
                check.equal("clear fixture is writable again", unlocked, "unlocked");
                check.attempt("remove retry", root.retry);
            }));
        });
    }

    function retry(): void {
        const nextId = DailyNotes.document.nextId;
        check.equal("removal succeeds on retry", DailyNotes.removeCategory(root.later, "Work"), true);
        check.equal("removal clears selection of the deleted category", DailyNotes.boardFor(root.later).quickCategory, undefined);
        check.equal("removed task no longer resolves", DailyNotes.find(root.survivor), null);
        check.equal("removal retry clears save error", DailyNotes.error, "");
        check.equal("an empty category keeps its day navigable", DailyNotes.days.includes(root.later), true);
        check.equal("preview falls back to the other day", DailyNotes.preview?.day, root.past);
        check.equal("named empty category remains", JSON.stringify(DailyNotes.boardFor(root.later).categories), '["Empty"]');
        check.equal("removing the last category succeeds", DailyNotes.removeCategory(root.later, "Empty"), true);
        check.equal("no implicit category remains after removing the last one", DailyNotes.boardFor(root.later).categories.length, 0);
        check.equal("only the other day remains navigable", DailyNotes.days.join(","), root.past);
        check.equal("no implicit card remains today", DailyNotes.todayChecklist.groups.length, 0);
        check.equal("cleared document remains valid", DailyNotes.validDocument(DailyNotes.document), true);
        const expected = JSON.stringify(DailyNotes.document);
        written.until(root.path, text => text === expected, text => {
            check.equal("cleared history, categories and selection persist together", text, expected);
            check.equal("a task cannot recreate the retired category", DailyNotes.save(root.later, "", "Retry", ""), false);
            check.equal("a new category can be made after clearing", DailyNotes.addCategory(root.later, "Work"), "Work");
            check.equal("new task uses the new named category", DailyNotes.save(root.later, "", "After clearing", "", "Work"), true);
            check.equal("clearing never reuses deleted identities", DailyNotes.document.notes[0].id, String(nextId));
            check.done();
        });
    }
}
