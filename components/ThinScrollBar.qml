pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"

/*! A slim scrollbar for a Flickable. Hidden entirely when nothing overflows. */
Item {
    id: root

    required property Flickable flickable

    readonly property bool overflowing: root.flickable
        && root.flickable.contentHeight > root.flickable.height + 1

    anchors.right: root.flickable ? root.flickable.right : undefined
    anchors.top: root.flickable ? root.flickable.top : undefined
    anchors.bottom: root.flickable ? root.flickable.bottom : undefined
    anchors.margins: 2
    width: 6
    visible: root.overflowing
    opacity: root.flickable && root.flickable.moving ? 1 : 0.45

    Behavior on opacity {
        NumberAnimation { duration: Appearance.t.base }
    }

    Rectangle {
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
