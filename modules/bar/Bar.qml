pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    The top panel: workspaces on the left, clock and media in the centre, status
    and the quick-settings button on the right.

    One panel standing just off the top edge.  The controls at its ends sit in
    shallow wells that group them; the clock sits on the panel itself, which is
    what keeps the middle of the bar quiet.  The window is taller than the panel
    — it holds the gap above and room for the shadow to fall below — but only
    the panel is reserved from the screen, and only the panel takes input.

    One instance per monitor.  It gives up its space — and gets out of the way —
    whenever the monitor is showing a fullscreen window.
*/
PanelWindow {
    id: root

    required property ShellScreen modelData

    readonly property HyprlandMonitor monitor: Compositor.monitorFor(root.modelData)
    readonly property bool suppressed: Compositor.isFullscreenOn(root.monitor)

    screen: root.modelData
    visible: !root.suppressed
    color: "transparent"
    implicitHeight: Appearance.m.barFootprint + Appearance.shadowFor(panel.elevation).blur
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: Appearance.m.barFootprint
    anchors { top: true; left: true; right: true }

    WlrLayershell.namespace: "shell-bar"
    WlrLayershell.layer: WlrLayer.Top

    /*! The gap around the panel is paint, not surface: clicks go through it. */
    mask: Region { item: panel }

    Component.onDestruction: Overlay.setPointerOver("bar:" + root.modelData.name, false)

    Surface {
        id: panel

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: Appearance.m.barGap
        anchors.leftMargin: Appearance.m.barSideGap
        anchors.rightMargin: Appearance.m.barSideGap
        height: Appearance.m.barHeight
        radius: Appearance.r.lg
        elevation: 1

        HoverHandler {
            id: pointer
            onHoveredChanged: Overlay.setPointerOver("bar:" + root.modelData.name, pointer.hovered)
        }

        BarGroup {
            anchors.left: parent.left
            anchors.leftMargin: Appearance.s.sm
            anchors.verticalCenter: parent.verticalCenter

            Workspaces {
                anchors.verticalCenter: parent.verticalCenter
                monitor: root.monitor
            }
        }

        // On the panel itself, with no well behind it: the centre of the bar
        // carries the one thing that is always there, and grouping it would
        // only draw a box around a thing that is not part of a set.
        ClockButton {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            screen: root.modelData
        }

        BarGroup {
            anchors.right: parent.right
            anchors.rightMargin: Appearance.s.sm
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
