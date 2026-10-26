import QtQuick
import QtTest
import Quickshell
import "root:/services"
import "root:/modules/common"

/*!
    Whether the pointer is over the open popup (Overlay.pointerOverShell),
    which is what keeps a click on it from closing it, through the two ways
    one card hands over to another under a resting pointer: a popup opened
    over another (the date menu's usage cards flying to the task manager),
    the card it took over from going after the new one is already pointed
    at; and a popup closed and opened again before its card has gone. The
    pointer is Qt's own events (TestEvent) on the popups' window.
*/
Item {
    id: root

    Check {
        id: check
    }

    Until {
        id: wait
    }

    TestEvent {
        id: pointer
    }

    // Two stand-in cards where the date menu's and the task manager's are:
    // the one under the bar's middle, the other centred and larger, so a
    // point inside the first is inside the second.
    OverlaySurface {
        ShellOverlay {
            id: from
            overlayId: Overlay.dateMenu
            cardWidth: 660
            cardHeight: 420
            Item { implicitWidth: 660; implicitHeight: 420 }
        }

        ShellOverlay {
            id: to
            overlayId: Overlay.taskManager
            placement: ShellOverlay.Placement.Centre
            cardWidth: 820
            cardHeight: 580
            Item { implicitWidth: 820; implicitHeight: 580 }
        }
    }

    readonly property ShellScreen screen: Quickshell.screens[0]
    readonly property real middle: root.screen.width / 2

    /*! The pointer moved to a point inside both cards, `nudge` px along. */
    function rest(nudge: int): void {
        pointer.mouseMove(from, root.middle + nudge, 200, -1, Qt.NoButton, Qt.NoModifier);
    }

    /*! Waits for a card to be all the way out, then rests the pointer on
        it and waits for the shell to hear it: Qt delivers the hover a frame
        later, for a card that came up under a pointer that did not move. */
    function pointAt(popup: Item, nudge: int, then: var): void {
        wait.until(popup.cardItem.heightChanged, () => popup.cardItem.height === popup.cardHeight, () => {
            root.rest(nudge);
            wait.until(Overlay.pointerRegionsChanged, () => Overlay.pointerOverShell, then);
        });
    }

    Component.onCompleted: {
        wait.bound = 2000;
        Overlay.open(Overlay.dateMenu, root.screen, root.middle);
        root.pointAt(from, 0, over => {
            check.equal("pointed at: over the shell", over, true);
            Overlay.openWith(Overlay.taskManager, root.screen, root.middle, { tab: "performance" });
            root.pointAt(to, 2, () => root.flown());
        });
    }

    function flown(): void {
        wait.until(from.renderedChanged, () => !from.rendered, gone => {
            check.equal("the card taken over from has gone", gone, true);
            root.rest(4);
            // A frame for whatever the move changes to land.
            wait.until(Overlay.pointerRegionsChanged, () => !Overlay.pointerOverShell, lost => {
                check.equal("flown to under the pointer: the shell does not lose it", lost, false);
                Overlay.dismissOnOutsideClick();
                check.equal("a click there leaves it open", Overlay.active, Overlay.taskManager);
                root.reopened();
            });
        });
    }

    function reopened(): void {
        Overlay.close();
        check.equal("closed: not over the shell", Overlay.pointerOverShell, false);
        // Opened again while its card is still up, the pointer resting on it.
        Overlay.open(Overlay.taskManager, root.screen, root.middle);
        root.rest(6);
        wait.until(Overlay.pointerRegionsChanged, () => Overlay.pointerOverShell, over => {
            check.equal("reopened under the pointer: over the shell", over, true);
            Overlay.dismissOnOutsideClick();
            check.equal("a click there leaves it open", Overlay.active, Overlay.taskManager);
            Overlay.close();
            check.done();
        });
    }
}
