pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/services"

/*! Exercise the production service and its private state file through the
    runner. Dates are fixed so history and ordering do not depend on midnight. */
Item {
    id: root

    Check { id: check }
    Until { id: ready }
    FileWait { id: written }
    Command { id: mode }
    readonly property string path: Quickshell.statePath("daily-notes.json")
    readonly property string earlier: "2024-02-29"
    readonly property string later: "2024-03-01"
    property string firstId: ""
    property string secondId: ""
    property string thirdId: ""
    property string newestId: ""

    Component.onCompleted: {
        if (Quickshell.env("TEST_BIN") === "") {
            check.report("isolated test runner required", false, "run tools/test.sh DailyNotesTest");
            check.done();
            return;
        }
        ready.until(DailyNotes.readyChanged, () => DailyNotes.ready, ok => {
            check.equal("new service becomes ready", ok, true);
            if (!ok) { check.done(); return; }
            check.attempt("daily notes operations", root.start);
        });
    }

    function parse(text: string): var {
        try { return JSON.parse(text); } catch (e) { return null; }
    }

    function unchanged(label: string, before: string): void {
        check.equal(label, JSON.stringify(DailyNotes.document), before);
    }

    function start(): void {
        check.equal("new document has no read error", DailyNotes.error, "");
        check.equal("new document has no notes", DailyNotes.document.notes.length, 0);
        check.equal("new document begins with identity one", DailyNotes.document.nextId, 1);
        check.equal("new checklist starts without categories", JSON.stringify(DailyNotes.boardFor(root.earlier).categories), '[]');
        check.equal("category creation cannot submit the retired name", DailyNotes.canAddCategory(root.earlier, "  iNbox  "), false);
        check.equal("category creation can submit a valid name", DailyNotes.canAddCategory(root.earlier, "  Work  "), true);
        check.equal("blank category is rejected", DailyNotes.addCategory(root.earlier, "  "), null);
        check.equal("retired category name is rejected", DailyNotes.addCategory(root.earlier, "  iNbox  "), null);
        check.equal("category name is trimmed", DailyNotes.addCategory(root.earlier, "  Work  "), "Work");
        check.equal("duplicate category resolves its canonical key", DailyNotes.addCategory(root.earlier, "work"), "Work");
        check.equal("second category saves", DailyNotes.addCategory(root.earlier, "Personal"), "Personal");
        check.equal("duplicate category is not appended", JSON.stringify(DailyNotes.boardFor(root.earlier).categories), '["Work","Personal"]');
        check.equal("other dates start without cards", DailyNotes.checklist(root.later).groups.length, 0);
        check.equal("another day cannot select this category", DailyNotes.selectCategory(root.later, "Work"), false);
        check.equal("a category cannot be created on an invalid date", DailyNotes.addCategory("2024-02-30", "Work"), null);
        check.equal("empty document has no preview", DailyNotes.preview, null);
        check.equal("missing identity resolves to null", DailyNotes.find("missing"), null);
        check.equal("valid leap day is accepted", DailyNotes.validDay(root.earlier), true);
        check.equal("date helper preserves local calendar date",
            Qt.formatDate(DailyNotes.dateFor(root.earlier), "yyyy-MM-dd"), root.earlier);
        for (const day of ["2023-02-29", "2024-04-31", "2024-00-01", "2024-13-01",
                "2024-01-00", "2024-2-09", "2024-02-29x", ""]) {
            check.equal("invalid calendar date rejected: " + day, DailyNotes.validDay(day), false);
        }
        check.equal("unset deadline is valid", DailyNotes.validDeadline(""), true);
        check.equal("leap-day deadline is valid", DailyNotes.validDeadline("2024-02-29T23:59"), true);
        for (const deadline of ["2023-02-29T09:00", "2024-04-31T10:00", "2024-02-29",
                "2024-02-29T24:00", "2024-02-29T09:60", "2024-02-29T9:00",
                "2024-02-29 09:00", "2024-02-29T09:00:00", "2024-02-29T09:00Z",
                " 2024-02-29T09:00", "2024-02-29T09:00 "]) {
            check.equal("invalid deadline rejected: " + deadline, DailyNotes.validDeadline(deadline), false);
        }
        const before = JSON.stringify(DailyNotes.document);
        check.equal("blank title cannot add", DailyNotes.save(root.earlier, "", "  ", "", "Work"), false);
        check.equal("invalid date cannot add", DailyNotes.save("2023-02-29", "", "Task", "", "Work"), false);
        check.equal("partial deadline cannot add", DailyNotes.save(root.earlier, "", "Task", "09:00", "Work"), false);
        check.equal("omitted category cannot add", DailyNotes.save(root.earlier, "", "Task", ""), false);
        check.equal("empty category cannot add", DailyNotes.save(root.earlier, "", "Task", "", ""), false);
        check.equal("unknown category cannot add", DailyNotes.save(root.earlier, "", "Task", "", "Missing"), false);
        check.equal("a category from another date cannot add", DailyNotes.save(root.later, "", "Task", "", "Work"), false);
        root.unchanged("rejected additions do not allocate identities", before);

        DailyNotes.addCategory(root.later, "Work");
        DailyNotes.addCategory(root.later, "Personal");
        check.equal("first historical task saves", DailyNotes.save(root.earlier, "", "  First task  ", "", "Personal"), true);
        root.firstId = DailyNotes.preview.id;
        check.equal("task title is trimmed", DailyNotes.find(root.firstId).title, "First task");
        check.equal("first task uses the requested category", DailyNotes.find(root.firstId).category, "Personal");
        check.equal("unset deadline has no label", DailyNotes.deadlineText(DailyNotes.preview.deadline), "");
        check.equal("empty deadline has no label", DailyNotes.deadlineText(""), "");
        check.equal("second day task saves", DailyNotes.save(root.later, "", "Second task", " 2024-03-04T10:30 ", "Work"), true);
        root.secondId = DailyNotes.preview.id;
        check.equal("task receives selected category", DailyNotes.find(root.secondId).category, "Work");
        check.equal("deadline is trimmed", DailyNotes.find(root.secondId).deadline, "2024-03-04T10:30");
        check.equal("deadline label includes its own date and time", DailyNotes.deadlineText(DailyNotes.preview.deadline), "Mar 4, 2024 · 10:30");
        check.equal("adding to an older day saves", DailyNotes.save(root.earlier, "", "Third task", "", "Personal"), true);
        root.thirdId = DailyNotes.preview.id;
        check.equal("preview follows newest addition across dates", DailyNotes.preview.id, root.thirdId);
        check.equal("history lists distinct sorted days", DailyNotes.days.join(","), root.earlier + "," + root.later);
        check.equal("older day retains both notes newest first",
            DailyNotes.forDay(root.earlier).map(note => note.id).join(","), root.thirdId + "," + root.firstId);
        check.equal("other day retains its own task", DailyNotes.forDay(root.later)[0].id, root.secondId);
        check.equal("unknown day has no notes", DailyNotes.forDay("2024-03-02").length, 0);
        root.edit();
    }

    function edit(): void {
        const before = JSON.stringify(DailyNotes.document);
        check.equal("edit cannot move a task to another day",
            DailyNotes.save(root.earlier, root.secondId, "Wrong day", ""), false);
        check.equal("unknown task cannot be edited",
            DailyNotes.save(root.later, "999", "Missing", ""), false);
        root.unchanged("rejected edits preserve history", before);
        check.equal("existing task can be edited",
            DailyNotes.save(root.later, root.secondId, "  Edited second  ", "2024-03-05T12:00"), true);
        const edited = DailyNotes.find(root.secondId);
        check.equal("edit preserves identity", edited.id, root.secondId);
        check.equal("edit preserves day", edited.day, root.later);
        check.equal("edit trims replacement title", edited.title, "Edited second");
        check.equal("edit updates deadline independently of board day", edited.deadline, "2024-03-05T12:00");
        check.equal("edit preserves category", edited.category, "Work");
        root.annotations();
        check.equal("task can move to another category",
            DailyNotes.save(root.later, root.secondId, "Edited second", "2024-03-05T12:00", "Personal"), true);
        check.equal("category assignment updates the note", DailyNotes.find(root.secondId).category, "Personal");
        check.equal("category assignment preserves identity and order", DailyNotes.document.notes[1].id, root.secondId);
        const checklist = DailyNotes.checklist(root.later);
        check.equal("historical checklist counts tasks", checklist.total, 1);
        check.equal("historical checklist retains its own empty category", checklist.groups[0].notes.size, 0);
        check.equal("checklist groups by saved category", checklist.groups[1].category, "Personal");
        check.equal("checklist uses stable identity keys", [...checklist.groups[1].notes.keys()].join(","), root.secondId);
        check.equal("edit preserves newest-first ordering", DailyNotes.preview.id, root.thirdId);
        const unchanged = JSON.stringify(DailyNotes.document);
        check.equal("unchanged edit succeeds",
            DailyNotes.save(root.later, root.secondId, "Edited second", "2024-03-05T12:00"), true);
        root.unchanged("unchanged edit preserves the document", unchanged);

        check.equal("a newer task can be added",
            DailyNotes.save(root.later, "", "Newest task", "", "Work"), true);
        root.newestId = DailyNotes.document.notes[0].id;
        check.equal("the preview follows the newest task", DailyNotes.preview.id, root.newestId);
        check.equal("all allocated identities are unique", new Set(DailyNotes.document.notes.map(note => note.id)).size, 4);
        const expected = JSON.stringify(DailyNotes.document);
        written.until(root.path, text => text === expected, text => {
            check.equal("task changes persist together", text, expected);
            const data = root.parse(text);
            check.equal("persisted document passes schema validation", DailyNotes.validDocument(data), true);
            check.equal("persisted task retains its category", data?.notes.find(note => note.id === root.secondId)?.category, "Personal");
            check.equal("notes persist in addition order after editing the task",
                JSON.stringify(data?.notes.find(note => note.id === root.secondId)?.annotations), '["First note","Second note"]');
            check.equal("writes leave service ready", DailyNotes.ready, true);
            check.equal("successful writes leave no error", DailyNotes.error, "");
            check.attempt("completion and deletion lifecycle", root.complete);
        });
    }

    function annotations(): void {
        const before = JSON.stringify(DailyNotes.document);
        check.equal("empty annotations are rejected", DailyNotes.saveAnnotation(root.secondId, undefined, 0, "  "), false);
        check.equal("annotations require an existing task", DailyNotes.saveAnnotation("999", undefined, 0, "Orphan"), false);
        root.unchanged("rejected annotations preserve history", before);
        check.equal("the first annotation saves", DailyNotes.saveAnnotation(root.secondId, undefined, 0, " First note "), true);
        const first = DailyNotes.find(root.secondId).annotations;
        check.equal("duplicate notes can be added", DailyNotes.saveAnnotation(root.secondId, first, 1, "First note"), true);
        const pair = DailyNotes.find(root.secondId).annotations;
        check.equal("an out-of-range deletion is rejected", DailyNotes.saveAnnotation(root.secondId, pair, 2, null), false);
        check.equal("a stale annotation action is rejected", DailyNotes.saveAnnotation(root.secondId, first, 0, null), false);
        check.equal("only the second copy is edited", DailyNotes.saveAnnotation(root.secondId, pair, 1, " Second note "), true);
        check.equal("the edit keeps the other copy", JSON.stringify(DailyNotes.find(root.secondId).annotations), '["First note","Second note"]');
        const data = JSON.parse(before);
        for (const invalid of [null, "Notes", [null], [""], ["  "]]) {
            data.notes[0].annotations = invalid;
            check.equal("invalid annotations are rejected: " + JSON.stringify(invalid), DailyNotes.validDocument(data), false);
        }
        check.equal("invalid time is rejected", DailyNotes.setDeadlineTime(root.thirdId, "25:00"), false);
        check.equal("setting the first time uses the task's day", DailyNotes.setDeadlineTime(root.thirdId, "00:00"), true);
        check.equal("initial time saves against the task's day", DailyNotes.find(root.thirdId).deadline, root.earlier + "T00:00");
        check.equal("time can be cleared independently", DailyNotes.setDeadlineTime(root.thirdId, ""), true);
    }

    function complete(): void {
        DailyNotes.toggleDone(root.firstId);
        check.equal("completion retains historical task", DailyNotes.find(root.firstId).done, true);
        check.equal("completing an older task preserves the current preview", DailyNotes.preview.id, root.newestId);
        check.equal("completion preserves both historical days", DailyNotes.days.length, 2);
        DailyNotes.toggleDone(root.newestId);
        check.equal("completing newest task finds next unfinished", DailyNotes.preview.id, root.thirdId);
        DailyNotes.toggleDone(root.newestId);
        check.equal("uncompletion restores the newest preview", DailyNotes.preview.id, root.newestId);
        DailyNotes.toggleDone(root.secondId);
        check.equal("completion preserves edited title", DailyNotes.find(root.secondId).title, "Edited second");
        check.equal("completion preserves edited deadline", DailyNotes.find(root.secondId).deadline, "2024-03-05T12:00");
        check.equal("completion preserves category", DailyNotes.find(root.secondId).category, "Personal");
        check.equal("checklist counts completed tasks", DailyNotes.checklist(root.later).done, 1);
        check.equal("category counts completed tasks",
            DailyNotes.checklist(root.later).groups.find(group => group.category === "Personal").done, 1);
        DailyNotes.toggleDone(root.secondId);
        check.equal("uncompletion leaves newer unfinished preview first", DailyNotes.preview.id, root.newestId);
        DailyNotes.remove(root.thirdId);
        check.equal("deleting an older task preserves the current preview", DailyNotes.preview.id, root.newestId);
        check.equal("deleted identity no longer resolves", DailyNotes.find(root.thirdId), null);
        const before = JSON.stringify(DailyNotes.document);
        DailyNotes.toggleDone("999");
        DailyNotes.remove("999");
        root.unchanged("unknown identity actions preserve the document", before);
        DailyNotes.remove(root.newestId);
        check.equal("removing newest task falls back across days", DailyNotes.preview.id, root.secondId);
        DailyNotes.toggleDone(root.secondId);
        check.equal("all completed tasks yield no preview", DailyNotes.preview, null);
        check.equal("all completed tasks remain in history", DailyNotes.document.notes.length, 2);
        DailyNotes.toggleDone(root.firstId);
        check.equal("old task can be uncompleted", DailyNotes.find(root.firstId).done, false);
        check.equal("uncompleted historical task becomes preview", DailyNotes.preview.id, root.firstId);
        check.equal("deleted identities are never reused", DailyNotes.document.nextId, 5);

        const expected = JSON.stringify(DailyNotes.document);
        written.until(root.path, text => text === expected, text => {
            check.equal("completion, deletion and history persist", text, expected);
            check.equal("final disk document remains valid", DailyNotes.validDocument(root.parse(text)), true);
            check.equal("empty categories remain available", JSON.stringify(DailyNotes.boardFor(root.earlier).categories), '["Work","Personal"]');
            check.equal("all operations leave service ready", DailyNotes.ready, true);
            root.retryWrite();
        });
    }

    function retryWrite(): void {
        const before = JSON.stringify(DailyNotes.document);
        mode.run('chmod u-w "$1" && printf locked', [root.path], locked => {
            check.equal("state file can be made read-only", locked, "locked");
            if (locked !== "locked") { check.done(); return; }
            check.equal("write failure is reported", DailyNotes.save(root.later, "", "Retry this task", "", "Work"), false);
            const annotations = DailyNotes.find(root.secondId).annotations;
            check.equal("annotation deletion failure is reported", DailyNotes.saveAnnotation(root.secondId, annotations, 0, null), false);
            check.equal("category write failure is reported", DailyNotes.addCategory(root.earlier, "Not saved"), null);
            root.unchanged("failed write preserves the last saved document", before);
            check.equal("failed category never becomes selectable", DailyNotes.boardFor(root.earlier).categories.includes("Not saved"), false);
            check.equal("failed write leaves an error for the editor", DailyNotes.error !== "", true);
            Qt.callLater(() => mode.run('chmod u+w "$1" && printf unlocked', [root.path], unlocked => {
                check.equal("state file is writable again", unlocked, "unlocked");
                check.equal("retrying the same change writes to disk",
                    DailyNotes.save(root.later, "", "Retry this task", "", "Work"), true);
                check.equal("successful retry clears the error", DailyNotes.error, "");
                check.equal("successful retry publishes the saved task", DailyNotes.preview?.title, "Retry this task");
                check.done();
            }));
        });
    }
}
