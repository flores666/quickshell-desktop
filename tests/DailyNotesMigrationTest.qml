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
        check.equal("legacy manual tracking is preserved", root.notes.preview?.id, "1");
        check.equal("legacy completion is preserved", root.notes.find("2").done, true);
        check.equal("legacy time window is preserved", root.notes.rangeText(root.notes.find("1")), "11:00–12:00");
        check.equal("legacy tasks without categories get one recovery category",
            JSON.stringify(root.notes.categories), '["Recovered Tasks"]');
        check.equal("all legacy notes keep their membership in the recovery category",
            root.notes.document.notes.every(note => note.category === "Recovered Tasks"), true);
        root.namedCategories();
        root.schema();
        written.until(root.path, text => text === JSON.stringify(root.legacy), text => {
            check.equal("loading does not rewrite the legacy file", text, JSON.stringify(root.legacy));
            check.equal("category can be created after migration", root.notes.addCategory("Work"), "Work");
            check.equal("legacy task can be categorized", root.notes.save("2024-06-01", "1", "Tracked", "11:00", "12:00", "Work"), true);
            const expected = JSON.stringify(root.notes.document);
            written.until(root.path, text => text === expected, text => {
                check.equal("successful change persists migration", text, expected);
                const data = JSON.parse(text);
                check.equal("only named category keys persist", JSON.stringify(data.categories), '["Recovered Tasks","Work"]');
                check.equal("untouched legacy tasks persist their recovery category",
                    data.notes.find(note => note.id === "2").category, "Recovered Tasks");
                check.equal("categorized legacy task persists its key", data.notes.find(note => note.id === "1").category, "Work");
                check.equal("migration preserves manual tracking on disk", data.trackedId, "1");
                check.equal("migrated disk document passes validation", root.notes.validDocument(data), true);
                check.done();
            });
        });
    }

    function namedCategories(): void {
        const ordered = root.copy(root.legacy);
        ordered.categories = ["Work", "iNbOx", "Personal"];
        ordered.cardOrder = ["", "Personal", "iNbOx", "Work"];
        ordered.notes[0].category = "";
        ordered.notes[1].category = "Work";
        ordered.notes[2].category = "iNbOx";
        check.equal("legacy order and literal Inbox are loadable", root.notes.validDocument(ordered), true);
        const migrated = root.bridge.format.migrate(ordered);
        check.equal("registry retains surviving named categories", JSON.stringify(migrated.categories), '["Work","Personal"]');
        check.equal("order drops both Inbox slots", JSON.stringify(migrated.cardOrder), '["Personal","Work"]');
        check.equal("legacy tasks move to the first surviving card in saved order",
            JSON.stringify(migrated.notes.map(note => note.category)), '["Personal","Work","Personal"]');
        check.equal("legacy order conversion keeps tracking", migrated.trackedId, "1");
        check.equal("migration leaves the source records intact", ordered.notes[2].category, "iNbOx");
        ordered.notes = [];
        ordered.categories = ["iNbOx"];
        ordered.cardOrder = ["", "iNbOx"];
        const empty = root.bridge.format.migrate(ordered);
        check.equal("no recovery category is created for an empty legacy Inbox",
            JSON.stringify([empty.categories, empty.cardOrder]), '[[],[]]');
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
