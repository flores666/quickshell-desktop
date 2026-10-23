import QtQuick
import "root:/config"
import "root:/modules/common"

/*!
    A card rolling out of the edge it hangs from as it opens, and back in as
    it closes (OverlayCard.door): its edge on the door stays put, the other
    comes and goes, its contents ride the moving edge, it is never shorter
    than its two corners — a rounded rectangle all the way, never a capsule —
    and shut it draws nothing.
*/
Item {
    id: root

    /*! As tall as a card's two corners: the shortest a door is. */
    readonly property real corners: Appearance.r.panel * 2

    Check {
        id: check
    }

    // Under the bar, rolling down out of its top edge.
    OverlayCard {
        id: under
        overlayId: "doorDown"
        shown: false
        settled: true
        door: Qt.TopEdge
        rest: Qt.rect(100, 50, 300, 200)
        contentData: Item {
            id: underContents
            anchors.fill: parent
        }
    }

    // Under the bar too, closed while it flies.
    OverlayCard {
        id: flier
        overlayId: "doorFlier"
        shown: false
        settled: true
        door: Qt.TopEdge
        rest: Qt.rect(1000, 50, 300, 200)
    }

    // Above the dock, rolling up out of its bottom edge.
    OverlayCard {
        id: above
        overlayId: "doorUp"
        shown: false
        settled: true
        door: Qt.BottomEdge
        rest: Qt.rect(600, 500, 260, 180)
        contentData: Item {
            id: aboveContents
            anchors.fill: parent
        }
    }

    Component.onCompleted: {
        check.near("shut: as tall as its corners", under.height, root.corners);
        check.near("shut: nothing drawn", under.opacity, 0);
        check.near("shut above the dock: at its bottom edge", above.y + above.height, 680);
        under.shown = true;
        above.shown = true;
        flier.shown = true;
        opening.start();
    }

    Timer {
        id: opening
        interval: Appearance.t.popupMove / 2
        onTriggered: {
            check.near("rolling down: its top edge stays put", under.y, 50);
            check.equal("rolling down: partly out, never shorter than its corners",
                under.height > root.corners && under.height < 200, true);
            check.equal("rolling down: fading in", under.opacity > 0, true);
            check.near("rolling down: contents ride its bottom edge",
                underContents.mapToItem(under, 0, 0).y, under.height - 200);
            check.near("rolling up: its bottom edge stays put", above.y + above.height, 680);
            check.equal("rolling up: partly out, never shorter than its corners",
                above.height > root.corners && above.height < 180, true);
            check.near("rolling up: contents ride its top edge", aboveContents.mapToItem(above, 0, 0).y, 0);
            open.start();
        }
    }

    Timer {
        id: open
        interval: Appearance.t.popupMove / 2 + 100
        onTriggered: {
            check.box("open under the bar: at rest", under, Qt.rect(100, 50, 300, 200));
            check.near("open: solid", under.opacity, 1);
            check.box("open above the dock: at rest", above, Qt.rect(600, 500, 260, 180));

            // A door takes no part in a flight: closed mid-flight, it lands
            // whole and only then rolls in.
            flier.from = Qt.rect(1000, 400, 200, 100);
            flier.flown = 0.5;
            flier.shown = false;
            check.near("closed mid-flight: its door held out", flier.rolled, 1);
            flier.flown = 1;
            check.near("closed mid-flight: lands at its full height", flier.height, 200);

            under.shown = false;
            above.shown = false;
            closing.start();
        }
    }

    Timer {
        id: closing
        interval: Appearance.t.popupFade / 2
        onTriggered: {
            check.near("rolling back up: its top edge stays put", under.y, 50);
            check.equal("rolling back up: partly in", under.height > root.corners && under.height < 200, true);
            check.near("rolling back down: its bottom edge stays put", above.y + above.height, 680);
            shut.start();
        }
    }

    Timer {
        id: shut
        // In before the popup lets its card go (ShellOverlay, t.popupFade + t.grace).
        interval: Appearance.t.popupFade / 2 + 50
        onTriggered: {
            check.near("shut again: as tall as its corners", under.height, root.corners);
            check.near("shut again: nothing drawn", under.opacity, 0);
            check.near("shut again above the dock: at its bottom edge", above.y + above.height, 680);
            check.done();
        }
    }
}
