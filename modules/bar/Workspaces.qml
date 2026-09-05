pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    The Hyprland workspaces belonging to one monitor.

    Occupied workspaces are dots, the active one stretches into a pill, and an
    urgent one takes the accent colour.  Scrolling anywhere over the strip moves
    between the workspaces on this monitor only.
*/
Item {
    id: root

    required property HyprlandMonitor monitor

    readonly property var list: Compositor.workspacesFor(root.monitor)

    implicitWidth: row.implicitWidth + Appearance.s.xs * 2
    implicitHeight: Appearance.m.barItemHeight

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: event => {
            Compositor.cycleWorkspace(root.monitor, event.angleDelta.y > 0 ? -1 : 1);
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Appearance.s.xxs

        Repeater {
            model: root.list

            Clickable {
                id: item

                required property HyprlandWorkspace modelData

                readonly property bool isActive: item.modelData.active
                readonly property bool occupied: item.modelData.toplevels.values.length > 0

                implicitWidth: item.isActive ? 26 : 18
                implicitHeight: Appearance.m.barItemHeight
                radius: Appearance.r.sm
                focusable: false
                // The dot already says which workspace is active. A hover wash
                // behind it says it too, and says it about whichever one the
                // pointer is crossing, so the strip reads as though the
                // selection follows the mouse.
                showStateLayer: false

                Behavior on implicitWidth {
                    NumberAnimation {
                        duration: Appearance.t.base
                        easing.type: Appearance.t.emphasizedEasing
                    }
                }

                onClicked: Compositor.switchToWorkspace(item.modelData.id)

                Rectangle {
                    anchors.centerIn: parent
                    width: item.isActive ? 16 : 6
                    height: 6
                    radius: 3
                    color: item.modelData.urgent ? Appearance.c.danger
                        : item.isActive ? Appearance.c.accent
                        : item.occupied ? Appearance.c.textMuted
                        : Appearance.c.borderStrong

                    Behavior on width {
                        NumberAnimation {
                            duration: Appearance.t.base
                            easing.type: Appearance.t.emphasizedEasing
                        }
                    }
                    Behavior on color {
                        ColorAnimation { duration: Appearance.t.fast }
                    }
                }
            }
        }
    }
}
