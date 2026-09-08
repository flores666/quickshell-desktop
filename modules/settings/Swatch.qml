pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"

/*! One selectable colour. The first entry in a row is the theme default. */
Clickable {
    id: root

    property color color: "transparent"
    /*! Marked with a slash: "whatever the theme ships with". */
    property bool isDefault: false

    implicitWidth: 28
    implicitHeight: 28
    radius: Appearance.r.full
    showStateLayer: false

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.color
        border.width: root.selected ? 2 : 1
        border.color: root.selected ? Appearance.c.accent : Appearance.c.borderStrong
        scale: root.down ? 0.9 : root.hovered ? 1.08 : 1

        Behavior on scale {
            NumberAnimation { duration: Appearance.t.fast; easing.type: Appearance.t.standardEasing }
        }

        Rectangle {
            anchors.centerIn: parent
            visible: root.isDefault
            width: 2
            height: parent.height - 8
            rotation: 45
            radius: 1
            color: Appearance.c.textMuted
        }
    }
}
