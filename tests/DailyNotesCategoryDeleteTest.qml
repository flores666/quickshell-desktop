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
    property string workTask: ""
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
        check.equal("fixture saves: " + title, DailyNotes.save(day, "", title, "", category), true);
        return DailyNotes.document.notes[0].id;
    }

    function start(): void {
        DailyNotes.addCategory(root.past, "Personal");
        DailyNotes.addCategory(root.past, "Work");
        DailyNotes.addCategory(root.past, "Empty");
        DailyNotes.addCategory(root.later, "Personal");
        DailyNotes.addCategory(root.later, "Work");
        root.workTask = root.add(root.past, "Past work task", "Work");
        DailyNotes.toggleDone(root.add(root.past, "Completed past task", "Work"));
        DailyNotes.toggleDone(root.add(root.later, "Completed later task", "Work"));
        root.survivor = root.add(root.later, "Keep this task", "Personal");
        root.add(root.past, "Older personal task", "Personal");
        const before = JSON.stringify(DailyNotes.document);
        check.equal("the first category becomes the saved destination", DailyNotes.boardFor(root.past).quickCategory, "Personal");
        check.equal("an unknown category cannot become the destination", DailyNotes.selectCategory(root.past, "Missing"), false);
        check.equal("blank category cannot be deleted", DailyNotes.removeCategory(root.past, ""), false);
        check.equal("unknown category cannot be deleted", DailyNotes.removeCategory(root.past, "Missing"), false);
        check.equal("category keys are exact", DailyNotes.removeCategory(root.past, "work"), false);
        check.equal("rejected deletions preserve all data", JSON.stringify(DailyNotes.document), before);
        check.equal("empty categories can be deleted", DailyNotes.removeCategory(root.past, "Empty"), true);
        check.equal("empty category is removed", DailyNotes.boardFor(root.past).categories.includes("Empty"), false);
        check.equal("removing an empty category preserves unrelated tasks", DailyNotes.find(root.workTask)?.category, "Work");
        check.equal("choosing another category succeeds without adding a task", DailyNotes.selectCategory(root.past, "Work"), true);
        const expected = JSON.stringify(DailyNotes.document);
        written.until(root.path, text => text === expected, text => {
            check.equal("the choice is written to the notes file immediately", text, expected);
            DailyNotes.load();
            check.equal("loading the notes restores that choice", DailyNotes.targetCategory(root.past), "Work");
            check.equal("choice does not cross dates", DailyNotes.targetCategory(root.later), "Personal");
            root.failWrite();
        });
    }

    function failWrite(): void {
        const before = JSON.stringify(DailyNotes.document);
        mode.run('chmod u-w "$1" && printf locked', [root.path], locked => {
            check.equal("category fixture can be made read-only", locked, "locked");
            if (locked !== "locked") { check.done(); return; }
            check.equal("choosing the same category needs no write", DailyNotes.selectCategory(root.past, "Work"), true);
            check.equal("a failed selection retains the previous destination", DailyNotes.selectCategory(root.past, "Personal"), false);
            check.equal("the previously saved destination remains active", DailyNotes.targetCategory(root.past), "Work");
            check.equal("failed atomic deletion is reported", DailyNotes.removeCategory(root.past, "Work"), false);
            check.equal("failed deletion preserves category, history and selection", JSON.stringify(DailyNotes.document), before);
            check.equal("failed category remains selectable", DailyNotes.boardFor(root.past).categories.includes("Work"), true);
            check.equal("failed deletion leaves an error", DailyNotes.error !== "", true);
            Qt.callLater(() => mode.run('chmod u+w "$1" && printf unlocked', [root.path], unlocked => {
                check.equal("category fixture is writable again", unlocked, "unlocked");
                check.attempt("category deletion retry", root.remove);
            }));
        });
    }

    function remove(): void {
        const nextId = DailyNotes.document.nextId;
        check.equal("category deletion succeeds after retry", DailyNotes.removeCategory(root.past, "Work"), true);
        check.equal("deleted category is unavailable", DailyNotes.boardFor(root.past).categories.includes("Work"), false);
        check.equal("deleting the chosen category clears the saved choice", DailyNotes.boardFor(root.past).quickCategory, undefined);
        check.equal("the most recent surviving task supplies the next destination", DailyNotes.targetCategory(root.past), "Personal");
        check.equal("all tasks in the deleted category are removed on the selected date",
            DailyNotes.forDay(root.past).some(note => note.category === "Work"), false);
        check.equal("a same-name category on another date keeps its completed task",
            DailyNotes.forDay(root.later).find(note => note.category === "Work")?.done, true);
        check.equal("the deleted task identity no longer resolves", DailyNotes.find(root.workTask), null);
        check.equal("other categories survive", DailyNotes.document.notes.length, 3);
        check.equal("other task identity survives", DailyNotes.find(root.survivor)?.title, "Keep this task");
        check.equal("identity counter never rewinds", DailyNotes.document.nextId, nextId);
        check.equal("successful deletion clears write error", DailyNotes.error, "");
        check.equal("deletion preserves document validity", DailyNotes.validDocument(DailyNotes.document), true);
        check.equal("deleted categories cannot accept stale saves",
            DailyNotes.save(root.past, "", "Stale task", "", "Work"), false);
        const expected = JSON.stringify(DailyNotes.document);
        written.until(root.path, text => text === expected, text => {
            check.equal("category deletion is persisted together", text, expected);
            check.done();
        });
    }
}
