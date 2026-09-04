pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"

/*! One application in the launcher grid. */
Clickable {
    id: root

    required property var entry
    property bool current: false

    radius: Appearance.r.md
    focusable: false
    selected: root.current

    Column {
        anchors.centerIn: parent
        width: parent.width - Appearance.s.md * 2
        spacing: Appearance.s.md

        AppIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            source: root.entry?.icon ?? ""
            size: 48
            scale: root.down ? 0.92 : root.hovered ? 1.05 : 1

            Behavior on scale {
                NumberAnimation { duration: Appearance.t.fast; easing.type: Appearance.t.standardEasing }
            }
        }

        Label {
            width: parent.width
            text: root.entry?.name ?? ""
            role: Label.Role.Small
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            maximumLineCount: 2
        }
    }
}
