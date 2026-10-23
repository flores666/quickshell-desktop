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

    /*! The card's place across and its height as drawn: they animate towards
        `cardX` and `cardHeight` on one clock and curve, so a popup that
        re-anchors and resizes at once reads as one movement. */
    property int liveX: root.cardX
    property int liveHeight: root.cardHeight

    Behavior on liveX {
        // Only once the popup is up: a card still being placed must appear
        // where it belongs and at its size, not slide in from the last
        // popup's place or grow into it.
        enabled: root.settled
        NumberAnimation { duration: Appearance.t.resize; easing.type: Appearance.t.resizeEasing }
    }

    Behavior on liveHeight {
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
        How much of that room there is above and below the card: no more than
        lies between it and the screen's edge. A level-3 shadow is deeper than
        the bar is tall, and what does not fit is cut off by the screen's edge
        rather than pushing the card off its place under the bar or above the
        dock; a negative layer-shell margin would instead push the surface off
        the edge it is anchored to.
    */
    readonly property int padTop: Math.min(root.pad, root.frame.top + Appearance.m.popupGap)
    readonly property int padBottom: Math.min(root.pad, root.frame.bottom + Appearance.m.popupGap)
    /*! The window's top edge on its screen, by which a card is handed between windows. */
    readonly property real top: root.placement === ShellOverlay.Placement.AboveDock
        ? (root.screen ? root.screen.height : 1080) - root.margins.bottom - root.implicitHeight
        : root.margins.top

    /*!
        Keys the popup did not handle itself; OverlayCard has already taken
        Escape. The popup owns its own navigation.
    */
    signal keyPressed(var event)

    screen: Overlay.screen
    visible: root.rendered
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    implicitHeight: root.surfaceHeight + root.padTop + root.padBottom

    anchors {
        left: true
        right: true
        top: root.placement !== ShellOverlay.Placement.AboveDock
        bottom: root.placement === ShellOverlay.Placement.AboveDock
    }

    margins {
        top: root.frame.top + Appearance.m.popupGap - root.padTop
        bottom: root.frame.bottom + Appearance.m.popupGap - root.padBottom
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
            // Taking over from another popup: placed afresh, though it may
            // still be up from closing a moment ago, so it can take off.
            if (Overlay.flight?.to === root.overlayId)
                root.settled = false;
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
            // must appear even if its size never quite stops moving, and one
            // taking over waits no longer for the other's picture.
            const late = settle.elapsedTime * 1000 >= Appearance.t.fast;
            const steady = settle.lastWidth === root.cardWidth && settle.lastHeight === root.cardHeight;
            settle.lastWidth = root.cardWidth;
            settle.lastHeight = root.cardHeight;
            if ((steady && !card.waiting) || late) {
                card.arrive();
                root.settled = true;
            }
        }
    }

    Connections {
        // The service makes a popup the active one before it hands over the
        // payload, so the popup shown is the one it is for and no other takes
        // it: every popup used to, and a tray item reached the dock's menu.
        // Tracked off the payload rather than `shown`, because asking for a
        // second tray icon's menu while the first is still up changes the
        // subject without the popup ever closing.
        target: Overlay

        function onPayloadChanged(): void {
            // Cleared, it stays: a closing popup keeps its subject through the
            // fade, and drops it as the surface goes.
            if (root.shown && Overlay.payload !== null)
                root.subject = Overlay.payload;
        }
    }

    Timer {
        // Unmaps the surface once the fade-out has played. This cannot hang off
        // the animation itself: an animation driven by a Behavior never emits
        // finished(). `running` is a plain binding, so the surface is unmapped
        // even if the property changes while no handler is watching.
        running: root.rendered && !root.shown && !card.holding
        interval: Appearance.t.fast + 60
        onTriggered: {
            root.rendered = false;
            root.settled = false;
            root.subject = null;
        }
    }

    OverlayCard {
        id: card

        overlayId: root.overlayId
        shown: root.shown
        settled: root.settled
        // Bottom-anchored popups keep their bottom edge against the dock, so the
        // room a resize is holding sits above the card rather than below it.
        rest: Qt.rect(root.liveX, root.padTop + (root.placement === ShellOverlay.Placement.AboveDock
            ? root.surfaceHeight - root.liveHeight : 0), root.cardWidth, root.liveHeight)
        windowTop: root.top
        elevation: root.elevation
        onKeyPressed: event => root.keyPressed(event)
    }
}
