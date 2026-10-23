pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/services"

/*!
    One shell popup — the launcher, quick settings, the date menu, the settings
    panel or a menu — on the window they all share (OverlaySurface): its card,
    where the card rests and how big it is, and the open/settle/fade lifecycle.
    Every popup fills the surface's room, so a card's place is the same in
    every popup's coordinates.

    One instance exists per popup, not per screen; the surface follows
    Overlay.screen, which is set to the focused monitor when a popup opens.
*/
Item {
    id: root

    /*! Where the card sits. Only `Centre` differs across the screen; every
        placement keeps the same `popupGap` from the panel it opens off. A card
        under the bar or above the dock rolls out of that edge as it opens
        (OverlayCard.door); a centred one fades in. */
    enum Placement { BelowBar, AboveDock, Centre }

    required property string overlayId
    property int placement: ShellOverlay.Placement.BelowBar
    /*! Size of the visible card. OverlaySurface adds room for its shadow. */
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
            ? screenWidth / 2 : Overlay.anchorXOf[root.overlayId] ?? 0;
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

    /*! The shadow its card casts (OverlaySurface leaves room for it). */
    property int elevation: 3
    /*! What takes the keyboard when the popup opens. */
    property Item initialFocusItem: null

    default property alias content: card.contentData
    readonly property alias cardItem: card
    /*! The screen the popups are on. */
    readonly property ShellScreen screen: Overlay.screen

    readonly property bool shown: Overlay.isOpen(root.overlayId)
    /*! Stays true through the closing animation so the popup can fade out. */
    property bool rendered: false
    /*!
        Whether the card's geometry has caught up with its content.

        The first size a popup's card is given is always stale (see the
        FrameAnimation below), because Qt cannot lay the content out until it is
        drawn. The card stays transparent until its size stops changing, so
        there is nothing to see meanwhile.
    */
    property bool settled: false
    /*!
        Overlay.payload, held for as long as the popup is on screen.

        Reading the service directly would empty the popup the instant it starts
        closing, collapsing the card mid-fade.
    */
    property var subject: null

    /*!
        Keys the popup did not handle itself; OverlayCard has already taken
        Escape. The popup owns its own navigation.
    */
    signal keyPressed(var event)

    anchors.fill: parent
    visible: root.rendered

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
        // Watches the card settle. Qt lays out only what is drawn — the
        // surface mapped, this popup visible — so nothing can be measured
        // before then and the size the card is first given is whatever the last
        // subject left behind; the real one lands a layout pass later. `running`
        // is a plain binding, like the timer's, so this cannot be left armed.
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
            // fade, and drops it as its card goes.
            if (root.shown && Overlay.payload !== null)
                root.subject = Overlay.payload;
        }
    }

    Timer {
        // Takes the card down once its fade-out has played; the surface unmaps
        // once no card is drawn. This cannot hang off the animation itself: an
        // animation driven by a Behavior never emits finished(). `running` is a
        // plain binding, so the card goes even if the property changes while no
        // handler is watching.
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
        // Popups above the dock keep their bottom edge against it, so the room
        // a resize is holding sits above the card rather than below it.
        rest: Qt.rect(root.liveX, root.placement === ShellOverlay.Placement.AboveDock
            ? root.height - root.liveHeight : 0, root.cardWidth, root.liveHeight)
        resizing: root.liveHeight !== root.cardHeight
        // It rolls out of the panel it opens off; a centred card fades in.
        door: root.placement === ShellOverlay.Placement.BelowBar ? Qt.TopEdge
            : root.placement === ShellOverlay.Placement.AboveDock ? Qt.BottomEdge : 0
        elevation: root.elevation
        onKeyPressed: event => root.keyPressed(event)
    }
}
