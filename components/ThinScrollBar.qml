pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"

/*! A slim scrollbar for a Flickable. Hidden entirely when nothing overflows. */
Item {
    id: root

    required property Flickable flickable

    readonly property bool overflowing: root.flickable
        && root.flickable.contentHeight > root.flickable.height + 1

    /*! Scroll so that the thumb's top edge lands at `y`. */
    function scrollTo(y: real): void {
        const span = root.height - thumb.height;
        if (span <= 0)
            return;
        const reach = root.flickable.contentHeight - root.flickable.height;
        root.flickable.contentY = Math.max(0, Math.min(1, y / span)) * reach;
    }

    anchors.right: root.flickable ? root.flickable.right : undefined
    anchors.top: root.flickable ? root.flickable.top : undefined
    anchors.bottom: root.flickable ? root.flickable.bottom : undefined
    anchors.margins: 2
    width: 6
    visible: root.overflowing
    opacity: (root.flickable && root.flickable.moving) || grab.pressed ? 1 : 0.45

    Behavior on opacity {
        NumberAnimation { duration: Appearance.t.base }
    }

    /*!
        The bar is a handle, not just a readout. Its grab area reaches further
        left than the 6px it paints, which is the difference between a scrollbar
        you can use with a mouse and one you can only look at.
    */
    MouseArea {
        id: grab

        anchors.fill: parent
        anchors.leftMargin: -Appearance.s.md
        enabled: root.overflowing
        preventStealing: true
        cursorShape: Qt.PointingHandCursor

        /*! Where on the thumb it was grabbed, so it does not jump under the hand. */
        property real offset: 0

        onPressed: event => {
            const onThumb = event.y >= thumb.y && event.y <= thumb.y + thumb.height;
            grab.offset = onThumb ? event.y - thumb.y : thumb.height / 2;
            if (!onThumb)
                root.scrollTo(event.y - grab.offset);
        }
        onPositionChanged: event => {
            if (grab.pressed)
                root.scrollTo(event.y - grab.offset);
        }
    }

    Rectangle {
        id: thumb

        width: parent.width
        radius: width / 2
        color: Appearance.c.borderStrong
        y: root.overflowing
            ? root.height * Math.max(0, Math.min(1 - height / root.height,
                root.flickable.contentY / root.flickable.contentHeight))
            : 0
        height: root.overflowing
            ? Math.max(28, root.height * (root.flickable.height / root.flickable.contentHeight))
            : 0
    }
}
