pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

/*! One application in the dock: its icon in the slot every dock item has
    (see Metrics), a dot under it for each window it has open, and the slot's
    highlight while one of them has focus. */
DockDraggable {
    id: root

    required property var item
    readonly property ColorScheme dotScheme: root.panel.schemeOver(dots)
    property real magnification: 1

    /*! Whether one of its windows has focus; read here, not in the model. */
    readonly property bool active: root.item.windows.some(w => w?.activated ?? false)
    implicitWidth: Appearance.m.dockSlot
    // Grow the clickable area upwards with the artwork while keeping its
    // horizontal centre and the dots underneath at their resting positions.
    implicitHeight: Appearance.m.dockSlot + Appearance.m.dockIcon * (root.magnification - 1)
    hoverDelay: Settings.dockMagnificationEnabled ? Appearance.t.dockHover : 0
    showStateLayer: !Settings.dockMagnificationEnabled
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    selected: root.active

    onMiddleClicked: Dock.launchNew(root.item)
    onRightClicked: {
        Overlay.openWith(Overlay.dockMenu, root.screen, root.centerX(), root.item);
    }

    // Previews need entry/exit immediately, independently of the hover wash.
    onPointerOverChanged: root.hoverChanged(root.item.key, root.item.name, root.centerX(), root.pointerOver)

    AppIcon {
        id: icon
        x: (root.width - icon.size) / 2
        y: root.height - Appearance.m.dockInset - icon.size
        source: root.item.icon
        size: Appearance.m.dockIcon
        optical: true
        transformOrigin: Item.Bottom
        property real pressScale: root.down ? 0.9 : 1
        scale: root.magnification * icon.pressScale

        Behavior on pressScale {
            NumberAnimation { duration: Appearance.t.fast; easing.type: Appearance.t.standardEasing }
        }
    }

    // A dot for each window, three at most, just under the slot. Which
    // application has focus is the highlight's to say, so the dots only ever
    // count. Each comes and goes with its window, in a place of its own with
    // half the gap either side, so the row stays centred while one grows.
    // They stand in a strip as wide as the slot, the gap above them repeated
    // below: what their colours are read against.
    Item {
        id: dots

        y: root.height
        width: root.width
        height: Appearance.m.dockDotGap * 2 + Appearance.m.dockDot

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Appearance.m.dockDotGap

            Repeater {
                model: 3

                Item {
                    id: dot

                    required property int index
                    property real presence: dot.index < root.item.windows.length ? 1 : 0

                    Behavior on presence {
                        NumberAnimation { duration: Appearance.t.base; easing.type: Appearance.t.emphasizedEasing }
                    }

                    width: (Appearance.m.dockDot + Appearance.s.xs) * dot.presence
                    height: Appearance.m.dockDot

                    Rectangle {
                        anchors.centerIn: parent
                        width: Appearance.m.dockDot
                        height: Appearance.m.dockDot
                        radius: Appearance.m.dockDot / 2
                        color: root.dotScheme.text
                        opacity: dot.presence
                        scale: dot.presence
                    }
                }
            }
        }
    }
}
