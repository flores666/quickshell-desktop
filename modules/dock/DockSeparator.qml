pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"

Item {
    implicitWidth: Appearance.s.md
    implicitHeight: Appearance.m.dockCell

    Rectangle {
        anchors.centerIn: parent
        width: 1
        height: parent.height - Appearance.s.lg
        color: Appearance.c.border
    }
}
