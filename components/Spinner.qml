pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"

/*! An indeterminate progress ring. Animates only while actually visible. */
Item {
    id: root

    property int size: Appearance.m.icon
    property color color: Appearance.c.accent

    implicitWidth: root.size
    implicitHeight: root.size

    Icon {
        id: glyph
        anchors.centerIn: parent
        name: "loading"
        size: root.size
        color: root.color

        RotationAnimator {
            target: glyph
            running: root.visible
            from: 0
            to: 360
            duration: Appearance.t.spinner
            loops: Animation.Infinite
        }
    }
}
