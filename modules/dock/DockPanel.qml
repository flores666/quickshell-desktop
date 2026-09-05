pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    The bottom dock: an overview button, pinned applications and every open
    window, then the application grid.

    It hides itself when it is not being used and slides back when the pointer
    reaches the bottom edge. The reveal trigger is a few pixels tall, invisible,
    and only as wide as the dock; the window reserves no space at all, and input
    is masked to the dock plus that strip, so everything else on screen stays
    click-through. The strip stays in the input region while the dock is out, so
    crossing the gap between them cannot drop the hover and start a hide.
*/
PanelWindow {
    id: root

    required property ShellScreen modelData

    readonly property HyprlandMonitor monitor: Compositor.monitorFor(root.modelData)
    readonly property bool suppressed: Compositor.isFullscreenOn(root.monitor)
    readonly property int dockHeight: Appearance.m.dockCell + Appearance.m.dockPadding * 2

    /*! Which dock child the pointer is on, so hiding is never ambiguous. */
    property string hoveredKey: ""

    readonly property bool pointerNear: dockHover.hovered || triggerHover.hovered
    /*! Stay out while a menu of ours is up, or a drag is in progress. */
    readonly property bool held: Overlay.isOpen(Overlay.dockMenu) || root.dragSlot >= 0

    /*! The icon being dragged into a new position, and the slot it would land in. */
    property int dragSlot: -1
    property int dropSlot: -1
    readonly property int slotStride: Appearance.m.dockCell + Appearance.m.dockGap

    property bool revealed: false

    /*! How far an icon has to step aside to open a gap where the drag will land. */
    function slideFor(slot: int): real {
        if (root.dragSlot < 0 || slot === root.dragSlot)
            return 0;
        if (slot > root.dragSlot && slot <= root.dropSlot)
            return -root.slotStride;
        if (slot < root.dragSlot && slot >= root.dropSlot)
            return root.slotStride;
        return 0;
    }

    screen: root.modelData
    visible: !root.suppressed
    color: "transparent"
    implicitHeight: root.dockHeight + Appearance.m.dockTooltipSpace + Appearance.m.screenGap
    exclusionMode: ExclusionMode.Ignore
    anchors { bottom: true; left: true; right: true }

    WlrLayershell.namespace: "shell-dock"
    WlrLayershell.layer: WlrLayer.Top

    mask: Region {
        item: trigger
        Region { item: surface }
    }

    onPointerNearChanged: {
        Overlay.setPointerOver("dock:" + root.modelData.name, root.pointerNear);
        if (root.pointerNear) {
            hideTimer.stop();
            root.revealed = true;
        } else {
            hideTimer.restart();
        }
    }

    onHeldChanged: if (!root.held && !root.pointerNear) hideTimer.restart()

    Component.onDestruction: Overlay.setPointerOver("dock:" + root.modelData.name, false)

    Timer {
        id: hideTimer
        interval: 700
        onTriggered: if (!root.pointerNear && !root.held) root.revealed = false
    }

    function onChildHover(key: string, label: string, centerX: real, entered: bool): void {
        if (entered) {
            root.hoveredKey = key;
            tip.text = label;
            tip.anchorX = surface.x + centerX;
            tip.show = true;
        } else if (root.hoveredKey === key) {
            root.hoveredKey = "";
            tip.show = false;
        }
    }

    // The reveal trigger: the bottom edge, dock-width, a few pixels tall.
    Item {
        id: trigger

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: surface.width
        // While the dock is out, the strip stretches up to meet it, so moving
        // between the two never crosses a gap where hover would be lost.
        height: root.revealed ? Appearance.m.screenGap + 3 : 3

        HoverHandler { id: triggerHover }
    }

    Tooltip {
        id: tip
        anchorY: surface.y
        visible: root.revealed && opacity > 0
        z: 1
    }

    Surface {
        id: surface

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.revealed
            ? Appearance.m.screenGap : -(root.dockHeight + Appearance.m.screenGap)
        width: layout.implicitWidth + Appearance.m.dockPadding * 2
        height: root.dockHeight
        radius: Appearance.r.lg
        elevation: 3

        Behavior on anchors.bottomMargin {
            NumberAnimation {
                duration: Appearance.t.base
                easing.type: Appearance.t.emphasizedEasing
            }
        }

        HoverHandler { id: dockHover }

        Row {
            id: layout
            anchors.centerIn: parent
            spacing: Appearance.m.dockGap

            DockButton {
                icon: "grid"
                tipText: qsTr("Overview")
                onActivated: Compositor.toggleOverview()
                onHoverChanged: (key, label, centerX, entered) =>
                    root.onChildHover(key, label, centerX, entered)
            }

            DockSeparator {}

            Repeater {
                model: Dock.items

                DockItem {
                    required property var modelData
                    required property int index

                    item: this.modelData
                    screen: root.modelData
                    slide: root.slideFor(this.index)
                    rearranging: root.dragSlot >= 0
                    onHoverChanged: (key, label, centerX, entered) =>
                        root.onChildHover(key, label, centerX, entered)

                    onDragMoved: dx => {
                        root.dragSlot = this.index;
                        root.dropSlot = Math.max(0, Math.min(Dock.items.length - 1,
                            this.index + Math.round(dx / root.slotStride)));
                    }
                    onDragEnded: {
                        const from = root.dragSlot;
                        const to = root.dropSlot;
                        // Cleared before the move, so the offsets are already
                        // gone by the time the new order is laid out.
                        root.dragSlot = -1;
                        root.dropSlot = -1;
                        Dock.moveItem(from, to);
                    }
                }
            }

            DockSeparator { visible: Dock.items.length > 0 }

            DockButton {
                icon: "apps"
                tipText: qsTr("Applications")
                selected: Overlay.isOpen(Overlay.launcher)
                onActivated: Overlay.toggle(Overlay.launcher, root.modelData)
                onHoverChanged: (key, label, centerX, entered) =>
                    root.onChildHover(key, label, centerX, entered)
            }
        }
    }
}
