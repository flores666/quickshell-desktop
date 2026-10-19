pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    The bottom dock: a glass capsule holding the pinned applications and every
    one that has a window open, then the application grid. Resting on the icon
    of an application with several windows open previews them (DockPreview).
    The overview is Super+Tab and the three-finger swipe; it has no button here.

    By default it hides itself when it is not being used and slides back when
    the pointer reaches the bottom edge. The reveal trigger is a few pixels
    tall, invisible, and only as wide as the dock; the window reserves no space
    at all, and input is masked to the dock plus that strip, so everything else
    on screen stays click-through. The strip stays in the input region while the
    dock is out, so crossing the gap between them cannot drop the hover and
    start a hide.

    With auto-hide off (Settings.dockAutoHide) the dock stays out and reserves
    its footprint the way the bar does, so windows stop above it rather than
    sitting under it for good. With its background off (Settings.dockBackground)
    the glass, edge and shadow go and the icons stand on their own.
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

    Component.onCompleted: root.pointerKey = "dock:" + root.modelData.name

    readonly property HyprlandMonitor monitor: Compositor.monitorFor(root.modelData)
    readonly property bool suppressed: Compositor.isFullscreenOn(root.monitor)
    readonly property int dockHeight: Appearance.m.dockHeight

    /*! Which dock child the pointer is on, so hiding is never ambiguous. */
    property string hoveredKey: ""

    readonly property bool pointerNear: dockHover.hovered || triggerHover.hovered || preview.hovered
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

    readonly property int slotStride: Appearance.m.dockSlot + Appearance.m.dockGap

    /*! Whether the pointer has called the dock out; it goes on tracking that
        while auto-hide is off, so turning it back on starts from the truth. */
    property bool revealed: false

    /*! The background, eased as it comes and goes: `glass` fades it, its edge
        and its shadow together, and `frame` and `base` (Metrics) move on the
        clock the dock's height does, so the icons settle with it. A theme
        change still recolours the glass at once, like any other surface. */
    property real glass: Settings.dockBackground ? 1 : 0
    property real frame: Appearance.m.dockFrame
    property real base: Appearance.m.dockBase

    Behavior on glass {
        NumberAnimation { duration: Appearance.t.base; easing.type: Appearance.t.standardEasing }
    }
    Behavior on frame {
        NumberAnimation { duration: Appearance.t.base; easing.type: Appearance.t.emphasizedEasing }
    }
    Behavior on base {
        NumberAnimation { duration: Appearance.t.base; easing.type: Appearance.t.emphasizedEasing }
    }
    readonly property bool shown: root.revealed || !Settings.dockAutoHide

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
    // Room above the dock for the preview and the tooltip, kept whether or not
    // either shows: input is masked down to what is there, and a window that
    // grew to show one would draw its first frame before the compositor had
    // made it any bigger. For the same reason it is the room of the dock with
    // its background, whichever it has: a window that changed size with that
    // switch made the icons jump about while the dock eased.
    implicitHeight: Appearance.m.dockSlot + Appearance.m.dockClearance * 2
        + Appearance.m.screenGap + preview.room
    // Writing exclusiveZone forces exclusionMode to Normal (Quickshell's own
    // setter), so the mode is not bound alongside it: whichever was written
    // last at creation would win. -1 is what ExclusionMode.Ignore sends.
    exclusiveZone: Settings.dockAutoHide ? -1 : Appearance.m.dockFootprint
    anchors { bottom: true; left: true; right: true }

    WlrLayershell.namespace: "shell-dock"
    WlrLayershell.layer: WlrLayer.Top

    mask: Region {
        item: trigger
        Region { item: surface }
        Region { item: preview.visible ? preview : null }
    }

    onPointerNearChanged: {
        Overlay.setPointerOver(root.pointerKey, root.pointerNear);
        if (root.pointerNear) {
            hideTimer.stop();
            root.revealed = true;
        } else {
            hideTimer.restart();
        }
    }

    onHeldChanged: if (!root.held && !root.pointerNear) hideTimer.restart()

    Component.onDestruction: Overlay.setPointerOver(root.pointerKey, false)

    Timer {
        id: hideTimer
        interval: Dock.hideDelay
        onTriggered: if (!root.pointerNear && !root.held) root.revealed = false
    }

    /*! An application with several windows previews them; anything else is
        named by the tooltip. */
    function onChildHover(key: string, label: string, centerX: real, entered: bool): void {
        const x = surface.x + centerX;
        if (!entered) {
            preview.leave(key);
            if (root.hoveredKey === key) {
                root.hoveredKey = "";
                tip.show = false;
            }
            return;
        }
        root.hoveredKey = key;
        if (preview.offers(Dock.items.find(i => i.key === key) ?? null)) {
            tip.show = false;
            preview.enter(key, x);
        } else {
            preview.close();
            tip.text = label;
            tip.anchorX = x;
            tip.show = true;
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
        height: root.shown ? Appearance.m.screenGap + 3 : 3

        HoverHandler { id: triggerHover }
    }

    DockPreview {
        id: preview
        dockTop: surface.y
        screen: root.modelData
        suppressed: root.held || !root.shown
        z: 1
    }

    Tooltip {
        id: tip
        anchorY: surface.y
        visible: root.shown && opacity > 0
        z: 1
    }

    Surface {
        id: surface

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.shown
            ? Appearance.m.screenGap : -(root.dockHeight + Appearance.m.screenGap)
        width: layout.implicitWidth + root.frame * 2
        height: root.dockHeight
        radius: Appearance.r.capsule(root.dockHeight)
        // Without its background the dock is only its icons, with nothing
        // drawn behind them. Faded by its own alpha, so it never passes
        // through another colour on the way.
        color: Qt.alpha(Appearance.c.chrome, Appearance.c.chrome.a * root.glass)
        borderColor: Qt.alpha(Appearance.c.border, Appearance.c.border.a * root.glass)
        shadowOpacity: root.glass
        elevation: 3

        Behavior on anchors.bottomMargin {
            NumberAnimation { duration: Appearance.t.base; easing.type: Appearance.t.emphasizedEasing }
        }

        Behavior on height {
            // On the same clock as the margin, which is what keeps the hidden
            // dock hidden. The icon size is settable, so dockHeight can change
            // while the dock is away; the margin that parks it offscreen is
            // derived from that height, and if only one of the two eased, the
            // difference between them would open and close — the dock peeking
            // up over the bottom edge and sliding back for no reason.
            NumberAnimation { duration: Appearance.t.base; easing.type: Appearance.t.emphasizedEasing }
        }

        HoverHandler { id: dockHover }

        // Midway across the gap before the launcher, level with the icons'
        // centres; outside the row, so it adds nothing to its spacing.
        DockSeparator {
            visible: Dock.items.length > 0
            x: layout.x + launcher.x - Math.round((Appearance.m.dockGap + width) / 2)
            y: layout.y + Math.round((Appearance.m.dockSlot - height) / 2)
        }

        Row {
            id: layout
            // Held to the bottom rather than centred: without a background
            // there is room below the slots for their dots and none above, and
            // from the bottom the row moves only as far as that room changes.
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.base
            spacing: Appearance.m.dockGap

            Repeater {
                model: Dock.items

                DockItem {
                    required property var modelData
                    required property int index

                    item: this.modelData
                    screen: root.modelData
                    slide: root.slideFor(this.index)
                    rearranging: root.drag !== null
                    onClicked: preview.close()
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

            DockButton {
                id: launcher
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
