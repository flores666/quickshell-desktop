pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Quickshell
import "root:/components"

// Drawing and dragging must be inverses even with a minimum-size thumb,
// overscroll, a tiny track, and a ListView whose first row has been removed.
Item {
    id: root
    Check { id: check }
    TestEvent { id: pointer }

    FloatingWindow {
        implicitWidth: 300
        implicitHeight: 220

        Flickable {
            id: view
            width: 100; height: 100
            contentWidth: 1000; contentHeight: 1000
        }
        ThinScrollBar { id: vertical; flickable: view }
        ThinScrollBar { id: horizontal; flickable: view; vertical: false }

        ListView {
            id: list
            x: 150; width: 100; height: 100
            model: ListModel { id: rows }
            delegate: Item { width: list.width; height: 100 }
        }
        ThinScrollBar { id: listBar; flickable: list }
    }

    function roundTrip(bar: ThinScrollBar, position: real): void {
        view.contentX = position;
        view.contentY = position;
        bar.scrollTo(bar.lead);
        check.near("thumb round trip " + bar.vertical + " at " + position,
            bar.vertical ? view.contentY : view.contentX, Math.max(0, Math.min(900, position)));
    }

    function start(): void {
        for (const p of [-10, 0, 500, 900, 950]) {
            root.roundTrip(vertical, p);
            root.roundTrip(horizontal, p);
        }
        view.contentY = 500;
        const old = view.contentY;
        const grab = vertical.children.find(c => c.pointerPressed !== undefined);
        check.equal("pointer grabs the thumb", pointer.mousePress(grab, 2, vertical.lead + 5, Qt.LeftButton, Qt.NoModifier, -1), true);
        pointer.mouseMove(grab, 2, vertical.lead + 5, -1, Qt.LeftButton, Qt.NoModifier);
        pointer.mouseRelease(grab, 2, vertical.lead + 5, Qt.LeftButton, Qt.NoModifier, -1);
        check.near("grabbing a minimum thumb does not jump", view.contentY, old);
        view.contentHeight = 200;
        view.contentY = 50;
        vertical.scrollTo(vertical.lead);
        check.near("proportional thumb round trip", view.contentY, 50);
        view.contentHeight = 100;
        check.equal("no overflow hides the bar", vertical.visible, false);
        view.contentHeight = 1000;
        view.height = 10;
        check.equal("thumb fits a tiny track", vertical.thumbLength, vertical.span);
        vertical.scrollTo(100);
        check.equal("no travel stays finite", isFinite(view.contentY), true);
        list.positionViewAtIndex(8, ListView.Beginning);
        rows.remove(0);
        frames.phase = 1;
        frames.ticks = 0;
        frames.running = true;
    }

    FrameAnimation {
        id: frames
        property int ticks: 0
        property int phase: 0
        running: true
        onTriggered: {
            if (++frames.ticks < 3) return;
            frames.running = false;
            if (frames.phase === 0) root.start();
            else {
                check.equal("removed rows shift the list origin", list.originY !== 0, true);
                const before = list.contentY;
                listBar.scrollTo(listBar.lead);
                check.near("nonzero origin round trip", list.contentY, before);
                listBar.scrollTo(0);
                check.near("track starts at the list origin", list.contentY, list.originY);
                check.done();
            }
        }
    }
    Component.onCompleted: { for (let i = 0; i < 15; i++) rows.append({ value: i }); }
}
