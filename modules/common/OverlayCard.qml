pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    The visible card of a popup: how it appears, fades and takes input.

    Where it sits and how big it is belong to ShellOverlay, which owns the
    surface around it; this is only what the card does once placed.
*/
Surface {
    id: card

    /*! Whether the popup is open. Hover and the keyboard follow this alone. */
    required property bool shown
    /*! Whether the card's geometry has caught up with its content (see
        ShellOverlay.settled). Until then it is invisible and does not animate. */
    required property bool settled
    /*! Where the card rests; `y` adds the entry slide to it. */
    property real restY: 0

    /*! Keys the card did not handle itself. */
    signal keyPressed(var event)

    /*! What the popup puts in the card. Not the default property: Surface's
        own `content` is, and is where this file's children go. */
    property alias contentData: body.data

    /*!
        The short slide the card makes as it appears. Animated on its own
        rather than through `y`, so that the resize compensation in `restY`
        stays exactly in step with the height instead of chasing it on a
        different curve — which is the bottom edge of the card visibly drifting.
    */
    property real entry: card.shown && card.settled ? 0 : -Appearance.s.md

    Behavior on entry {
        NumberAnimation { duration: Appearance.t.base; easing.type: Appearance.t.emphasizedEasing }
    }

    Behavior on x {
        // Same clock and curve as the height, so a popup that re-anchors and
        // resizes at once reads as one movement. Not while it is still being
        // placed: it must appear where it belongs, not slide in from the
        // last popup's position.
        enabled: card.settled
        NumberAnimation { duration: Appearance.t.resize; easing.type: Appearance.t.resizeEasing }
    }

    y: card.restY + card.entry
    // One radius for every panel; no popup picks its own.
    radius: Appearance.r.panel
    opacity: card.shown && card.settled ? 1 : 0

    Behavior on opacity {
        NumberAnimation { duration: Appearance.t.fast; easing.type: Appearance.t.standardEasing }
    }

    HoverHandler {
        id: pointer
        onHoveredChanged: Overlay.setPointerOver("popup", pointer.hovered && card.shown)
    }

    Item {
        id: body
        anchors.fill: parent
        // The card's contents never draw outside the card. While the card is
        // animating to a new height its content is already at full size, and
        // without this it spills over the edge onto the desktop.
        clip: true
        // Fades as one flattened image. An opacity on the card is applied to
        // every descendant separately, so a control drawn from opaque shapes
        // painted over each other shows through itself: a quick-settings tile
        // that has a detail page is a body, a chevron and a rectangle bridging
        // the seam between them, and each one it overlaps adds its colour
        // again. Measured on the closing fade, with the tile at accent: the
        // seam read 60% brighter than the tile around it.
        layer.enabled: card.opacity < 1
    }

    /*! Escape is consumed here; anything else is offered to the popup, which
        owns its own navigation. */
    Keys.onPressed: event => {
        InputMode.keyboardUsed();
        if (event.key === Qt.Key_Escape) {
            Overlay.close();
            event.accepted = true;
            return;
        }
        card.keyPressed(event);
    }
}
