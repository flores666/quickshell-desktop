pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/config"
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

    /*! Where the card sits. Only `Centre` differs across the screen; every
        placement keeps the same `popupGap` from the panel it opens off. */
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

        "Once" is enforced by `frame`, below. The bar's and dock's footprints are
        settable, so they can change while a popup is up — and the popup that
        changes them is this one, holding the settings panel. Left as a live
        binding this would resize and re-margin the very surface the user is
        dragging a slider in, which is the 77px artifact above, on every step.
    */
    readonly property int surfaceHeight: Math.max(root.cardHeight, root.liveHeight,
        (root.screen ? root.screen.height : 1080)
            - root.frame.top - root.frame.bottom - Appearance.m.popupGap * 2)

    /*!
        The room the bar and the dock leave.

        Live while the surface is down, frozen for as long as it is up: the
        window is configured from the footprints as they are at the moment it
        maps, and nothing the user does to the bar while it is on screen moves
        it again. Only the surface reads this — the card's contents read
        Appearance directly, since redrawing them is client-side and free.
    */
    property var frame: root.footprints()

    function footprints(): var {
        return { top: Appearance.m.barFootprint, bottom: Appearance.m.dockFootprint };
    }

    onRenderedChanged: root.frame = root.rendered
        ? root.footprints()
        : Qt.binding(() => root.footprints())
    property int elevation: 3
    /*! What takes the keyboard when the popup opens. */
    property Item initialFocusItem: null

    default property alias content: card.contentData

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
    readonly property int pad: Appearance.shadowFor(root.elevation).pad + Appearance.s.md

    /*!
        Keys the popup did not handle itself; OverlayCard has already taken
        Escape. The popup owns its own navigation.
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
        // Never negative: a hand-edited settings.json can put the bar closer to
        // the top than a level-3 shadow is deep, and a negative layer-shell
        // margin pushes the surface off the edge it is anchored to.
        top: Math.max(0, root.frame.top + Appearance.m.popupGap - root.pad)
        bottom: Math.max(0, root.frame.bottom + Appearance.m.popupGap - root.pad)
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
    onShownChanged: {
        if (root.shown) {
            root.rendered = true;
            Qt.callLater(() => (root.initialFocusItem ?? card).forceActiveFocus());
        } else {
            Overlay.setPointerOver("popup", false);
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

    OverlayCard {
        id: card

        shown: root.shown
        settled: root.settled
        x: root.cardX
        // Bottom-anchored popups keep their bottom edge against the dock, so the
        // room a resize is holding sits above the card rather than below it.
        restY: root.pad
            + (root.placement === ShellOverlay.Placement.AboveDock
                ? root.surfaceHeight - root.liveHeight : 0)
        width: root.cardWidth
        height: root.liveHeight
        elevation: root.elevation
        onKeyPressed: event => root.keyPressed(event)
    }
}
