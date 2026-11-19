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
    property string tracked: ""
    property string survivor: ""

    Component.onCompleted: {
        if (Quickshell.env("TEST_BIN") === "") {
            check.report("isolated runner required", false, "run tools/test.sh DailyNotesCategoryDeleteTest");
            check.done();
            return;
        }
        ready.until(DailyNotes.readyChanged, () => DailyNotes.ready, ok => {
            check.equal("category deletion service becomes ready", ok, true);
            if (ok)
                check.attempt("category deletion", root.start);
            else
                check.done();
        });
    }

    function add(day: string, title: string, category: string): string {
        check.equal("fixture saves: " + title, DailyNotes.save(day, "", title, "", "", category), true);
        return DailyNotes.document.notes[0].id;
    }

    function start(): void {
        DailyNotes.addCategory("Work");
        DailyNotes.addCategory("Empty");
        DailyNotes.addCategory("Personal");
        root.tracked = root.add(root.past, "Tracked past task", "Work");
        DailyNotes.toggleTracking(root.tracked);
        const completed = root.add(root.later, "Completed later task", "Work");
        DailyNotes.toggleDone(completed);
        root.survivor = root.add(root.later, "Keep this task", "Personal");
        root.add(root.past, "Older personal task", "Personal");
        const before = JSON.stringify(DailyNotes.document);
        check.equal("without a saved choice the newest task supplies the destination", DailyNotes.targetCategory, "Personal");
        check.equal("an unknown category cannot become the destination", DailyNotes.selectCategory("Missing"), false);
        check.equal("blank category cannot be deleted", DailyNotes.removeCategory(""), false);
        check.equal("unknown category cannot be deleted", DailyNotes.removeCategory("Missing"), false);
        check.equal("category keys are exact", DailyNotes.removeCategory("work"), false);
        check.equal("rejected deletions preserve all data", JSON.stringify(DailyNotes.document), before);
        check.equal("empty categories can be deleted", DailyNotes.removeCategory("Empty"), true);
        check.equal("empty category is removed", DailyNotes.categories.includes("Empty"), false);
        check.equal("unrelated tracked task is preserved", DailyNotes.trackedId, root.tracked);
        check.equal("choosing a category succeeds without adding a task", DailyNotes.selectCategory("Work"), true);
        const expected = JSON.stringify(DailyNotes.document);
        written.until(root.path, text => text === expected, text => {
            check.equal("the choice is written to the notes file immediately", text, expected);
            DailyNotes.load();
            check.equal("loading the notes restores that choice", DailyNotes.targetCategory, "Work");
            root.failWrite();
        });
    }

    function failWrite(): void {
        const before = JSON.stringify(DailyNotes.document);
        mode.run('chmod u-w "$1" && printf locked', [root.path], locked => {
            check.equal("category fixture can be made read-only", locked, "locked");
            if (locked !== "locked") { check.done(); return; }
            check.equal("choosing the same category needs no write", DailyNotes.selectCategory("Work"), true);
            check.equal("a failed selection retains the previous destination", DailyNotes.selectCategory("Personal"), false);
            check.equal("the previously saved destination remains active", DailyNotes.targetCategory, "Work");
            check.equal("failed atomic deletion is reported", DailyNotes.removeCategory("Work"), false);
            check.equal("failed deletion preserves category, history and tracking", JSON.stringify(DailyNotes.document), before);
            check.equal("failed category remains selectable", DailyNotes.categories.includes("Work"), true);
            check.equal("failed deletion leaves an error", DailyNotes.error !== "", true);
            Qt.callLater(() => mode.run('chmod u+w "$1" && printf unlocked', [root.path], unlocked => {
                check.equal("category fixture is writable again", unlocked, "unlocked");
                check.attempt("category deletion retry", root.remove);
            }));
        });
    }

    function remove(): void {
        const nextId = DailyNotes.document.nextId;
        check.equal("category deletion succeeds after retry", DailyNotes.removeCategory("Work"), true);
        check.equal("deleted category is unavailable", DailyNotes.categories.includes("Work"), false);
        check.equal("deleting the chosen category clears the saved choice", DailyNotes.document.quickCategory, undefined);
        check.equal("the most recent surviving task supplies the next destination", DailyNotes.targetCategory, "Personal");
        check.equal("all dates and completion states are removed",
            DailyNotes.document.notes.some(note => note.category === "Work"), false);
        check.equal("deleted tracked identity no longer resolves", DailyNotes.find(root.tracked), null);
        check.equal("category deletion clears its tracked task", DailyNotes.trackedId, "");
        check.equal("other categories survive", DailyNotes.document.notes.length, 2);
        check.equal("other task identity survives", DailyNotes.find(root.survivor)?.title, "Keep this task");
        check.equal("identity counter never rewinds", DailyNotes.document.nextId, nextId);
        check.equal("successful deletion clears write error", DailyNotes.error, "");
        check.equal("deletion preserves document validity", DailyNotes.validDocument(DailyNotes.document), true);
        check.equal("deleted categories cannot accept stale saves",
            DailyNotes.save(root.past, "", "Stale task", "", "", "Work"), false);
        const expected = JSON.stringify(DailyNotes.document);
        written.until(root.path, text => text === expected, text => {
            check.equal("category deletion is persisted together", text, expected);
            check.done();
        });
    }
}
