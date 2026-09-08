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
    readonly property bool held: Overlay.isOpen(Overlay.dockMenu) || root.drag !== null

    /*!
        The drag in flight: the slot the icon came from, and the slot it would
        land in.

        One property and not two. Assigning a pair of them leaves a frame in
        which `slideFor` sees the new drag against the last drop — QML
        re-evaluates every binding on the first write, before the second has
        happened — and with the drop still at its cleared -1 every icon left of
        the drag reads as being inside the gap. Measured on the frame a drag
        began: both icons to its left kicked 46px sideways and animated back,
        which is the cascade the dock used to show for a drag that had not
        reordered anything yet.
    */
    property var drag: null

    readonly property int slotStride: Appearance.m.dockCell + Appearance.m.dockGap

    property bool revealed: false

    /*! How far an icon has to step aside to open a gap where the drag will land. */
    function slideFor(slot: int): real {
        if (!root.drag || slot === root.drag.from)
            return 0;
        if (slot > root.drag.from && slot <= root.drag.to)
            return -root.slotStride;
        if (slot < root.drag.from && slot >= root.drag.to)
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
        interval: Dock.hideDelay
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

        Behavior on height {
            // On the same clock as the margin, which is what keeps the hidden
            // dock hidden. The icon size is settable, so dockHeight can change
            // while the dock is away; the margin that parks it offscreen is
            // derived from that height, and if only one of the two eased, the
            // difference between them would open and close — the dock peeking
            // up over the bottom edge and sliding back for no reason.
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
                    rearranging: root.drag !== null
                    onHoverChanged: (key, label, centerX, entered) =>
                        root.onChildHover(key, label, centerX, entered)

                    onDragMoved: dx => root.drag = ({
                        from: this.index,
                        to: Math.max(0, Math.min(Dock.items.length - 1,
                            this.index + Math.round(dx / root.slotStride)))
                    })
                    onDragEnded: {
                        const drag = root.drag;
                        // Cleared before the move, so the offsets are already
                        // gone by the time the new order is laid out.
                        root.drag = null;
                        if (drag)
                            Dock.moveItem(drag.from, drag.to);
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
