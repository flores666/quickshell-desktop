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
    /*! Wears a pin: a colour the user keeps. */
    property bool pinned: false
    /*! Drawn instead of a colour, for a swatch that is an action. */
    property string icon: ""

    implicitWidth: Appearance.m.swatch
    implicitHeight: Appearance.m.swatch
    radius: Appearance.r.full
    showStateLayer: false

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.icon !== "" ? Appearance.c.raised : root.color
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

        Icon {
            anchors.centerIn: parent
            visible: root.icon !== ""
            name: root.icon
            size: Appearance.m.iconSm
            color: Appearance.c.textMuted
        }
    }

    Rectangle {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: -Appearance.s.xxs
        visible: root.pinned
        width: Appearance.m.swatchBadge
        height: Appearance.m.swatchBadge
        radius: height / 2
        color: Appearance.c.surface
        border.width: 1
        border.color: Appearance.c.borderStrong

        Icon {
            anchors.centerIn: parent
            name: "pin"
            size: Appearance.m.swatchBadge - Appearance.s.xs
            color: Appearance.c.text
        }
    }
}
