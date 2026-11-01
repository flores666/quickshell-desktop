pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"

/*! A non-application action in the dock: the application grid. */
Clickable {
    id: root

    property string icon: ""
    property string tipText: ""
    property alias targetMagnification: wave.targetScale
    property real fitFactor: 1
    readonly property real requestedMagnification: wave.value
    readonly property real magnification: 1 + (wave.value - 1) * root.fitFactor

    DockMagnification { id: wave }

    signal activated
    signal hoverChanged(string key, string label, real centerX, bool entered)

    implicitWidth: Appearance.m.dockSlot + Appearance.m.dockIcon * (root.magnification - 1)
    implicitHeight: implicitWidth
    // The slot an application has, highlight and all (see DockItem).
    radius: Appearance.r.capsule(root.height)
    focusable: false

    /*! Its middle across the dock's window, as a DockItem reports it. */
    function centerX(): real {
        const surface = root.QsWindow.contentItem;
        return surface ? root.mapToItem(surface, root.width / 2, 0).x : 0;
    }

    onClicked: root.activated()
    onHoveredChanged: root.hoverChanged(root.tipText, root.tipText, root.centerX(), root.hovered)

    // In an application icon's own box, so as wide as their artwork: the
    // glyph's dots fill two thirds of its box, about what an icon's artwork
    // does of its own.
    Icon {
        id: artwork
        x: (root.width - artwork.size) / 2
        y: root.height - Appearance.m.dockInset - artwork.size
        name: root.icon
        size: Appearance.m.dockIcon
        color: root.selected ? root.scheme.accent : root.scheme.text
        transformOrigin: Item.Bottom
        property real pressScale: root.down ? 0.9 : 1
        scale: root.magnification * artwork.pressScale

        Behavior on pressScale {
            NumberAnimation { duration: Appearance.t.fast; easing.type: Appearance.t.standardEasing }
        }
        Behavior on color {
            ColorAnimation { duration: Appearance.t.fast; easing.type: Appearance.t.standardEasing }
        }
    }
}
