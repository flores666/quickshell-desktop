pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"

Clickable {
    id: root

    required property string text
    required property real availableWidth
    signal clearRequested

    implicitWidth: deadlineLabel.implicitWidth + Appearance.s.sm * 2
    implicitHeight: deadlineLabel.implicitHeight + Appearance.s.xxs * 2
    width: Math.min(root.availableWidth, implicitWidth)
    height: implicitHeight
    radius: Appearance.r.full
    background: Appearance.c.sunken
    Accessible.role: Accessible.Button
    Accessible.name: root.text === "" ? qsTr("Set time") : qsTr("Edit time, %1").arg(root.text)
    Accessible.description: qsTr("Press Delete to remove the deadline.")
    Keys.onDeletePressed: root.clearRequested()

    Label {
        id: deadlineLabel
        anchors.fill: parent
        anchors.leftMargin: Appearance.s.sm
        anchors.rightMargin: Appearance.s.sm
        text: root.text || qsTr("Set time")
        role: Label.Role.Small
        muted: true
    }
}
