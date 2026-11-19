pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"

Clickable {
    id: root

    required property string category

    implicitWidth: title.implicitWidth + glyph.width + Appearance.s.md * 2 + Appearance.s.xs
    implicitHeight: Appearance.m.compactButton
    radius: Appearance.r.capsule(root.height)
    background: Appearance.c.raised
    Accessible.role: Accessible.Button
    Accessible.name: qsTr("Task category, %1").arg(title.text)

    Label {
        id: title

        anchors.left: parent.left
        anchors.leftMargin: Appearance.s.md
        anchors.right: glyph.left
        anchors.rightMargin: Appearance.s.xs
        anchors.verticalCenter: parent.verticalCenter
        text: root.category
        role: Label.Role.Small
    }

    Icon {
        id: glyph

        anchors.right: parent.right
        anchors.rightMargin: Appearance.s.md
        anchors.verticalCenter: parent.verticalCenter
        name: "chevron-down"
        size: Appearance.m.iconSm
    }
}
