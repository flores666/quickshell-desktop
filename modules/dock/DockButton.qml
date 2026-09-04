pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"

/*! A non-application action in the dock, such as the overview or app grid. */
Clickable {
    id: root

    property string icon: ""
    property string tipText: ""

    signal activated
    signal hoverChanged(string key, string label, real centerX, bool entered)

    implicitWidth: Appearance.m.dockCell
    implicitHeight: Appearance.m.dockCell
    radius: Appearance.r.md
    focusable: false

    onClicked: root.activated()
    onHoveredChanged: root.hoverChanged(root.tipText, root.tipText,
        root.mapToItem(root.parent.parent, root.width / 2, 0).x, root.hovered)

    Icon {
        anchors.centerIn: parent
        name: root.icon
        size: Appearance.m.iconXl
        color: root.selected ? Appearance.c.accent : Appearance.c.text
        scale: root.down ? 0.9 : root.hovered ? 1.06 : 1

        Behavior on scale {
            NumberAnimation { duration: Appearance.t.fast; easing.type: Appearance.t.standardEasing }
        }
        Behavior on color {
            ColorAnimation { duration: Appearance.t.fast }
        }
    }
}
