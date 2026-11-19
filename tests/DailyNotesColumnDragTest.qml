pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Quickshell
import Quickshell.Wayland
import "root:/config"
import "root:/services"
import "root:/modules/widgets"

Item {
    id: root

    readonly property var categories: ["Alpha", "Bravo", "Charlie", "Delta", "Echo", "Foxtrot"]
    property bool seeded: false
    property real viewportWidth: 500
    property real viewportHeight: 760

    Check { id: check }
    TestEvent { id: input }
    Until { id: ready }

    PanelWindow {
        screen: Quickshell.screens[0]
        implicitWidth: 560
        implicitHeight: 760
        visible: root.seeded
        WlrLayershell.namespace: "shell-notes-column-drag-test"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        Item {
            id: scene
            anchors.fill: parent

            DailyNotesScroll {
                id: viewport
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.margins: Appearance.s.md
                width: root.viewportWidth
                height: Math.min(root.viewportHeight, parent.height - Appearance.s.md * 2)
                contentHeight: board.height
                dragPoint: board.dragPoint
                onContentMoved: board.refreshDrag()

                DailyNotesBoard {
                    id: board
                    width: viewport.contentWidth
                    groups: DailyNotes.todayChecklist.groups
                    dragViewport: viewport
                }
            }
        }
    }

    Timer {
        id: settle
        property var then
        interval: Math.max(Appearance.windowDrag.landing, Appearance.t.popupMove) + Appearance.t.grace
        onTriggered: check.attempt("column drag step", settle.then)
    }

    function after(then: var): void {
        settle.then = then;
        settle.restart();
    }

    function tile(category: string): DailyNoteCategory {
        return board.children.find(item => item instanceof DailyNoteCategory && item.category === category)
            as DailyNoteCategory;
    }

    function handle(item: Item): Item {
        if (item.objectName === "dragNoteCategory")
            return item;
        for (const child of item.children) {
            const grip = root.handle(child);
            if (grip)
                return grip;
        }
        return null;
    }

    function column(label: string, keys: var, x: real): void {
        let y = 0;
        for (const category of keys) {
            const card = root.tile(category);
            check.near(label + " " + category + " stays in its column", card.x, x);
            check.near(label + " " + category + " packs tightly in its column", card.y, y);
            y += card.height + board.gap;
        }
    }

    function grab(source: DailyNoteCategory, target: DailyNoteCategory): point {
        const origin = source.mapToItem(scene, source.width / 2, Appearance.s.md * 2);
        const drop = target.mapToItem(scene, target.width / 2, target.height / 4);
        check.equal(source.category + " accepts a press",
            input.mousePress(scene, origin.x, origin.y, Qt.LeftButton, Qt.NoModifier, -1), true);
        root.move(drop);
        check.equal(source.category + " starts dragging", board.dragging, true);
        return drop;
    }

    function move(point: point): void {
        input.mouseMove(scene, point.x, point.y, -1, Qt.LeftButton, Qt.NoModifier);
    }

    function release(drop: point): void {
        input.mouseRelease(scene, drop.x, drop.y, Qt.LeftButton, Qt.NoModifier, -1);
        check.equal("release ends the drag", board.dragging, false);
    }

    function start(): void {
        check.equal("fixture starts with two columns", board.columns, 2);
        root.checkOriginalColumns("before drag");
        const source = root.tile("Alpha");
        const target = root.tile("Bravo");
        const lower = target.mapToItem(scene, target.width / 2, target.height * 3 / 4);
        const saved = DailyNotes.document;
        const upper = root.grab(source, target);
        root.after(() => {
            root.checkDroppedColumns("upper half preview");
            check.equal("upper half preview leaves the document untouched", DailyNotes.document, saved);
            root.move(lower);
            root.after(() => root.lowerPreview(upper, saved));
        });
    }

    function lowerPreview(upper: point, saved: var): void {
        root.column("lower half preview", ["Delta", "Echo"], 0);
        root.column("lower half preview", ["Bravo", "Alpha", "Charlie", "Foxtrot"], board.columnWidth + board.gap);
        check.equal("changing insertion side leaves the document untouched", DailyNotes.document, saved);
        check.equal("the preview preserves saved category order", JSON.stringify(DailyNotes.cardOrder),
            JSON.stringify(root.categories));
        root.move(Qt.point(viewport.x / 2, upper.y));
        root.after(() => {
            root.checkOriginalColumns("outside preview");
            check.equal("the pointer can re-enter during the same drag", board.dragging, true);
            root.move(upper);
            root.after(() => root.dropPreview(upper));
        });
    }

    function dropPreview(drop: point): void {
        root.checkDroppedColumns("re-entered preview");
        let moved = false;
        const neighbors = root.categories.slice(1).map(category => {
            const card = root.tile(category);
            const x = card.x;
            const y = card.y;
            const positionChanged = () => {
                if (Math.abs(card.x - x) >= 0.001 || Math.abs(card.y - y) >= 0.001)
                    moved = true;
            };
            card.xChanged.connect(positionChanged);
            card.yChanged.connect(positionChanged);
            return [card, positionChanged];
        });
        root.release(drop);
        root.after(() => {
            for (const [card, positionChanged] of neighbors) {
                card.xChanged.disconnect(positionChanged);
                card.yChanged.disconnect(positionChanged);
            }
            check.equal("settled neighbors hold position throughout the release", moved, false);
            root.landed();
        });
    }

    function checkOriginalColumns(label: string): void {
        root.column(label, ["Alpha", "Delta", "Echo"], 0);
        root.column(label, ["Bravo", "Charlie", "Foxtrot"], board.columnWidth + board.gap);
    }

    function checkDroppedColumns(label: string): void {
        root.column(label, ["Delta", "Echo"], 0);
        root.column(label, ["Alpha", "Bravo", "Charlie", "Foxtrot"], board.columnWidth + board.gap);
    }

    function landed(): void {
        root.checkDroppedColumns("after drop");
        root.viewportWidth = 300;
        root.after(() => {
            check.equal("narrow viewport uses one column", board.columns, 1);
            root.viewportWidth = 500;
            root.after(() => {
                check.equal("restored viewport uses two columns", board.columns, 2);
                root.checkDroppedColumns("after restoring the width");
                root.keyboard();
            });
        });
    }

    function keyboard(): void {
        const source = root.tile("Delta");
        const grip = root.handle(source);
        grip.forceActiveFocus(Qt.TabFocusReason);
        check.equal("top left card's grip receives keyboard focus", grip.activeFocus, true);
        let direction = 0;
        const recordStep = delta => direction = delta;
        const before = DailyNotes.document;
        source.stepRequested.connect(recordStep);
        input.keyClick(Qt.Key_Up, Qt.NoModifier, -1);
        source.stepRequested.disconnect(recordStep);
        check.equal("Up is delivered to the grip", direction, -1);
        check.equal("Up on the first visual card is a no-op", DailyNotes.document, before);

        check.equal("remove the other left card", DailyNotes.removeCategory("Echo"), true);
        root.after(root.exchange);
    }

    function exchange(): void {
        root.column("before exchange", ["Delta"], 0);
        const drop = root.grab(root.tile("Delta"), root.tile("Alpha"));
        root.after(() => {
            root.exchangedColumns("exchange preview");
            root.release(drop);
            root.after(() => {
                root.exchangedColumns("after exchange");
                check.equal("remove the only left card", DailyNotes.removeCategory("Alpha"), true);
                root.after(root.refill);
            });
        });
    }

    function exchangedColumns(label: string): void {
        root.column(label, ["Alpha"], 0);
        root.column(label, ["Delta", "Bravo", "Charlie", "Foxtrot"], board.columnWidth + board.gap);
    }

    function refill(): void {
        root.column("after deleting the last left card", ["Foxtrot"], 0);
        root.column("after deleting the last left card", ["Delta", "Bravo", "Charlie"], board.columnWidth + board.gap);
        check.equal("new category saves", DailyNotes.addCategory("Golf"), "Golf");
        root.after(() => {
            root.column("after adding a category", ["Foxtrot", "Golf"], 0);
            root.column("after adding a category", ["Delta", "Bravo", "Charlie"], board.columnWidth + board.gap);
            root.viewportHeight = 190;
            root.after(root.scrollLanding);
        });
    }

    function scrollLanding(): void {
        viewport.reset();
        const origin = board.mapToItem(scene, 0, 0).y;
        const committedReach = board.resting.height - viewport.height;
        const top = root.grab(root.tile("Foxtrot"), root.tile("Delta"));
        const edge = Qt.point(top.x, viewport.y + viewport.height - 2);
        root.move(edge);
        ready.until(viewport.contentMoved, () => origin - board.mapToItem(scene, 0, 0).y > committedReach + board.gap,
            reached => Qt.callLater(() => {
                check.equal("edge scroll reaches the preview beyond the committed bottom", reached, true);
                const height = board.height;
                let minimum = height;
                const resized = () => minimum = Math.min(minimum, board.height);
                board.heightChanged.connect(resized);
                root.release(edge);
                board.heightChanged.disconnect(resized);
                check.near("committing the preview never shrinks the scroll bounds", minimum, height);
                root.after(() => {
                    root.column("after edge landing", ["Golf"], 0);
                    root.column("after edge landing", ["Delta", "Bravo", "Charlie", "Foxtrot"], board.columnWidth + board.gap);
                    check.done();
                });
            }));
    }

    Component.onCompleted: {
        if (Quickshell.env("TEST_BIN") === "") {
            check.report("isolated test runner required", false, "run tools/test.sh DailyNotesColumnDragTest");
            check.done();
            return;
        }
        ready.until(DailyNotes.readyChanged, () => DailyNotes.ready, ok => {
            check.equal("notes service is ready", ok, true);
            if (!ok) { check.done(); return; }
            const counts = [5, 3, 5, 1, 4, 4];
            for (const [index, category] of root.categories.entries()) {
                check.equal("category saves: " + category, DailyNotes.addCategory(category), category);
                for (let row = 1; row <= counts[index]; ++row)
                    check.equal("task saves: " + category + " " + row,
                        DailyNotes.save(DailyNotes.today, "", "Task " + row, "", "", category), true);
            }
            root.seeded = true;
            root.after(root.start);
        });
    }
}
