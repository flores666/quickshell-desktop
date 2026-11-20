pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

/*! The service import is delayed until its private legacy file exists, so
    this verifies real startup migration rather than mutating live state. */
Item {
    id: root

    Check { id: check }
    Until { id: ready }
    FileWait { id: written }
    Command { id: command }
    property var bridge: null
    readonly property var notes: root.bridge?.service ?? null
    readonly property string path: Quickshell.statePath("daily-notes.json")
    readonly property var legacy: ({ nextId: 4, trackedId: "1", notes: [
        { id: "3", day: "2024-06-02", title: "Newest", start: "", end: "", done: false },
        { id: "2", day: "2024-06-01", title: "Completed", start: "09:00", end: "10:00", done: true },
        { id: "1", day: "2024-06-01", title: "Tracked", start: "11:00", end: "12:00", done: false }
    ] })

    Component.onCompleted: {
        if (Quickshell.env("TEST_BIN") === "") {
            check.report("isolated test runner required", false, "run tools/test.sh DailyNotesMigrationTest");
            check.done();
            return;
        }
        command.run('mkdir -p "$(dirname "$1")" && printf %s "$2" > "$1" && printf seeded',
            [root.path, JSON.stringify(root.legacy)], result => {
                check.equal("legacy state fixture is seeded", result, "seeded");
                if (result !== "seeded") { check.done(); return; }
                root.bridge = Qt.createQmlObject('import QtQuick; import "root:/services"; '
                    + 'QtObject { readonly property var service: DailyNotes; '
                    + 'readonly property var format: DailyNotesDocument {} }', root, "legacy-notes-bridge");
                ready.until(root.notes.readyChanged, () => root.notes.ready, ok => {
                    check.equal("legacy service becomes ready", ok, true);
                    if (ok)
                        check.attempt("legacy migration", root.migrate);
                    else
                        check.done();
                });
            });
    }

    function copy(value: var): var {
        return JSON.parse(JSON.stringify(value));
    }

    function migrate(): void {
        check.equal("legacy document is accepted", root.notes.validDocument(root.legacy), true);
        check.equal("legacy load has no error", root.notes.error, "");
        check.equal("legacy history retains identity order", root.notes.document.notes.map(note => note.id).join(","), "3,2,1");
        check.equal("legacy identity counter is preserved", root.notes.document.nextId, 4);
        check.equal("legacy manual tracking does not override the preview", root.notes.preview?.id, "3");
        const previous = Object.assign({}, root.notes.document, { trackedId: "1" });
        check.equal("a dated document with obsolete tracking still loads", root.notes.validDocument(previous), true);
        check.equal("dated conversion discards only obsolete tracking",
            JSON.stringify(root.bridge.format.migrate(previous)), JSON.stringify(root.notes.document));
        check.equal("legacy completion is preserved", root.notes.find("2").done, true);
        check.equal("legacy range end becomes the deadline", root.notes.find("1").deadline, "2024-06-01T12:00");
        check.equal("legacy tasks without categories are recovered on their own dates",
            JSON.stringify(root.notes.boardFor("2024-06-01").categories), '["Recovered Tasks"]');
        check.equal("migration does not carry recovery categories to other dates", root.notes.boardFor("2024-06-03").categories.length, 0);
        check.equal("all legacy notes keep their membership in the recovery category",
            root.notes.document.notes.every(note => note.category === "Recovered Tasks"), true);
        root.deadlines();
        root.namedCategories();
        root.schema();
        written.until(root.path, text => text === JSON.stringify(root.legacy), text => {
            check.equal("loading does not rewrite the legacy file", text, JSON.stringify(root.legacy));
            check.equal("category can be created after migration", root.notes.addCategory("2024-06-01", "Work"), "Work");
            check.equal("legacy task can be categorized", root.notes.save("2024-06-01", "1", "Tracked", "2024-06-01T12:00", "Work"), true);
            const expected = JSON.stringify(root.notes.document);
            written.until(root.path, text => text === expected, text => {
                check.equal("successful change persists migration", text, expected);
                const data = JSON.parse(text);
                check.equal("each date persists its own category keys",
                    JSON.stringify(data.boards["2024-06-01"].categories), '["Recovered Tasks","Work"]');
                check.equal("untouched legacy tasks persist their recovery category",
                    data.notes.find(note => note.id === "2").category, "Recovered Tasks");
                check.equal("categorized legacy task persists its key", data.notes.find(note => note.id === "1").category, "Work");
                check.equal("the next save drops the obsolete tracking field", data.trackedId, undefined);
                check.equal("normal writes remove all obsolete range fields",
                    data.notes.every(note => note.start === undefined && note.end === undefined), true);
                check.equal("normal writes retain empty legacy deadlines", data.notes[0].deadline, "");
                check.equal("migrated disk document passes validation", root.notes.validDocument(data), true);
                check.done();
            });
        });
    }

    function deadlines(): void {
        check.equal("empty legacy range becomes an unset deadline", root.notes.find("3").deadline, "");
        check.equal("migration does not mutate legacy range fields", root.legacy.notes[2].end, "12:00");
        const dated = root.copy(root.notes.document);
        dated.trackedId = "1";
        for (const note of dated.notes) {
            note.start = note.id === "3" ? "" : "08:00";
            note.end = note.id === "3" ? "" : "09:30";
            delete note.deadline;
        }
        check.equal("dated legacy ranges validate", root.notes.validDocument(dated), true);
        const migrated = root.bridge.format.migrate(dated);
        check.equal("dated migration uses original end on board day", migrated.notes[1].deadline, "2024-06-01T09:30");
        check.equal("dated migration preserves empty ranges", migrated.notes[0].deadline, "");
        check.equal("dated migration preserves boards", JSON.stringify(migrated.boards), JSON.stringify(dated.boards));
        check.equal("dated migration preserves task order and state",
            migrated.notes.map(note => note.id + ":" + note.done).join(","), "3:false,2:true,1:false");
        check.equal("dated migration strips ranges and tracking",
            migrated.trackedId === undefined && migrated.notes.every(note => note.start === undefined && note.end === undefined), true);
        check.equal("dated migration leaves its source intact", dated.notes[1].end, "09:30");
        for (const pair of [["09:00", ""], ["", "10:00"], ["9:00", "10:00"], ["10:00", "09:00"],
                ["09:00", "09:00"], ["23:00", "01:00"], ["24:00", "25:00"], ["09:60", "10:00"], [null, "10:00"]]) {
            const invalid = root.copy(dated);
            [invalid.notes[0].start, invalid.notes[0].end] = pair;
            check.equal("invalid dated legacy range rejected: " + JSON.stringify(pair), root.notes.validDocument(invalid), false);
            delete invalid.boards;
            invalid.notes.forEach(note => delete note.category);
            check.equal("invalid flat legacy range rejected: " + JSON.stringify(pair), root.notes.validDocument(invalid), false);
        }
        for (const deadline of [null, 1, "2023-02-29T09:00", "2024-06-01T24:00", "2024-06-01", "2024-06-01T09:00Z"]) {
            const invalid = root.copy(migrated);
            invalid.notes[0].deadline = deadline;
            check.equal("invalid canonical deadline rejected: " + deadline, root.notes.validDocument(invalid), false);
        }
        const mixed = root.copy(dated);
        mixed.notes[0] = migrated.notes[0];
        check.equal("mixed old and new note timing schemas validate", root.notes.validDocument(mixed), true);
        check.equal("mixed schemas normalize to canonical notes", JSON.stringify(root.bridge.format.migrate(mixed)), JSON.stringify(migrated));
        const missing = root.copy(migrated);
        delete missing.notes[0].deadline;
        check.equal("missing both timing schemas is rejected", root.notes.validDocument(missing), false);
    }

    function namedCategories(): void {
        const ordered = root.copy(root.legacy);
        ordered.categories = ["Work", "iNbOx", "Personal", "Without a date"];
        ordered.cardOrder = ["", "Personal", "iNbOx", "Work", "Without a date"];
        ordered.cardLanes = { Work: 0, Personal: 1, iNbOx: 0 };
        ordered.quickCategory = "Personal";
        ordered.notes[0].category = "";
        ordered.notes[1].category = "Work";
        ordered.notes[2].category = "iNbOx";
        check.equal("legacy order and literal Inbox are loadable", root.notes.validDocument(ordered), true);
        const migrated = root.bridge.format.migrate(ordered);
        const older = migrated.boards["2024-06-01"];
        const newer = migrated.boards["2024-06-02"];
        check.equal("registry retains surviving named categories", JSON.stringify(older.categories), '["Work","Personal"]');
        check.equal("order drops both Inbox slots", JSON.stringify(older.cardOrder), '["Personal","Work"]');
        check.equal("lanes stay with the categories of that date", JSON.stringify(newer.cardLanes), '{"Personal":1}');
        check.equal("legacy choice is copied to at most one day", newer.quickCategory === "Personal" && older.quickCategory === undefined, true);
        check.equal("legacy tasks move to the first surviving card in saved order",
            JSON.stringify(migrated.notes.map(note => note.category)), '["Personal","Work","Personal"]');
        check.equal("legacy order conversion drops obsolete tracking", migrated.trackedId, undefined);
        check.equal("migration leaves the source records intact", ordered.notes[2].category, "iNbOx");
        check.equal("a category without a dated task is not carried forward",
            Object.values(migrated.boards).some(board => board.categories.includes("Without a date")), false);
        check.equal("a task cannot reference another day's category",
            root.notes.validDocument(Object.assign({}, migrated, { notes: [Object.assign({}, migrated.notes[0], { category: "Work" })] })), false);
        ordered.notes = [];
        ordered.categories = ["iNbOx"];
        ordered.cardOrder = ["", "iNbOx"];
        delete ordered.quickCategory;
        delete ordered.cardLanes;
        const empty = root.bridge.format.migrate(ordered);
        check.equal("no recovery category is created for an empty legacy Inbox",
            JSON.stringify(empty.boards), '{}');
    }

    function schema(): void {
        for (const categories of [null, "Work", [""], [" Work"], ["Work "], ["Work", "work"], [1]]) {
            const invalid = root.copy(root.legacy);
            invalid.categories = categories;
            check.equal("malformed categories are rejected: " + JSON.stringify(categories), root.notes.validDocument(invalid), false);
        }
        for (const category of [null, 1, "Missing"]) {
            const invalid = root.copy(root.legacy);
            invalid.categories = ["Work"];
            invalid.notes[0].category = category;
            check.equal("malformed task category is rejected: " + JSON.stringify(category), root.notes.validDocument(invalid), false);
        }
        const mixed = root.copy(root.legacy);
        mixed.categories = ["Work"];
        mixed.notes[0].category = "Work";
        check.equal("partially migrated document remains valid", root.notes.validDocument(mixed), true);
        for (const quickCategory of [null, "", "work", "Inbox", "Missing"]) {
            const invalid = Object.assign({}, mixed, { categories: ["Work", "Inbox"], quickCategory });
            check.equal("invalid quick entry destination is rejected: " + quickCategory, root.notes.validDocument(invalid), false);
        }
    }
}
