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
    color: Appearance.c.surface
    implicitHeight: Appearance.m.barHeight
    anchors { top: true; left: true; right: true }

    WlrLayershell.namespace: "shell-bar"
    WlrLayershell.layer: WlrLayer.Top

    HoverHandler {
        id: pointer
        onHoveredChanged: Overlay.setPointerOver("bar:" + root.modelData.name, pointer.hovered)
    }

    Component.onDestruction: Overlay.setPointerOver("bar:" + root.modelData.name, false)

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: Appearance.c.border
    }

    Workspaces {
        anchors.left: parent.left
        anchors.leftMargin: Appearance.s.sm
        anchors.verticalCenter: parent.verticalCenter
        monitor: root.monitor
    }

    ClockButton {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        screen: root.modelData
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: Appearance.s.sm
        anchors.verticalCenter: parent.verticalCenter
        spacing: Appearance.s.xs

        KeyboardLayout {
            anchors.verticalCenter: parent.verticalCenter
        }

        Tray {
            anchors.verticalCenter: parent.verticalCenter
            screen: root.modelData
        }

        StatusCluster {
            anchors.verticalCenter: parent.verticalCenter
            screen: root.modelData
        }
    }
}
