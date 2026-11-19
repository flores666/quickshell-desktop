pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    A movable item with its position and span measured by DockLayout. Its
    artwork magnifies without changing that horizontal footprint.
*/
Item {
    id: root

    /*! { key, item, leaving, arriving }, from DockRow. */
    required property var entry
    required property ShellScreen screen
    required property Surface panel
    readonly property bool widget: root.entry.key === Dock.notesSlot.key
    readonly property bool launcher: root.entry.key === Dock.launcherSlot.key
    readonly property real contentWidth: root.widget ? Appearance.m.dockNotesWidth : Appearance.m.dockSlot
    readonly property real artworkWidth: root.widget ? Appearance.m.dockNotesWidth
        : root.launcher ? Appearance.m.dockLauncherIcon : Appearance.m.dockIcon
    required property real centerOffset
    required property real controlExtension
    property real slide: 0
    property bool rearranging: false
    readonly property DockDraggable control: button.item as DockDraggable
    readonly property bool dragging: root.control?.dragging ?? false
    property alias targetMagnification: wave.targetScale
    readonly property real magnification: wave.value
    readonly property real growth: root.widget ? 0 : Appearance.m.dockIcon * (root.magnification - 1)

    signal clicked(var item, real centerX)
    signal hoverChanged(var key, string label, real centerX, bool entered)
    signal dragMoved(real dx)
    signal dragEnded
    signal dragCanceled
    /*! Shrunk out of the row: the row can drop it. */
    signal gone(var key)

    DockMagnification { id: wave }

    /*! How much of its place it takes up, 0 to 1. */
    property real presence: root.entry.arriving ? 0 : 1

    Component.onCompleted: root.presence = Qt.binding(() => root.entry.leaving ? 0 : 1)

    Behavior on presence {
        NumberAnimation { duration: Appearance.t.base; easing.type: Appearance.t.emphasizedEasing }
    }

    // A binding rather than the animation's end, which never fires inside a
    // Behavior (AGENTS.md).
    Timer {
        running: root.entry.leaving && root.presence === 0
        interval: 0
        onTriggered: root.gone(root.entry.key)
    }

    height: Appearance.m.dockSlot
    opacity: root.presence
    // Above its neighbours while it is being carried, so it is never clipped
    // by the icon it is passing over.
    z: root.dragging ? 1 : 0

    Loader {
        id: button
        enabled: !root.entry.leaving
        x: root.centerOffset - width / 2
        y: -root.growth + (root.widget ? root.controlExtension / 2 : 0)
        width: root.contentWidth
        height: root.height + root.growth + (root.launcher ? root.controlExtension : 0)
        scale: root.presence
        sourceComponent: root.widget ? noteButton : root.launcher ? launcherButton : appButton
    }

    Component {
        id: appButton
        DockItem {
            item: root.entry.item
            screen: root.screen
            panel: root.panel
            magnification: root.magnification
            slide: root.slide
            rearranging: root.rearranging
            onInvoked: root.clicked(root.entry.item, this.centerX())
        }
    }

    Component {
        id: launcherButton
        DockButton {
            screen: root.screen
            panel: root.panel
            controlExtension: root.controlExtension
            magnification: root.magnification
            slide: root.slide
            rearranging: root.rearranging
        }
    }

    Component {
        id: noteButton
        DockNotesButton {
            screen: root.screen
            panel: root.panel
            slide: root.slide
            rearranging: root.rearranging
        }
    }

    Connections {
        target: root.control
        function onHoverChanged(key: var, label: string, centerX: real, entered: bool): void {
            root.hoverChanged(key, label, centerX, entered);
        }
        function onDragMoved(dx: real): void { root.dragMoved(dx); }
        function onDragFinished(dropped: bool): void {
            if (dropped) root.dragEnded();
            else root.dragCanceled();
        }
    }
}
