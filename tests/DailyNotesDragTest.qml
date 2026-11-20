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

    Check { id: check }
    TestEvent { id: input }
    Until { id: ready }
    property bool seeded: false
    property bool stealingFocus: false
    property int deletions: 0
    property string noteId
    property var originalTiles: []
    property point dropPoint: Qt.point(0, 0)
    property point grabPoint: Qt.point(0, 0)
    property real scrollStart: 0
    property int viewportWidth: 300
    property int viewportHeight: 420
    readonly property string initialOrder: '["Alpha","Beta","Gamma"]'
    readonly property string movedOrder: '["Beta","Gamma","Alpha"]'

    PanelWindow {
        screen: Quickshell.screens[0]
        implicitWidth: 520
        implicitHeight: 500
        visible: root.seeded
        WlrLayershell.namespace: "shell-notes-drag-test"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        Item {
            id: scene
            anchors.fill: parent

            DailyNotesScroll {
                id: scrollViewport
                x: 40
                y: 40
                width: root.viewportWidth
                height: root.viewportHeight
                contentHeight: board.height
                dragPoint: board.dragPoint
                onContentMoved: board.refreshDrag()

                DailyNotesBoard {
                    id: board
                    width: scrollViewport.contentWidth
                    day: DailyNotes.today
                    groups: DailyNotes.todayChecklist.groups
                    dragViewport: scrollViewport
                    onDeleteRequested: root.deletions++
                }
            }
        }
    }

    PanelWindow {
        screen: Quickshell.screens[0]
        implicitWidth: 80
        implicitHeight: 80
        visible: root.stealingFocus
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    }

    Timer {
        id: settle
        property var then
        interval: Appearance.t.popupFade + Appearance.t.popupResize + Appearance.t.grace
        onTriggered: check.attempt("category drag step", settle.then)
    }
    function after(then: var): void {
        settle.then = then;
        settle.restart();
    }

    function tile(category: string): DailyNoteCategory {
        return board.children.find(item => item instanceof DailyNoteCategory && item.category === category)
            as DailyNoteCategory;
    }

    function find(item: Item, matches: var): Item {
        if (!item || matches(item))
            return item;
        for (const child of item.children) {
            const found = root.find(child, matches);
            if (found)
                return found;
        }
        return null;
    }

    function handle(category: string): Item {
        return root.find(root.tile(category), item => item.objectName === "dragNoteCategory");
    }
    function task(): Item {
        return root.find(root.tile("Alpha"), item => item instanceof DailyNoteRow);
    }
    function deleteButton(category: string): Item {
        return root.find(root.tile(category), item => item.objectName === "deleteNoteCategory");
    }

    function center(item: Item): point {
        return item.mapToItem(scene, item.width / 2, item.height / 2);
    }
    function move(point: point): void {
        input.mouseMove(scene, point.x, point.y, -1, Qt.LeftButton, Qt.NoModifier);
    }
    function release(point: point): void {
        input.mouseRelease(scene, point.x, point.y, Qt.LeftButton, Qt.NoModifier, -1);
    }

    function press(category: string): point {
        return root.pressAt(category, root.center(root.handle(category)));
    }
    function pressAt(category: string, point: point): point {
        root.grabPoint = root.tile(category).mapFromItem(scene, point.x, point.y);
        check.equal("the card accepts a left press",
            input.mousePress(scene, point.x, point.y, Qt.LeftButton, Qt.NoModifier, -1), true);
        return point;
    }

    function order(label: string, expected: string): void {
        check.equal(label, JSON.stringify(DailyNotes.orderFor(DailyNotes.today)), expected);
    }

    function retained(): void {
        check.equal("reordering retains every card delegate",
            ["Alpha", "Beta", "Gamma"].every((category, index) => root.tile(category) === root.originalTiles[index]), true);
    }

    function checkGrab(category: string): void {
        const point = root.tile(category).mapFromItem(scene, root.dropPoint.x, root.dropPoint.y);
        check.within("the held card pins the horizontal grab point", point.x, root.grabPoint.x, 1);
        check.within("the held card pins the vertical grab point", point.y, root.grabPoint.y, 1);
    }

    function start(): void {
        check.equal("fixture uses one column", board.columns, 1);
        const categories = ["Alpha", "Beta", "Gamma"];
        root.originalTiles = categories.map(category => root.tile(category));
        check.equal("all cards expose drag headers", categories.every(category => root.handle(category) !== null), true);
        if (categories.some(category => !root.handle(category))) { check.done(); return; }
        root.order("fixture starts in registry order", root.initialOrder);

        const point = root.press("Alpha");
        root.move(Qt.point(point.x + Application.styleHints.startDragDistance / 2, point.y));
        check.equal("small pointer movement does not start a drag", board.dragging, false);
        root.release(point);
        root.order("clicking the header does not reorder", root.initialOrder);
        const task = root.center(root.task());
        input.mouseClick(scene, task.x, task.y, Qt.LeftButton, Qt.NoModifier, -1);
        check.equal("clicking a task still toggles it", DailyNotes.find(root.noteId).done, true);
        const trash = root.center(root.deleteButton("Alpha"));
        input.mouseClick(scene, trash.x, trash.y, Qt.LeftButton, Qt.NoModifier, -1);
        check.equal("clicking the delete button still invokes it", root.deletions, 1);
        root.after(root.forward);
    }

    function forward(): void {
        root.dropPoint = root.center(root.tile("Gamma"));
        const saved = DailyNotes.document;
        const fill = root.tile("Alpha").fill;
        root.pressAt("Alpha", root.center(root.task()));
        root.move(root.dropPoint);
        check.equal("a vertical drag from a task starts dragging the card", board.dragging, true);
        root.order("preview does not persist early", root.initialOrder);
        root.after(() => root.previewed(saved, fill));
    }

    function previewed(saved: var, fill: color): void {
        check.equal("the held preview does not change the notes document", DailyNotes.document, saved);
        check.near("the next card animates into the vacated slot while held", root.tile("Beta").y, 0);
        check.equal("the held card targets Gamma", board.gesture?.target, "Gamma");
        root.checkGrab("Alpha");
        const card = root.tile("Alpha");
        check.sameColor("dragging preserves the card's fill", card.fill, fill, 0);
        const left = card.mapToItem(scene, 0, 0);
        const right = card.mapToItem(scene, card.width, 0);
        check.near("the held card takes the window lift scale", right.x - left.x,
            card.width * Appearance.windowDrag.scale);
        check.near("the card straightens while held still", right.y, left.y);
        root.retained();
        root.release(root.dropPoint);
        check.equal("release ends the drag", board.dragging, false);
        check.equal("release clears the gesture", board.gesture, null);
        check.equal("the released card stays raised during landing", card.carried, true);
        check.equal("dragging from a task does not toggle it", DailyNotes.find(root.noteId).done, true);
        root.order("drop inserts at the original target index", root.movedOrder);
        root.after(root.keyboard);
    }

    function keyboard(): void {
        check.equal("landing returns the card to the board", root.tile("Alpha").carried, false);
        check.near("the next card keeps its preview position after the drop", root.tile("Beta").y, 0);
        const header = root.handle("Alpha");
        header.forceActiveFocus(Qt.TabFocusReason);
        check.equal("the drag header accepts keyboard focus", header.activeFocus, true);
        input.keyClick(Qt.Key_Up, Qt.NoModifier, -1);
        root.order("Up moves the focused category one place", '["Beta","Alpha","Gamma"]');
        input.keyClick(Qt.Key_Down, Qt.NoModifier, -1);
        root.order("Down moves the focused category one place", root.movedOrder);
        check.equal("keyboard reordering retains header focus", header.activeFocus, true);
        check.equal("keyboard reordering does not leave a pointer drag", board.dragging, false);
        root.after(root.cancelOutside);
    }

    function cancelOutside(): void {
        root.retained();
        const card = root.tile("Beta");
        const inset = Appearance.s.md / 2;
        root.pressAt("Beta", card.mapToItem(scene, inset, card.height - inset));
        const target = root.center(root.tile("Alpha"));
        root.move(target);
        check.equal("the card's padding starts a drag", board.dragging, true);
        const outside = Qt.point(scrollViewport.x / 2, target.y);
        root.move(outside);
        root.release(outside);
        check.equal("outside release clears the drag", board.dragging, false);
        root.order("dropping outside cancels the preview", root.movedOrder);
        root.after(root.loseFocus);
    }

    function loseFocus(): void {
        const target = root.center(root.tile("Beta"));
        root.press("Alpha");
        root.move(target);
        check.equal("the card is held before focus changes", board.dragging, true);
        root.stealingFocus = true;
        root.after(() => {
            check.equal("losing window focus cancels the drag", board.dragging, false);
            root.order("losing focus does not commit the preview", root.movedOrder);
            root.release(target);
            root.stealingFocus = false;
            root.viewportWidth = 420;
            root.viewportHeight = 190;
            for (let i = 1; i <= 12; ++i)
                DailyNotes.addCategory(DailyNotes.today, "Extra " + i);
            root.after(root.scrollDrag);
        });
    }

    function scrollDrag(): void {
        check.equal("wide scroll fixture uses two columns", board.columns, 2);
        const first = root.tile("Beta");
        const below = board.children.filter(tile => tile instanceof DailyNoteCategory && tile.x === first.x && tile.y > first.y);
        const slots = below.map(tile => tile.mapToItem(board, 0, 0));
        check.equal("the dragged card tops a column with several cards below", first.y === 0 && below.length > 1, true);
        const point = root.pressAt("Beta", root.center(root.deleteButton("Beta")));
        root.scrollStart = board.mapToItem(scene, 0, 0).y;
        root.dropPoint = Qt.point(scrollViewport.x + scrollViewport.width * 0.7,
            scrollViewport.y + scrollViewport.height - 2);
        root.move(Qt.point(point.x, point.y + Application.styleHints.startDragDistance + 2));
        check.equal("vertical dragging from a card button takes the grab from the scrolling view", board.dragging, true);
        root.move(root.dropPoint);
        check.equal("the pointer crosses to the other column", root.dropPoint.x - point.x > board.columnWidth / 2, true);
        root.after(() => {
            check.equal("holding the card at the edge scrolls the board",
                board.mapToItem(scene, 0, 0).y < root.scrollStart - Appearance.windowDrag.edge, true);
            check.equal("the source column compacts during edge scroll without switching lanes", below.every((tile, i) => {
                const point = tile.mapToItem(board, 0, 0);
                return point.x === slots[i].x && Math.abs(point.y + first.height + board.gap - slots[i].y) < 0.001;
            }), true);
            root.checkGrab("Beta");
            root.release(root.dropPoint);
            check.equal("dragging from a card button does not invoke it", root.deletions, 1);
            check.equal("dropping after edge scroll ends the drag", board.dragging, false);
            check.equal("the drop reaches a category below the original viewport",
                DailyNotes.orderFor(DailyNotes.today).indexOf("Beta") > DailyNotes.orderFor(DailyNotes.today).indexOf("Extra 8"), true);
            root.after(() => {
                root.retained();
                check.done();
            });
        });
    }

    Component.onCompleted: {
        if (Quickshell.env("TEST_BIN") === "") {
            check.report("isolated test runner required", false, "run tools/test.sh DailyNotesDragTest");
            check.done();
            return;
        }
        ready.until(DailyNotes.readyChanged, () => DailyNotes.ready, ok => {
            check.equal("notes service is ready", ok, true);
            if (!ok) { check.done(); return; }
            for (const category of ["Alpha", "Beta", "Gamma"])
                DailyNotes.addCategory(DailyNotes.today, category);
            check.equal("the drag fixture saves a task", DailyNotes.save(DailyNotes.today, "", "Alpha task", "", "", "Alpha"), true);
            root.noteId = DailyNotes.document.notes[0].id;
            root.seeded = true;
            root.after(root.start);
        });
    }
}
