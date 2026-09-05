pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    The shared chrome for every shell popup: launcher, quick settings, the date
    menu and the two popup menus.

    The window is the space a popup may occupy; the card inside it is the popup
    (see `surfaceHeight`). Input is masked to the card, so a click outside lands
    on whatever is under it — the application still gets that click, and hover
    keeps working everywhere.

    One instance exists per popup, not per screen; it follows Overlay.screen,
    which is set to the focused monitor when the popup opens.
*/
PanelWindow {
    id: root

    enum Placement { BelowBar, AboveDock, Centre }

    required property string overlayId
    property int placement: ShellOverlay.Placement.BelowBar
    /*! Size of the visible card. The window adds room for its shadow. */
    property int cardWidth: Appearance.m.popoverWidth
    property int cardHeight: 200
    /*!
        Where the card sits across the screen, clamped so it never hangs off an
        edge. The surface spans the whole width, so re-anchoring a popup that is
        already up — right-clicking a second dock icon — moves the card and not
        the surface, on the same clock as the resize. Moving the surface instead
        hands the move to the compositor, which animates it on a schedule of its
        own: measured as the card gliding sideways for ~380ms while its height
        had already finished changing in 150.
    */
    readonly property int cardX: {
        const screenWidth = root.screen ? root.screen.width : 1920;
        const centre = root.placement === ShellOverlay.Placement.Centre
            ? screenWidth / 2 : Overlay.anchorX;
        const edge = Appearance.s.md;
        return Math.round(Math.max(edge,
            Math.min(screenWidth - root.cardWidth - edge, centre - root.cardWidth / 2)));
    }

    /*! The card's height as drawn; animates towards `cardHeight`. */
    property int liveHeight: root.cardHeight

    Behavior on liveHeight {
        // Only once the popup is up: a card still being placed must appear at
        // its size rather than grow into it.
        enabled: root.settled
        NumberAnimation { duration: Appearance.t.resize; easing.type: Appearance.t.resizeEasing }
    }
    /*!
        What the surface is sized to: the whole space a popup may occupy, not the
        card.

        Changing a layer surface's geometry is a round trip through the
        compositor, and the compositor animates the result — an anchored surface
        is moved towards its new box while the old buffer is still on screen.
        Measured on a shrinking dock menu whose card had not moved at all in the
        scene: the bottom edge leapt 77px and eased back over eight frames. No
        client-side compensation can cancel that, because the frames are drawn
        from a buffer the shell has already committed.

        So the surface is never resized while a popup is up. It is given the
        room between the bar and the dock once, and the card animates inside it,
        which is pure client-side rendering the compositor never sees. The rest
        of the surface is transparent and masked out of the input region, the
        same way the dock's window is far wider than the dock.
    */
    readonly property int surfaceHeight: Math.max(root.cardHeight, root.liveHeight,
        (root.screen ? root.screen.height : 1080)
            - Appearance.m.barHeight - Appearance.m.dockFootprint - Appearance.s.md * 2)
    property int elevation: 3
    property int cardRadius: Appearance.r.lg
    /*! What takes the keyboard when the popup opens. */
    property Item initialFocusItem: null

    default property alias content: body.data

    readonly property bool shown: Overlay.isOpen(root.overlayId)
    /*! Stays true through the closing animation so the popup can fade out. */
    property bool rendered: false
    /*!
        Whether the card's geometry has caught up with its content.

        The first size a popup's card is given is always stale (see the
        FrameAnimation below), because Qt cannot lay the content out until the
        surface exists. The card stays transparent until its size stops
        changing; the surface around it is empty, so there is nothing to see
        meanwhile.
    */
    property bool settled: false
    /*!
        Overlay.payload, held for as long as the popup is on screen.

        Reading the service directly would empty the popup the instant it starts
        closing, collapsing the card mid-fade.
    */
    property var subject: null
    /*! Room for the shadow to spread outside the card. */
    readonly property int pad: Appearance.shadowFor(root.elevation).blur + Appearance.s.md

    /*!
        Keys the popup did not handle itself. Escape is consumed here; anything
        else is offered to the popup, which owns its own navigation.
    */
    signal keyPressed(var event)

    screen: Overlay.screen
    visible: root.rendered
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    implicitHeight: root.surfaceHeight + root.pad * 2

    anchors {
        left: true
        right: true
        top: root.placement !== ShellOverlay.Placement.AboveDock
        bottom: root.placement === ShellOverlay.Placement.AboveDock
    }

    margins {
        top: root.placement === ShellOverlay.Placement.Centre
            ? Math.round((root.screen ? root.screen.height : 1080) * 0.07) - root.pad
            : Appearance.m.barHeight + Appearance.s.md - root.pad
        bottom: Appearance.m.dockFootprint + Appearance.s.md - root.pad
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "shell-" + root.overlayId
    /*!
        On-demand, never exclusive: an exclusive layer surface in Hyprland takes
        the pointer as well as the keyboard, which would stop clicks reaching
        the application underneath. On-demand still gives the popup the keyboard
        it needs for typing and Escape.
    */
    WlrLayershell.keyboardFocus: root.shown
        ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    /*!
        Input lands on the card and nowhere else — not even on the shadow around
        it, which is only paint.
    */
    mask: Region { item: root.shown ? card : null }

    /*!
        Dismissal on an outside click.

        Nothing here captures input. Hyprland reports every pointer press through
        a non-consuming bind (see hyprland.conf), and Overlay decides: the press
        closes the popup unless the pointer is over one of the shell's own
        surfaces. The click itself is delivered to whatever is underneath either
        way, and hover out there is never interrupted.
    */
    onShownChanged: if (!root.shown) Overlay.setPointerOver("popup", false)

    // Connected explicitly rather than through an `onShownChanged` handler on the
    // root, because several popups declare one of their own and a handler in a
    // derived component replaces the base component's.
    Connections {
        target: root

        function onShownChanged(): void {
            if (root.shown) {
                root.rendered = true;
                Qt.callLater(() => (root.initialFocusItem ?? card).forceActiveFocus());
            }
        }
    }

    FrameAnimation {
        // Watches the card settle. Qt lays a window's contents out only while
        // that window is mapped, so nothing can be measured before the surface
        // exists and the size the card is first given is whatever the last
        // subject left behind; the real one lands a layout pass later. `running`
        // is a plain binding, like the unmap timer's, so this cannot be left
        // armed.
        id: settle

        property int lastWidth: -1
        property int lastHeight: -1

        running: root.rendered && !root.settled
        onRunningChanged: {
            settle.lastWidth = -1;
            settle.lastHeight = -1;
        }
        onTriggered: {
            // Bounded: a popup still filling in — a tray menu waiting on DBus —
            // must appear even if its size never quite stops moving.
            root.settled = (settle.lastWidth === root.cardWidth
                    && settle.lastHeight === root.cardHeight)
                || settle.elapsedTime * 1000 >= Appearance.t.fast;
            settle.lastWidth = root.cardWidth;
            settle.lastHeight = root.cardHeight;
        }
    }

    Connections {
        // Tracked here rather than off `shown`, because the service sets the
        // subject before it opens the popup — and because asking for a second
        // tray icon's menu while the first is still up changes the subject
        // without the popup ever closing.
        target: Overlay

        function onPayloadChanged(): void {
            // Only the popup on screen keeps the subject as it is cleared; the
            // rest drop it there and then rather than holding it until they are
            // next opened.
            if (Overlay.payload !== null || !root.rendered)
                root.subject = Overlay.payload;
        }
    }

    Timer {
        // Unmaps the surface once the fade-out has played. This cannot hang off
        // the animation itself: an animation driven by a Behavior never emits
        // finished(). `running` is a plain binding, so the surface is unmapped
        // even if the property changes while no handler is watching.
        running: root.rendered && !root.shown
        interval: Appearance.t.fast + 60
        onTriggered: {
            root.rendered = false;
            root.settled = false;
            root.subject = null;
        }
    }

    Surface {
        id: card

        /*!
            The short slide the card makes as it appears. Animated on its own
            rather than through `y`, so that the resize compensation below stays
            exactly in step with the height instead of chasing it on a different
            curve — which is the bottom edge of the card visibly drifting.
        */
        property real entry: root.shown && root.settled ? 0 : -Appearance.s.md

        Behavior on entry {
            NumberAnimation { duration: Appearance.t.base; easing.type: Appearance.t.emphasizedEasing }
        }

        x: root.cardX

        Behavior on x {
            // Same clock and curve as the height, so a popup that re-anchors and
            // resizes at once reads as one movement. Not while it is still being
            // placed: it must appear where it belongs, not slide in from the
            // last popup's position.
            enabled: root.settled
            NumberAnimation { duration: Appearance.t.resize; easing.type: Appearance.t.resizeEasing }
        }
        // Bottom-anchored popups keep their bottom edge against the dock, so the
        // room a resize is holding sits above the card rather than below it.
        y: root.pad + card.entry
            + (root.placement === ShellOverlay.Placement.AboveDock
                ? root.surfaceHeight - root.liveHeight : 0)
        width: root.cardWidth
        height: root.liveHeight
        radius: root.cardRadius
        elevation: root.elevation
        opacity: root.shown && root.settled ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Appearance.t.fast; easing.type: Appearance.t.standardEasing }
        }

        HoverHandler {
            id: pointer
            onHoveredChanged: Overlay.setPointerOver("popup", pointer.hovered && root.shown)
        }

        Item {
            id: body
            anchors.fill: parent
            // The card's contents never draw outside the card. While the card is
            // animating to a new height its content is already at full size, and
            // without this it spills over the edge onto the desktop.
            clip: true
        }

        Keys.onPressed: event => {
            InputMode.keyboardUsed();
            if (event.key === Qt.Key_Escape) {
                Overlay.close();
                event.accepted = true;
                return;
            }
            root.keyPressed(event);
        }
    }
}
