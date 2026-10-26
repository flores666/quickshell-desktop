pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"

/*!
    How much of something is used, as a bar that fills: the root
    filesystem's space, the GPU's memory. Drawn as MemoryGauge's bar is, in
    the colour of the reading it belongs to; empty with no reading.
*/
Item {
    id: root

    /*! The share used, 0 to 1. */
    property real fraction: 0
    property color color: Appearance.c.accent

    implicitHeight: Appearance.m.gaugeHeight

    Rectangle {
        anchors.fill: parent
        radius: Appearance.r.capsule(height)
        color: Appearance.c.sunken
    }

    Rectangle {
        visible: root.fraction > 0
        width: Math.max(height, root.width * Math.min(1, root.fraction))
        height: parent.height
        radius: Appearance.r.capsule(height)
        color: root.color

        Behavior on width {
            NumberAnimation { duration: Appearance.t.base; easing.type: Appearance.t.standardEasing }
        }
    }
}
