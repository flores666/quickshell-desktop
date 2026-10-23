pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    The visible card of a popup: how it appears, fades and takes input, and
    how it flies in from the popup it takes over from.

    Where it rests and how big it is belong to ShellOverlay, which owns the
    surface around it (`rest`); this is only what the card does once placed.

    A popup opened over another on the same screen does not fade in: its card
    starts exactly over the other's and flies to its own place, as the one
    card (Overlay.flight). The other's contents ride along as a picture and
    fade out over the first half of the way, this one's fade in over the
    second, and the other card is gone in the very frame this one takes off:
    every popup's card is drawn in the one window (OverlaySurface), in the same
    coordinates, so the hand-off is one change to one scene. A popup given a
    new subject while it is up takes over from itself the same way: its
    picture first, then the subject, and it flies to its new place.
*/
Surface {
    id: card

    required property string overlayId
    /*! Whether the popup is open. Hover and the keyboard follow this alone. */
    required property bool shown
    /*! Whether the card's geometry has caught up with its content (see
        ShellOverlay.settled). Until then it is invisible and does not animate. */
    required property bool settled
    /*! Where the card rests in its window, and its size there: what it flies
        to, and what its contents are laid out at. A card that fades in place
        slides into it (`entry`); one with a `door` rolls out to it. */
    property rect rest
    /*! Its rest on the way to a new height, its contents already laid out at
        that height (ShellOverlay.liveHeight). */
    property bool resizing: false
    /*! The edge it hangs from, which it rolls out of as it opens and back into
        as it closes, as a garage door does: Qt.TopEdge under the bar,
        Qt.BottomEdge above the dock. 0, a card with neither (a centred one),
        fades in place instead. */
    property int door: 0

    /*! Keys the card did not handle itself. */
    signal keyPressed(var event)

    /*! What the popup puts in the card. Not the default property: Surface's
        own `content` is, and is where this file's children go. */
    property alias contentData: body.data

    /*! Where it took off from, in its window; and how far from there it has
        come, 0 to 1 over `t.popupResize` — 1, at rest, unless it is flying. */
    property rect from
    property real flown: 1
    readonly property bool flying: card.flown < 1
    /*! The picture of the contents it took over (a grab result, held for its
        url), which rides along until it lands. */
    property var leftBehind: null
    /*! How strongly the card it took over from was drawn: below 1 when that
        one was still fading in, which this one goes on with as it flies. */
    property real tookOver: 1
    /*! The old contents' share of the way, and the new ones'. */
    readonly property real outgoing: card.flying ? 1 - Math.min(1, card.flown * 2) : 0
    readonly property real incoming: card.flying ? Math.max(0, card.flown * 2 - 1) : 1

    /*! Kept on screen for the popup taking over: from the moment its own
        popup closes until the other card takes off, or the hand-off is given
        up — then it closes as it would alone. */
    readonly property bool holding: !card.shown && Overlay.flight !== null
        && Overlay.flight.from === card.overlayId && !Overlay.flight.away
    /*! Taking over from itself: up, and given a new subject that goes in as
        it takes off (Overlay.openWith). */
    readonly property bool renewing: card.shown && Overlay.flight !== null
        && Overlay.flight.from === card.overlayId && Overlay.flight.to === card.overlayId
        && !Overlay.flight.away
    /*! Taking over, with the other card's picture not yet in hand. */
    readonly property bool waiting: Overlay.flight !== null
        && Overlay.flight.to === card.overlayId && Overlay.flight.contents === null
    /*! Gone at once, the other card flying on in its place; kept, whatever
        the next hand-off, until it is up again — opened alone, or taking off
        in a hand-off of its own. Not as soon as its popup opens: switched
        back to before it is in, it is still on its way out, and was drawn
        so beside the card flying from its place. */
    property bool handedOver: false
    readonly property bool up: (card.shown || card.holding) && card.settled

    /*!
        The short slide the card makes as it appears. Animated on its own
        rather than through `y`, so that the resize compensation in the rest
        stays exactly in step with the height instead of chasing it on a
        different curve — which is the bottom edge of the card visibly drifting.
    */
    property real entry: card.up || card.flying ? 0 : -Appearance.s.md
    property real fade: card.up ? 1 : 0
    /*! How far out of its `door` it has rolled: 0 shut, 1 at rest. It fades
        in from shut as it rolls. Held out, as the slide is held in, while the
        card flies, which they take no part in: closed mid-flight, the card
        landed on wherever they had got to, a jump of 150 px. */
    readonly property alias rolled: roller.rolled
    readonly property bool rolling: card.door !== 0 && roller.rolling

    Door {
        id: roller
        edge: card.door
        out: card.up || card.flying
        full: card.rest.height
        radius: card.radius
    }

    Behavior on entry {
        NumberAnimation { duration: Appearance.t.popupMove; easing.type: Appearance.t.emphasizedEasing }
    }

    Behavior on fade {
        NumberAnimation { duration: Appearance.t.popupFade; easing.type: Appearance.t.standardEasing }
    }

    /*! Where a value of the rest stands on the way there from `from`. */
    function along(start: real, end: real): real {
        return card.flying ? start + (end - start) * card.flown : end;
    }

    x: card.along(card.from.x, card.rest.x)
    // Rolled out, its edge on the door stays put and the other comes and goes.
    y: card.along(card.from.y, card.rest.y)
        + (card.flying ? 0 : card.door === 0 ? card.entry : roller.drop)
    width: card.along(card.from.width, card.rest.width)
    height: card.flying || card.door === 0 ? card.along(card.from.height, card.rest.height)
        : roller.extent
    // One radius for every panel; no popup picks its own.
    radius: Appearance.r.panel
    // A card in flight is the one that was there: as strong as that one was
    // from its first frame, whatever its own fade has reached, and coming in
    // with its fade from there.
    opacity: card.flying && card.up ? Math.max(card.tookOver, card.fade) : card.fade
    visible: !card.handedOver

    onShownChanged: {
        if (card.shown && Overlay.flight?.to !== card.overlayId)
            card.handedOver = false;
        else if (!card.shown && Overlay.flight?.from === card.overlayId)
            card.depart();
    }
    // Unmapped, or about to take off again: whatever it was flying is over.
    onSettledChanged: if (!card.settled) {
        flight.stop();
        card.flown = 1;
    }
    onFlyingChanged: if (!card.flying) card.leftBehind = null

    Connections {
        target: Overlay

        // Read off the hand-off, not off `holding` or `renewing`: they hear
        // this same change, and may not have yet.
        function onFlightChanged(): void {
            const f = Overlay.flight;
            if (f === null || f.from !== card.overlayId)
                return;
            if (!card.shown && f.away)
                card.handedOver = true;
            else if (card.shown && f.to === card.overlayId && !f.away && f.contents === null)
                card.depart();
        }
    }

    NumberAnimation {
        id: flight
        target: card
        property: "flown"
        from: 0
        to: 1
        duration: Appearance.t.popupResize
        easing.type: Appearance.t.resizeEasing
    }

    /*! Hands the card over to the popup taking over: a picture of what it
        shows, where it is and how strongly it is drawn. Taking over from
        itself, it takes off with it at once, the picture being all it waits
        for. Given up when there is nothing on screen to hand over. */
    function depart(): void {
        const ratio = card.Screen.devicePixelRatio;
        const grabbed = card.settled && stage.grabToImage(result => {
            const self = card.renewing && Overlay.flight.contents === null;
            if (!card.holding && !self)
                return;
            Overlay.depart(card.overlayId, Qt.rect(card.x, card.y, card.width, card.height),
                card.opacity, result);
            if (self)
                card.arrive();
        }, Qt.size(Math.ceil(card.width * ratio), Math.ceil(card.height * ratio)));
        if (!grabbed)
            Overlay.abandon(card.overlayId);
    }

    /*! As its popup settles: taking over, it starts over the other card with
        that card's contents and flies, and the other goes in the same frame;
        with no picture of it in time, it gives the hand-off up and opens
        alone. */
    function arrive(): void {
        card.handedOver = false;
        const f = Overlay.flight;
        if (f === null || f.to !== card.overlayId)
            return;
        if (f.contents === null) {
            Overlay.abandon(card.overlayId);
            return;
        }
        card.from = f.rect;
        card.tookOver = f.strength;
        card.leftBehind = f.contents;
        card.flown = 0;
        flight.restart();
        Overlay.arrive(card.overlayId);
    }

    HoverHandler {
        id: pointer
        onHoveredChanged: Overlay.setPointerOver("popup", pointer.hovered && card.shown)
    }

    RoundedClip {
        id: stage
        anchors.fill: parent
        // The card's contents never draw outside the card. While the card is
        // animating to a new height or flying its content is already at full
        // size, and without this it spills over the edge onto the desktop —
        // and, cut square, past the card's rounded corners.
        clip: true
        radius: card.radius
        active: card.flying || card.resizing || card.rolling

        Item {
            id: body
            // Laid out at the size it rests at, so flying never reflows it;
            // centred, so a card on its way shows the middle of it — and on a
            // door's moving edge, as a door's panel is, so a card rolling out
            // shows its far end first.
            x: (parent.width - body.width) / 2
            y: card.flying || card.door === 0 ? (parent.height - body.height) / 2 : roller.contentY
            width: card.rest.width
            height: card.rest.height
            opacity: card.incoming
            // Fades as one flattened image. An opacity on the card is applied
            // to every descendant separately, so a control drawn from shapes
            // painted over each other shows through itself: a quick-settings
            // tile is a fill with a disc and a chevron on it, and each shape it
            // overlaps adds its colour again. Measured on the closing fade, when
            // the tile was built from three overlapping pieces: the seam read
            // 60% brighter than the tile around it.
            layer.enabled: card.opacity < 1 || card.flying
        }

        Image {
            anchors.centerIn: parent
            width: card.from.width
            height: card.from.height
            visible: card.flying && card.leftBehind !== null
            source: card.leftBehind?.url ?? ""
            opacity: card.outgoing
            cache: false
        }
    }

    // Over the content, so a menu opened near a pane's edge is not clipped by it.
    CardMenu {
        anchors.fill: parent
        active: card.shown
    }

    /*!
        Escape is consumed here and acted on elsewhere: the global bind
        (ShellIpc's escapeKey) fires on every press whether or not this card
        has the keyboard, and it is the one that closes. Acting here as well
        would take two steps on one press — a context menu closed by one, and
        the popup behind it by the other. Anything else is offered to the
        popup, which owns its own navigation.
    */
    Keys.onPressed: event => {
        InputMode.keyboardUsed();
        if (event.key === Qt.Key_Escape) {
            event.accepted = true;
            return;
        }
        card.keyPressed(event);
    }
}
