pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"

/*!
    A slim scrollbar for a Flickable, along either axis. Hidden entirely when
    nothing overflows.

    It anchors itself over the trailing edge of the flickable it is given — the
    right edge for a vertical bar, the bottom for a horizontal one — so it
    costs no room in the surrounding layout. Content that must not run
    underneath it is inset by `footprint`, which is the only number a caller
    needs to know about the bar.
*/
Item {
    id: root

    required property Flickable flickable
    /*! The axis the bar scrolls. */
    property bool vertical: true

    /*! How thick the bar paints, and how far it is inset from the edges. */
    readonly property int thickness: Appearance.m.scrollbarThickness
    readonly property int inset: Appearance.m.scrollbarInset
    /*! What a caller keeps clear alongside the bar: the bar, the insets it
        sits in, and a gap, so content does not run up against it. */
    readonly property int footprint: root.thickness + root.inset * 2 + Appearance.s.md

    /*! The flickable's geometry along the scrolling axis, so the rest of this
        file can be written once rather than once per orientation. */
    readonly property real content: !root.flickable ? 0
        : root.vertical ? root.flickable.contentHeight : root.flickable.contentWidth
    readonly property real viewport: !root.flickable ? 0
        : root.vertical ? root.flickable.height : root.flickable.width
    readonly property real position: !root.flickable ? 0
        : root.vertical ? root.flickable.contentY : root.flickable.contentX
    readonly property real origin: !root.flickable ? 0
        : root.vertical ? root.flickable.originY : root.flickable.originX
    readonly property real reach: Math.max(0, root.content - root.viewport)
    readonly property real progress: root.reach > 0
        ? Math.max(0, Math.min(1, (root.position - root.origin) / root.reach)) : 0

    readonly property bool overflowing: root.content > root.viewport + 1
    /*! How far the bar runs, and how much of that the thumb covers. */
    readonly property real span: root.vertical ? root.height : root.width
    readonly property real thumbLength: root.overflowing
        ? Math.min(root.span, Math.max(Appearance.m.scrollbarThumb, root.span * (root.viewport / root.content))) : 0
    readonly property real travel: Math.max(0, root.span - root.thumbLength)
    readonly property real lead: root.travel * root.progress

    /*! Scroll so that the thumb's leading edge lands at `at`. */
    function scrollTo(at: real): void {
        if (!root.flickable || root.travel <= 0)
            return;
        const to = root.origin + Math.max(0, Math.min(1, at / root.travel)) * root.reach;
        if (root.vertical)
            root.flickable.contentY = to;
        else
            root.flickable.contentX = to;
    }

    anchors.right: root.flickable ? root.flickable.right : undefined
    anchors.bottom: root.flickable ? root.flickable.bottom : undefined
    // The two edges the bar spans between. Leaving the other axis unanchored is
    // what lets `thickness` size it.
    anchors.top: root.flickable && root.vertical ? root.flickable.top : undefined
    anchors.left: root.flickable && !root.vertical ? root.flickable.left : undefined
    anchors.margins: root.inset
    implicitWidth: root.thickness
    implicitHeight: root.thickness
    visible: root.overflowing
    opacity: (root.flickable && root.flickable.moving) || grab.pressed ? 1 : Appearance.m.scrollbarIdle

    Behavior on opacity {
        NumberAnimation { duration: Appearance.t.base; easing.type: Appearance.t.standardEasing }
    }

    /*!
        The bar is a handle, not just a readout. Its grab area reaches further
        into the content than the 6px it paints, which is the difference between
        a scrollbar you can use with a mouse and one you can only look at.
    */
    Clickable {
        id: grab

        anchors.fill: parent
        anchors.leftMargin: root.vertical ? -Appearance.s.md : 0
        anchors.topMargin: root.vertical ? 0 : -Appearance.s.md
        enabled: root.overflowing
        focusable: false
        showStateLayer: false
        preventStealing: true
        cursorShape: Qt.PointingHandCursor

        /*! Where on the thumb it was grabbed, so it does not jump under the hand. */
        property real offset: 0

        /*! The press, along the bar's own axis. The reach above only widens the
            axis this ignores, so these stay in the bar's coordinates. */
        function along(event: var): real {
            return root.vertical ? event.y : event.x;
        }

        onPointerPressed: event => {
            const at = grab.along(event);
            const lead = root.lead;
            const onThumb = at >= lead && at <= lead + root.thumbLength;
            grab.offset = onThumb ? at - lead : root.thumbLength / 2;
            if (!onThumb)
                root.scrollTo(at - grab.offset);
        }
        onPointerMoved: event => {
            if (grab.pressed)
                root.scrollTo(grab.along(event) - grab.offset);
        }
    }

    Rectangle {
        id: thumb

        x: root.vertical ? 0 : root.lead
        y: root.vertical ? root.lead : 0
        width: root.vertical ? root.width : root.thumbLength
        height: root.vertical ? root.thumbLength : root.height
        radius: root.thickness / 2
        color: Appearance.c.borderStrong
    }
}
