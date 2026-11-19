pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

/*! A non-application action in the dock: the application grid. */
DockDraggable {
    id: root

    readonly property string tipText: qsTr("Applications")
    property real magnification: 1
    property real controlExtension: 0

    hoverDelay: Settings.dockMagnificationEnabled ? Appearance.t.dockHover : 0
    showStateLayer: !Settings.dockMagnificationEnabled
    selected: Overlay.isOpen(Overlay.launcher)
    Accessible.role: Accessible.Button
    Accessible.name: root.tipText
    onInvoked: Overlay.toggle(Overlay.launcher, root.screen, root.centerX())
    onDraggingChanged: if (root.dragging && root.selected) Overlay.close()
    onPointerOverChanged: root.hoverChanged(Dock.launcherSlot.key, root.tipText, root.centerX(), root.pointerOver)

    // Center the smaller drawing in the shared icon box so it moves with the wave.
    Icon {
        id: artwork
        x: (root.width - width) / 2
        y: root.height - Appearance.m.dockInset - height - root.controlExtension / 2
        width: Appearance.m.dockIcon
        height: width
        name: "apps"
        size: Appearance.m.dockLauncherIcon
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
