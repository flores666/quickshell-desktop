pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"

/*! A non-application action in the dock: the application grid. */
Clickable {
    id: root

    property string icon: ""
    property string tipText: ""

    signal activated
    signal hoverChanged(string key, string label, real centerX, bool entered)

    implicitWidth: Appearance.m.dockSlot
    implicitHeight: Appearance.m.dockSlot
    // The slot an application has, highlight and all (see DockItem).
    radius: Appearance.r.capsule(Appearance.m.dockSlot)
    focusable: false

    onClicked: root.activated()
    onHoveredChanged: root.hoverChanged(root.tipText, root.tipText,
        root.mapToItem(root.parent.parent, root.width / 2, 0).x, root.hovered)

    // In an application icon's own box, so as wide as their artwork: the
    // glyph's dots fill two thirds of its box, about what an icon's artwork
    // does of its own.
    Icon {
        x: Appearance.m.dockInset
        y: Appearance.m.dockInset
        name: root.icon
        size: Appearance.m.dockIcon
        color: root.selected ? Appearance.c.accent : Appearance.c.text
        scale: root.down ? 0.9 : root.hovered ? 1.06 : 1

        Behavior on scale {
            NumberAnimation { duration: Appearance.t.fast; easing.type: Appearance.t.standardEasing }
        }
        Behavior on color {
            ColorAnimation { duration: Appearance.t.fast; easing.type: Appearance.t.standardEasing }
        }
    }
}
