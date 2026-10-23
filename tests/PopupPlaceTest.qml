import QtQuick
import Quickshell
import "root:/config"
import "root:/services"
import "root:/modules/common"

/*!
    A popup's window on its screen (ShellOverlay.top): what turns a card's
    place in one popup's window into its place in another's. At rest a card
    sits `popupGap` under the bar or above the dock, on the screen.
*/
Item {
    Check {
        id: check
    }

    ShellOverlay {
        id: below
        overlayId: "placeBelow"
        cardHeight: 200
    }

    ShellOverlay {
        id: centre
        overlayId: "placeCentre"
        placement: ShellOverlay.Placement.Centre
        cardHeight: 200
    }

    ShellOverlay {
        id: above
        overlayId: "placeAbove"
        placement: ShellOverlay.Placement.AboveDock
        cardHeight: 200
    }

    Component.onCompleted: {
        const screen = Quickshell.screens[0];
        // Placed on a screen without being opened, so nothing maps.
        Overlay.screen = screen;
        const underBar = Appearance.m.barFootprint + Appearance.m.popupGap;
        check.near("a card under the bar, on the screen", below.top + below.padTop, underBar);
        check.near("a centred card, on the screen", centre.top + centre.padTop, underBar);
        check.near("a card above the dock, on the screen",
            above.top + above.padTop + above.surfaceHeight,
            screen.height - Appearance.m.dockFootprint - Appearance.m.popupGap);
        check.done();
    }
}
