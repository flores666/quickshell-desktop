pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"

/*! One row of a popup menu: optional icon, label, and a trailing marker. */
Clickable {
    id: root

    property string label: ""
    property string icon: ""
    property bool checked: false
    property bool checkable: false
    property bool submenu: false
    property bool danger: false

    implicitWidth: Math.max(180, textLabel.implicitWidth + 76)
    implicitHeight: 32
    radius: Appearance.r.xs
    focusable: false

    // The icon column is always reserved, so every label in a menu lines up
    // whether or not its own row has a glyph.
    Icon {
        id: leading
        anchors.verticalCenter: parent.verticalCenter
        x: Appearance.s.md
        name: root.checkable ? (root.checked ? "check" : "") : root.icon
        size: Appearance.m.iconSm
        color: root.danger ? Appearance.c.danger : Appearance.c.textMuted
    }

    Label {
        id: textLabel
        anchors.verticalCenter: parent.verticalCenter
        x: leading.x + leading.width + Appearance.s.md
        width: root.width - x - (trailing.visible ? 26 : Appearance.s.md)
        text: root.label
        role: Label.Role.Small
        color: root.danger ? Appearance.c.danger : Appearance.c.text
    }

    Icon {
        id: trailing
        anchors.verticalCenter: parent.verticalCenter
        x: root.width - width - Appearance.s.md
        visible: root.submenu
        name: "chevron-right"
        size: Appearance.m.iconSm
        color: Appearance.c.textFaint
    }
}
