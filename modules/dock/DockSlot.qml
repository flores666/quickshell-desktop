pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"

/*!
    An application's place in the dock's row: its icon (DockItem) and the gap
    after it, grown into as the application arrives and shrunk out of as it
    leaves, so its neighbours close up round it rather than jumping. One there
    when the dock is made is simply there.
*/
Item {
    id: root

    /*! { key, item, leaving, arriving }, from DockRow. */
    required property var entry
    required property ShellScreen screen
    property alias slide: icon.slide
    property alias rearranging: icon.rearranging
    readonly property bool dragging: icon.dragging

    signal clicked(var item, real centerX)
    signal hoverChanged(string key, string label, real centerX, bool entered)
    signal dragMoved(real dx)
    signal dragEnded
    /*! Shrunk out of the row: the row can drop it. */
    signal gone(string key)

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

    width: (Appearance.m.dockSlot + Appearance.m.dockGap) * root.presence
    height: Appearance.m.dockSlot
    opacity: root.presence
    // Above its neighbours while it is being carried, so it is never clipped
    // by the icon it is passing over.
    z: root.dragging ? 1 : 0

    DockItem {
        id: icon

        item: root.entry.item
        screen: root.screen
        // One that is leaving has nothing left to open; a click would launch it.
        enabled: !root.entry.leaving
        // Centred in what it takes up, and as small.
        x: Appearance.m.dockSlot * (root.presence - 1) / 2
        scale: root.presence

        onClicked: root.clicked(root.entry.item, icon.centerX())
        onHoverChanged: (key, label, centerX, entered) => root.hoverChanged(key, label, centerX, entered)
        onDragMoved: dx => root.dragMoved(dx)
        onDragEnded: root.dragEnded()
    }
}
