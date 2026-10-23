import QtQuick
import Quickshell
import "root:/config"
import "root:/services"
import "root:/modules/common"

/*!
    A popup's card in flight: where it is, what it shows and how strongly,
    from the moment it takes off over the card it took over from to the
    moment it rests; that card holding, then going as it takes off; and a
    card given a new subject taking over from itself. The
    cards share a window, as popups' do (OverlaySurface), since a card hands
    over a picture of itself and only an item in a window can be pictured.
*/
Item {
    id: root

    readonly property rect from: Qt.rect(100, 300, 220, 120)

    Check {
        id: check
    }

    FloatingWindow {
        // A card hands over once its window is up, as a popup's is.
        onBackingWindowVisibleChanged: if (backingWindowVisible) root.handOver()
        implicitWidth: 1900
        implicitHeight: 1000
        color: "transparent"

        OverlayCard {
            id: card
            overlayId: Overlay.dateMenu
            shown: true
            settled: false
            rest: Qt.rect(500, 40, 300, 200)
            contentData: Item {
                id: contents
                anchors.fill: parent
            }
        }

        // The card a hand-off is from, and one whose hand-off is dropped.
        OverlayCard {
            id: leaving
            overlayId: Overlay.quickSettings
            shown: true
            settled: true
            rest: Qt.rect(1400, 40, 380, 500)
        }

        OverlayCard {
            id: dropped
            overlayId: Overlay.vpnMenu
            shown: true
            settled: true
            rest: Qt.rect(1000, 40, 260, 180)
        }

        // Up, and given a new subject.
        OverlayCard {
            id: renewed
            overlayId: Overlay.trayMenu
            shown: true
            settled: true
            rest: Qt.rect(200, 600, 240, 160)
        }
    }

    Component.onCompleted: {
        const screen = Quickshell.screens[0];

        check.equal("at rest it is not flying", card.flying, false);
        check.equal("at rest its contents are opaque", card.incoming, 1);
        check.equal("at rest there is nothing outgoing", card.outgoing, 0);
        check.near("at rest: x", card.x, 500);
        check.near("at rest: width", card.width, 300);
        check.near("at rest: height", card.height, 200);

        // As ShellOverlay settles a popup taking over: the old card's place,
        // in the window they share, a stand-in picture, and the old card
        // still fading in.
        Overlay.open(Overlay.launcher, screen, 0);
        Overlay.open(Overlay.dateMenu, screen, 0);
        check.equal("waits for the old card's picture", card.waiting, true);
        Overlay.depart(Overlay.launcher, root.from, 0.4, { url: "" });
        check.equal("the old card stays until this one takes off", Overlay.flight?.away, false);
        card.arrive();
        card.settled = true;
        check.equal("flying once it takes off", card.flying, true);
        check.near("as strong as the old card on its first frame", card.opacity, 0.4);
        check.box("starts exactly over the old card", card, root.from);
        check.equal("the old card goes in the frame this one takes off", Overlay.flight?.away, true);

        card.flown = 0.25;
        check.box("a quarter of the way", card, Qt.rect(200, 235, 240, 140));
        check.near("old contents half gone", card.outgoing, 0.5);
        check.near("new contents not in yet", card.incoming, 0);
        check.near("contents keep their size: width", contents.width, 300);
        check.near("contents keep their size: height", contents.height, 200);
        const at = contents.mapToItem(card, 0, 0);
        check.near("contents centred: x", at.x, -30);
        check.near("contents centred: y", at.y, -30);

        card.flown = 0.75;
        check.near("old contents gone", card.outgoing, 0);
        check.near("new contents half in", card.incoming, 0.5);
        card.rest = Qt.rect(600, 40, 300, 200);
        check.near("follows a rest that moves", card.x, 475);
        midway.start();
    }

    function handOver(): void {
        const screen = Quickshell.screens[0];

        // A hand-off that is dropped: the old card closes as it does today.
        Overlay.open(Overlay.vpnMenu, screen, 0);
        Overlay.open(Overlay.launcher, screen, 0);
        dropped.shown = false;
        check.equal("holds while the hand-off stands", dropped.holding, true);
        Overlay.abandon(Overlay.launcher);
        check.equal("lets go once it is dropped", dropped.holding, false);

        // A hand-off taken: the old card holds, then goes at once.
        Overlay.open(Overlay.quickSettings, screen, 0);
        Overlay.open(Overlay.dateMenu, screen, 0);
        leaving.shown = false;
        check.equal("holds from the moment its popup closes", leaving.holding, true);
        landed.start();
    }

    Timer {
        id: midway
        interval: Appearance.t.popupResize / 2
        onTriggered: {
            check.equal("still flying halfway through t.popupResize", card.flying, true);
            check.equal("coming in from the old card's strength", card.opacity > 0.4, true);
        }
    }

    Timer {
        id: landed
        interval: Appearance.t.popupResize + 150
        onTriggered: {
            check.equal("landed after t.popupResize", card.flying, false);
            check.box("at rest once landed", card, Qt.rect(600, 40, 300, 200));
            check.equal("contents opaque once landed", card.incoming, 1);
            check.equal("the old picture let go", card.leftBehind, null);

            check.equal("hands over its place on the screen", Overlay.flight?.rect?.toString(),
                Qt.rect(1400, 40, 380, 500).toString());
            check.equal("hands over a picture of itself", (Overlay.flight?.contents?.url ?? "") !== "", true);
            check.equal("held at full strength, not faded", leaving.opacity, 1);
            check.equal("held on screen", leaving.visible, true);
            check.near("a dropped hand-off fades as today", dropped.opacity, 0);
            check.equal("a dropped hand-off is not hidden at once", dropped.visible, true);

            Overlay.arrive(Overlay.dateMenu);
            check.equal("gone at once when the new card takes off", leaving.visible, false);
            check.equal("no longer holding", leaving.holding, false);
            Overlay.open(Overlay.vpnMenu, Quickshell.screens[0], 0);
            check.equal("stays gone through the next hand-off", leaving.visible, false);
            Overlay.open(Overlay.quickSettings, Quickshell.screens[0], 0);
            leaving.shown = true;
            check.equal("switched back to, gone until it is up again", leaving.visible, false);
            leaving.arrive();
            check.equal("back once it is up, here alone", leaving.visible, true);

            Overlay.openWith(Overlay.trayMenu, Quickshell.screens[0], 0, root.oldSubject);
            Overlay.abandon(Overlay.trayMenu);
            Overlay.openWith(Overlay.trayMenu, Quickshell.screens[0], 200, root.newSubject);
            check.equal("a new subject waits for its picture", Overlay.payload, root.oldSubject);
            check.equal("not flying before its picture is in", renewed.flying, false);
            renewal.start();
        }
    }

    readonly property var oldSubject: ({})
    readonly property var newSubject: ({})

    Timer {
        id: renewal
        // A picture is in a frame or two after it is asked for (45–85 ms);
        // the flight it starts takes t.popupResize.
        interval: 150
        onTriggered: {
            check.equal("its picture in, the new subject goes in", Overlay.payload, root.newSubject);
            check.equal("and it takes off", Overlay.flight?.away, true);
            check.equal("from where it rested", renewed.from.toString(),
                Qt.rect(200, 600, 240, 160).toString());
            check.equal("its old contents ride along",
                renewed.flying ? renewed.leftBehind !== null : true, true);
            check.done();
        }
    }
}
