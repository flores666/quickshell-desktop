pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"

/*!
    A small label that appears above a point after a short delay.

    The caller supplies the anchor point in this item's parent coordinates, which
    keeps the tooltip free of layout assumptions.  The owning window must reserve
    room above the anchor — the dock, for instance, is taller than its visible
    surface and masks input back down to it.
*/
Item {
    id: root

    property string text: ""
    property bool show: false
    /*! Horizontal centre and top edge of the thing being described. */
    property real anchorX: 0
    property real anchorY: 0
    property int gap: Appearance.s.md
    property int delayMs: 450
    property int edgeMargin: Appearance.s.md

    readonly property bool shown: root.show && root.text !== ""

    // Centred on the anchor, but never past the edge of the surface it lives in.
    x: Math.round(root.parent
        ? Math.max(root.edgeMargin,
            Math.min(root.parent.width - root.width - root.edgeMargin,
                root.anchorX - root.width / 2))
        : root.anchorX - root.width / 2)
    y: Math.round(root.anchorY - height - root.gap)
    implicitWidth: label.implicitWidth + Appearance.s.lg * 2
    implicitHeight: label.implicitHeight + Appearance.s.md * 2
    width: implicitWidth
    height: implicitHeight
    visible: opacity > 0
    opacity: 0

    Behavior on opacity {
        NumberAnimation { duration: Appearance.t.fast; easing.type: Appearance.t.standardEasing }
    }

    Timer {
        id: delay
        interval: root.delayMs
        onTriggered: root.opacity = 1
    }

    onShownChanged: {
        if (root.shown) {
            delay.restart();
        } else {
            delay.stop();
            root.opacity = 0;
        }
    }

    Surface {
        anchors.fill: parent
        radius: Appearance.r.xs
        elevation: 2

        Label {
            id: label
            anchors.centerIn: parent
            text: root.text
            role: Label.Role.Small
        }
    }
}
