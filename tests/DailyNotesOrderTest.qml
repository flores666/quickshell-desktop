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
    DailyNotesDocument { id: format }

    readonly property string path: Quickshell.statePath("daily-notes.json")
    readonly property string past: "2024-06-01"
    property string tracked: ""

    Component.onCompleted: {
        if (Quickshell.env("TEST_BIN") === "") {
            check.report("isolated runner required", false, "run tools/test.sh DailyNotesOrderTest");
            check.done();
            return;
        }
        ready.until(DailyNotes.readyChanged, () => DailyNotes.ready, ok => {
            check.equal("card order service becomes ready", ok, true);
            if (ok)
                check.attempt("card order lifecycle", root.start);
            else
                check.done();
        });
    }

    function order(label: string, expected: var): void {
        check.equal(label, JSON.stringify(DailyNotes.orderFor(DailyNotes.today)), JSON.stringify(expected));
        check.equal(label + " remains valid", DailyNotes.validDocument(DailyNotes.document), true);
    }

    function cards(day: string): string {
        return JSON.stringify(DailyNotes.checklist(day).groups.map(group => group.category));
    }

    function add(day: string, category: string): string {
        check.equal("fixture saves in " + category, DailyNotes.save(day, "", "Task " + category, "", "", category), true);
        return DailyNotes.document.notes[0].id;
    }

    function start(): void {
        check.equal("new documents omit card order", DailyNotes.boardFor(DailyNotes.today).cardOrder, undefined);
        check.equal("a document without saved lanes supplies an empty map", DailyNotes.lanesFor(DailyNotes.today).size, 0);
        DailyNotes.addCategory(DailyNotes.today, "Work");
        DailyNotes.addCategory(DailyNotes.today, "Temporary");
        DailyNotes.addCategory(DailyNotes.today, "Personal");
        DailyNotes.addCategory(DailyNotes.today, "Empty");
        DailyNotes.removeCategory(DailyNotes.today, "Temporary");
        root.order("default follows the live registry", ["Work", "Personal", "Empty"]);
        check.equal("category edits preserve legacy omission", DailyNotes.boardFor(DailyNotes.today).cardOrder, undefined);
        DailyNotes.addCategory(root.past, "Personal");
        DailyNotes.addCategory(root.past, "Work");
        root.add(root.past, "Personal");
        root.tracked = root.add(root.past, "Work");
        DailyNotes.toggleTracking(root.tracked);
        root.add(DailyNotes.today, "Personal");
        root.schema();

        const before = JSON.stringify(DailyNotes.document);
        check.equal("already adjacent before is a no-op", DailyNotes.moveCategory(DailyNotes.today, "Work", "Personal", false), false);
        check.equal("already adjacent after is a no-op", DailyNotes.moveCategory(DailyNotes.today, "Personal", "Work", true), false);
        check.equal("self move is rejected", DailyNotes.moveCategory(DailyNotes.today, "Work", "Work", true), false);
        check.equal("legacy empty source is rejected", DailyNotes.moveCategory(DailyNotes.today, "", "Work", false), false);
        check.equal("missing source is rejected", DailyNotes.moveCategory(DailyNotes.today, "Missing", "Work", false), false);
        check.equal("missing target is rejected", DailyNotes.moveCategory(DailyNotes.today, "Work", "Missing", true), false);
        check.equal("category identity is exact", DailyNotes.moveCategory(DailyNotes.today, "work", "Personal", true), false);
        check.equal("rejected moves preserve document and legacy omission", JSON.stringify(DailyNotes.document), before);
        check.equal("forward move succeeds", DailyNotes.moveCategory(DailyNotes.today, "Work", "Empty", true), true);
        root.order("forward move preserves unrelated order", ["Personal", "Empty", "Work"]);
        check.equal("today shows ordered cards including empty categories", root.cards(DailyNotes.today), '["Personal","Empty","Work"]');
        check.equal("history keeps its own order", root.cards(root.past), '["Personal","Work"]');
        check.equal("backward move resolves the current target", DailyNotes.moveCategory(DailyNotes.today, "Work", "Personal", false), true);
        root.order("backward move preserves unrelated order", ["Work", "Personal", "Empty"]);
        check.equal("registry order is independent of card order", JSON.stringify(DailyNotes.boardFor(DailyNotes.today).categories), '["Work","Personal","Empty"]');
        check.equal("reordering preserves notes", JSON.stringify(DailyNotes.document.notes), JSON.stringify(JSON.parse(before).notes));
        check.equal("reordering preserves tracked identity", DailyNotes.trackedId, root.tracked);
        root.placeCards();
        check.equal("new category appends to the chosen card order", DailyNotes.addCategory(DailyNotes.today, "New"), "New");
        check.equal("a new category has no explicit lane", DailyNotes.lanesFor(DailyNotes.today).has("New"), false);
        root.order("append retains custom order", ["Work", "Personal", "Empty", "New"]);
        check.equal("category removal succeeds", DailyNotes.removeCategory(DailyNotes.today, "Personal"), true);
        check.equal("empty category removal succeeds", DailyNotes.removeCategory(DailyNotes.today, "Empty"), true);
        root.order("removed category keys disappear from order", ["Work", "New"]);
        check.equal("deleted categories release their lanes", JSON.stringify([...DailyNotes.lanesFor(DailyNotes.today)]), '[["Work",0]]');
        const removed = JSON.stringify(DailyNotes.document);
        check.equal("removed drag source is rejected", DailyNotes.moveCategory(DailyNotes.today, "Personal", "Work", true), false);
        check.equal("removed drop target is rejected", DailyNotes.moveCategory(DailyNotes.today, "Work", "Empty", true), false);
        check.equal("stale moves leave every field intact", JSON.stringify(DailyNotes.document), removed);
        root.add(DailyNotes.today, "Work");
        check.equal("saving another task cannot restore a removed card", root.cards(DailyNotes.today), '["Work","New"]');
        root.failWrite();
    }

    function placeCards(): void {
        const placements = new Map([["Work", 0], ["Personal", 1], ["Empty", 0]]);
        check.equal("a move can change lanes without changing flat order",
            DailyNotes.moveCategory(DailyNotes.today, "Work", "Personal", false, placements), true);
        root.order("saving lanes keeps the flat order", ["Work", "Personal", "Empty"]);
        check.equal("saved lanes are visible", JSON.stringify([...DailyNotes.lanesFor(DailyNotes.today)]), JSON.stringify([...placements]));
        check.equal("other dates do not take saved lanes", DailyNotes.lanesFor(root.past).size, 0);
        const before = DailyNotes.document;
        const reversed = new Map([...placements].reverse());
        check.equal("same placements in another order are a no-op", DailyNotes.moveCategory(DailyNotes.today, "Work", "Personal", false, reversed), false);
        for (const invalid of [null, [], {}, new Map([["Missing", 0]]), new Map([["work", 0]]),
                new Map([[1, 0]]), new Map([["Work", 2]]), new Map([["Work", "0"]]), new Map([["Work", true]])]) {
            check.equal("invalid placement map is rejected", DailyNotes.moveCategory(DailyNotes.today, "Work", "Empty", true, invalid), false);
        }
        check.equal("a rejected placement publishes no document", DailyNotes.document, before);
        check.equal("an ordinary reorder still succeeds", DailyNotes.moveCategory(DailyNotes.today, "Work", "Personal", true), true);
        check.equal("an ordinary reorder preserves lanes", JSON.stringify([...DailyNotes.lanesFor(DailyNotes.today)]), JSON.stringify([...placements]));
        check.equal("an ordinary reorder restores the initial order", DailyNotes.moveCategory(DailyNotes.today, "Work", "Personal", false), true);

        DailyNotes.addCategory(DailyNotes.today, "__proto__");
        placements.set("__proto__", 1);
        check.equal("prototype-like category names have ordinary placements",
            DailyNotes.moveCategory(DailyNotes.today, "__proto__", "Empty", true, placements), true);
        check.equal("prototype-like names round-trip through JSON",
            JSON.parse(JSON.stringify(DailyNotes.boardFor(DailyNotes.today).cardLanes)).__proto__, 1);
        check.equal("prototype-like placement can be removed", DailyNotes.removeCategory(DailyNotes.today, "__proto__"), true);
        check.equal("prototype-like removal keeps the document valid", DailyNotes.validDocument(DailyNotes.document), true);
    }

    function schema(): void {
        const data = JSON.parse(JSON.stringify(DailyNotes.document));
        const board = data.boards[DailyNotes.today];
        check.equal("omitted card order remains valid", DailyNotes.validDocument(data), true);
        board.cardOrder = ["Personal", "Empty", "Work"];
        check.equal("complete exact-key permutation is valid", DailyNotes.validDocument(data), true);
        for (const value of [null, "Work", [], ["Personal", "", "Empty", "Work"], ["", "Work", "Personal"], ["", "Work", "Work", "Empty"],
                ["", "Work", "", "Personal", "Empty"],
                ["", "Work", "Personal", "Missing"], ["", "work", "Personal", "Empty"], ["", "Work", "Personal", 1]]) {
            board.cardOrder = value;
            check.equal("malformed order rejected: " + JSON.stringify(value), DailyNotes.validDocument(data), false);
        }
        check.equal("schema checks do not persist order", DailyNotes.boardFor(DailyNotes.today).cardOrder, undefined);
        delete board.cardOrder;
        board.cardLanes = { Work: 0 };
        check.equal("a partial lane assignment is valid", DailyNotes.validDocument(data), true);
        for (const value of [null, [], "Work", new Map(), { Missing: 0 }, { work: 0 }, { Work: -1 }, { Work: "1" }]) {
            board.cardLanes = value;
            check.equal("malformed lane row is rejected: " + JSON.stringify(value), DailyNotes.validDocument(data), false);
        }
        const legacy = { nextId: data.nextId, trackedId: data.trackedId, notes: data.notes,
            categories: [...board.categories, "Inbox"], cardLanes: { Work: 0, Inbox: 1 } };
        check.equal("a retired category lane is loadable", DailyNotes.validDocument(legacy), true);
        check.equal("migration releases the retired category lane", JSON.stringify(format.migrate(legacy).boards[root.past].cardLanes), '{"Work":0}');
    }

    function failWrite(): void {
        const before = JSON.stringify(DailyNotes.document);
        mode.run('chmod u-w "$1" && printf locked', [root.path], locked => {
            check.equal("order fixture can be made read-only", locked, "locked");
            if (locked !== "locked") { check.done(); return; }
            check.equal("failed atomic reorder is reported",
                DailyNotes.moveCategory(DailyNotes.today, "New", "Work", false, new Map([["New", 0], ["Work", 1]])), false);
            check.equal("failed reorder preserves all state", JSON.stringify(DailyNotes.document), before);
            check.equal("failed reorder leaves an error", DailyNotes.error !== "", true);
            Qt.callLater(() => mode.run('chmod u+w "$1" && printf unlocked', [root.path], unlocked => {
                check.equal("order fixture is writable again", unlocked, "unlocked");
                check.attempt("card order retry", root.retry);
            }));
        });
    }

    function retry(): void {
        check.equal("reorder succeeds after retry",
            DailyNotes.moveCategory(DailyNotes.today, "New", "Work", false, new Map([["New", 0], ["Work", 1]])), true);
        root.order("retry uses the preserved live order", ["New", "Work"]);
        check.equal("successful retry clears write error", DailyNotes.error, "");
        const expected = JSON.stringify(DailyNotes.document);
        written.until(root.path, text => text === expected, text => {
            check.equal("card order and tasks persist atomically", text, expected);
            const data = JSON.parse(text);
            const board = data.boards[DailyNotes.today];
            check.equal("persisted card order contains only named categories", JSON.stringify(board.cardOrder), '["New","Work"]');
            check.equal("persisted lanes accompany the new order", JSON.stringify(board.cardLanes), '{"New":0,"Work":1}');
            check.equal("persisted registry retains insertion order", JSON.stringify(board.categories), '["Work","New"]');
            check.equal("persisted document remains valid", DailyNotes.validDocument(data), true);
            check.equal("tracking survives every reorder", data.trackedId, root.tracked);
            DailyNotes.load();
            check.equal("saved lane assignments load again", JSON.stringify([...DailyNotes.lanesFor(DailyNotes.today)]), '[["New",0],["Work",1]]');
            check.equal("saved flat order loads with its lanes", JSON.stringify(DailyNotes.orderFor(DailyNotes.today)), '["New","Work"]');
            check.done();
        });
    }
}
