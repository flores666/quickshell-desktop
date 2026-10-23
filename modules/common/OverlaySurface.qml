pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/config"
import "root:/services"

/*!
    The one window every popup's card is drawn in: the launcher's, quick
    settings', the date menu's, the settings panel's and the menus'. Each
    popup is a ShellOverlay laid over `room`, so a card's place is the same in
    every popup's coordinates.

    One window for all of them, so that a popup opened over another takes the
    card over inside a single frame (OverlayCard's flight). Each popup used to
    have a window of its own, and two surfaces commit their frames apart: the
    compositor showed a frame with neither card, or one with both stacked —
    glass on glass, darker — whichever came first, a blink.

    The window is the space a popup may occupy; the cards inside it are the
    popups. Input is masked to the open popup's card, so a click outside lands
    on whatever is under it — the application still gets that click, and hover
    keeps working everywhere.

    It follows Overlay.screen, which is set to the focused monitor when a popup
    opens.
*/
PanelWindow {
    id: root

    /*! The popups, each a ShellOverlay filling the room. */
    default property alias popups: room.data

    /*! The popup open, if any; and whether any card is drawn, the one open or
        one fading or holding on its way out. */
    readonly property ShellOverlay open: {
        for (const child of room.children) {
            const host = child as ShellOverlay;
            if (host?.shown)
                return host;
        }
        return null;
    }
    readonly property bool drawn: {
        for (const child of room.children) {
            if ((child as ShellOverlay)?.rendered)
                return true;
        }
        return false;
    }

    /*!
        What the surface is sized to: the whole space a popup may occupy, not a
        card — the room between the bar and the dock, or more for a card taller
        than that.

        Changing a layer surface's geometry is a round trip through the
        compositor, and the compositor animates the result — an anchored surface
        is moved towards its new box while the old buffer is still on screen.
        Measured on a shrinking dock menu whose card had not moved at all in the
        scene: the bottom edge leapt 77px and eased back over eight frames. No
        client-side compensation can cancel that, because the frames are drawn
        from a buffer the shell has already committed.

        So the surface is never resized while a popup is up. It is given the
        room between the bar and the dock once, and the cards animate inside
        it, which is pure client-side rendering the compositor never sees. The
        rest of the surface is transparent and masked out of the input region,
        the same way the dock's window is far wider than the dock.

        "Once" is enforced by `frame`, below. The bar's and dock's footprints are
        settable, so they can change while a popup is up — and the popup that
        changes them is one of these, the settings panel. Left as a live binding
        this would resize and re-margin the very surface the user is dragging a
        slider in, which is the 77px artifact above, on every step.
    */
    readonly property int surfaceHeight: {
        let height = room.height;
        for (const child of room.children) {
            const host = child as ShellOverlay;
            if (host?.rendered)
                height = Math.max(height, host.cardHeight, host.liveHeight);
        }
        return height;
    }

    /*!
        The room the bar and the dock leave.

        Live while the surface is down, frozen for as long as it is up: the
        window is configured from the footprints as they are at the moment it
        maps, and nothing the user does to the bar while it is on screen moves
        it again. Only the surface reads this — the cards' contents read
        Appearance directly, since redrawing them is client-side and free.
    */
    property var frame: root.footprints()

    function footprints(): var {
        return { top: Appearance.m.barFootprint, bottom: Appearance.m.dockFootprint };
    }

    onDrawnChanged: root.frame = root.drawn
        ? root.footprints()
        : Qt.binding(() => root.footprints())

    /*! The shadow the cards cast, the window shadow, and the room it needs to
        spread outside a card. */
    property int elevation: 3
    readonly property int pad: Appearance.shadowFor(root.elevation).pad + Appearance.s.md
    /*!
        How much of that room there is above and below the cards: no more than
        lies between them and the screen's edge. A level-3 shadow is deeper than
        the bar is tall, and what does not fit is cut off by the screen's edge
        rather than pushing a card off its place under the bar or above the
        dock; a negative layer-shell margin would instead push the surface off
        the edge it is anchored to.
    */
    readonly property int padTop: Math.min(root.pad, root.frame.top + Appearance.m.popupGap)
    readonly property int padBottom: Math.min(root.pad, root.frame.bottom + Appearance.m.popupGap)

    screen: Overlay.screen
    visible: root.drawn
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    implicitHeight: root.surfaceHeight + root.padTop + root.padBottom

    anchors {
        left: true
        right: true
        top: true
    }

    margins.top: root.frame.top + Appearance.m.popupGap - root.padTop

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "shell-popups"
    /*!
        On-demand, never exclusive: an exclusive layer surface in Hyprland takes
        the pointer as well as the keyboard, which would stop clicks reaching
        the application underneath. On-demand still gives the popup the keyboard
        it needs for typing and Escape.
    */
    WlrLayershell.keyboardFocus: root.open !== null
        ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    /*!
        Input lands on the open popup's card and nowhere else — not on a card
        on its way out, and not even on the shadow around one, which is only
        paint.

        Dismissal on an outside click: nothing here captures input. Hyprland
        reports every pointer press through a non-consuming bind (see
        hyprland.conf), and Overlay decides: the press closes the popup unless
        the pointer is over one of the shell's own surfaces. The click itself is
        delivered to whatever is underneath either way, and hover out there is
        never interrupted.
    */
    mask: Region { item: root.open?.cardItem ?? null }

    Item {
        id: room
        y: root.padTop
        width: parent.width
        height: (root.screen ? root.screen.height : 1080)
            - root.frame.top - root.frame.bottom - Appearance.m.popupGap * 2
    }
}
