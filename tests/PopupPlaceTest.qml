import QtQuick
import Quickshell
import "root:/config"
import "root:/services"
import "root:/modules/common"

/*!
    Where popups' cards rest on the screen, all of them in the one window
    (OverlaySurface): `popupGap` under the bar or above the dock, whatever the
    placement, and in the same coordinates in every popup, which is what lets
    one card take over from another's place; and the edge each rolls out of.
*/
Item {
    Check {
        id: check
    }

    OverlaySurface {
        id: surface

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
    }

    /*! A card's top on the screen, at rest. */
    function topOf(host: ShellOverlay): real {
        return surface.margins.top + surface.padTop + host.cardItem.rest.y;
    }

    Component.onCompleted: {
        const screen = Quickshell.screens[0];
        // Placed on a screen without being opened, so nothing maps.
        Overlay.screen = screen;
        const underBar = Appearance.m.barFootprint + Appearance.m.popupGap;
        check.equal("nothing open: the surface is down", surface.visible, false);
        check.near("a card under the bar, on the screen", topOf(below), underBar);
        check.near("a centred card, on the screen", topOf(centre), underBar);
        check.near("a card above the dock, on the screen", topOf(above) + above.cardItem.rest.height,
            screen.height - Appearance.m.dockFootprint - Appearance.m.popupGap);
        check.equal("under the bar: rolls out of it", below.cardItem.door, Qt.TopEdge);
        check.equal("above the dock: rolls out of it", above.cardItem.door, Qt.BottomEdge);
        check.equal("centred: rolls out of the bar it hangs under", centre.cardItem.door, Qt.TopEdge);
        check.near("every popup in the same coordinates: x", below.mapToItem(above, 0, 0).x, 0);
        check.near("every popup in the same coordinates: y", below.mapToItem(above, 0, 0).y, 0);
        check.done();
    }
}
