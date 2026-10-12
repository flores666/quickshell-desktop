pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    The top panel: workspaces on the left, the clock in the centre, status
    and the quick-settings button on the right.

    One glass capsule standing just off the top edge, its three groups laid
    straight onto it: no wells and no rules between them, only the space that
    keeps them apart.  The window is taller than the panel
    — it holds the gap above and room for the shadow to fall below — but only
    the panel is reserved from the screen, and only the panel takes input.

    One instance per monitor.  It gives up its space — and gets out of the way —
    whenever the monitor is showing a fullscreen window.
*/
PanelWindow {
    id: root

    required property ShellScreen modelData
    /*!
        This window's entry in Overlay's pointer regions. Taken once, while
        the screen exists: by the time the window is destroyed its screen may
        already be gone, and the entry built from it then could not be cleared.
    */
    property string pointerKey: ""

    Component.onCompleted: root.pointerKey = "bar:" + root.modelData.name

    readonly property HyprlandMonitor monitor: Compositor.monitorFor(root.modelData)
    readonly property bool suppressed: Compositor.isFullscreenOn(root.monitor)

    screen: root.modelData
    visible: !root.suppressed
    color: "transparent"
    implicitHeight: Appearance.m.barFootprint + Appearance.shadowFor(panel.elevation).pad
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: Appearance.m.barFootprint
    anchors { top: true; left: true; right: true }

    WlrLayershell.namespace: "shell-bar"
    WlrLayershell.layer: WlrLayer.Top

    /*! The gap around the panel is paint, not surface: clicks go through it. */
    mask: Region { item: panel }

    Component.onDestruction: Overlay.setPointerOver(root.pointerKey, false)

    Surface {
        id: panel

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: Appearance.m.barGap
        anchors.leftMargin: Appearance.m.barSideGap
        anchors.rightMargin: Appearance.m.barSideGap
        height: Appearance.m.barHeight
        radius: Appearance.r.capsule(Appearance.m.barHeight)
        // The panel stands clear of the screen edge, so it casts the shadow of
        // something raised off the desktop rather than of trim resting on it.
        elevation: 2

        HoverHandler {
            id: pointer
            onHoveredChanged: Overlay.setPointerOver(root.pointerKey, pointer.hovered)
        }

        BarGroup {
            anchors.left: parent.left
            anchors.leftMargin: Appearance.s.xs
            anchors.verticalCenter: parent.verticalCenter

            Workspaces {
                anchors.verticalCenter: parent.verticalCenter
                monitor: root.monitor
            }
        }

        ClockButton {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            screen: root.modelData
        }

        BarGroup {
            anchors.right: parent.right
            anchors.rightMargin: Appearance.s.xs
            anchors.verticalCenter: parent.verticalCenter

            Tray {
                id: tray
                anchors.verticalCenter: parent.verticalCenter
                screen: root.modelData
            }

            // The one place a rule earns itself: application icons and the
            // shell's own indicators are different kinds of thing.
            Divider {
                anchors.verticalCenter: parent.verticalCenter
                vertical: true
                height: Appearance.m.icon
                visible: tray.visible
            }

            KeyboardLayout {
                anchors.verticalCenter: parent.verticalCenter
            }

            StatusCluster {
                anchors.verticalCenter: parent.verticalCenter
                screen: root.modelData
            }
        }
    }
}
