import QtQuick
import Quickshell
import "root:/config"
import "root:/services"
import "root:/modules/common"

/*!
    A popup's card let go once its popup closes: at nothing by t.popupFade,
    kept through t.grace so the fade's last frame is drawn, and gone after.
    A timer stands in for the fade's own end, which a Behavior never reports
    (ShellOverlay).
*/
Item {
    Check {
        id: check
    }

    OverlaySurface {
        ShellOverlay {
            id: popup
            overlayId: "letGo"
            cardHeight: 200
        }
    }

    Component.onCompleted: {
        check.equal("the grace is a motion token", typeof Appearance.t.grace, "number");
        Overlay.open("letGo", Quickshell.screens[0], 0);
        opened.start();
    }

    Timer {
        id: opened
        interval: 500
        onTriggered: {
            check.near("open: solid", popup.cardItem.opacity, 1);
            Overlay.close();
            faded.start();
        }
    }

    Timer {
        id: faded
        interval: Appearance.t.popupFade + 30
        onTriggered: {
            check.near("closed: at nothing by t.popupFade", popup.cardItem.opacity, 0);
            check.equal("closed: kept through t.grace", popup.rendered, true);
            gone.start();
        }
    }

    Timer {
        id: gone
        // From the close: t.popupFade + t.grace and a frame or two.
        interval: Appearance.t.grace + 10
        onTriggered: {
            check.equal("closed: let go after t.popupFade + t.grace", popup.rendered, false);
            check.done();
        }
    }
}
