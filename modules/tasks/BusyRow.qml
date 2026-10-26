pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    One of the disk's most active processes: its application's icon where
    one matches, its name, and what it reads and writes a second now. Kept by
    pid, the process read from Processes as it stands.
*/
Item {
    id: root

    required property int modelData

    readonly property var process: Processes.byPid[root.modelData] ?? null
    readonly property string name: root.process?.name ?? ""

    implicitHeight: Appearance.m.touchTarget

    ProcessIcon {
        id: icon
        anchors.verticalCenter: parent.verticalCenter
        name: root.name
    }

    Label {
        anchors.verticalCenter: parent.verticalCenter
        x: icon.width + Appearance.s.md
        width: rate.x - x - Appearance.s.md
        text: root.name
    }

    Label {
        id: rate
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: Usage.formatRate(root.process?.io ?? -1)
        role: Label.Role.Small
        font.features: { "tnum": 1 }
    }
}
