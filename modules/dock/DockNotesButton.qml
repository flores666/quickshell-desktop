pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

DockDraggable {
    id: root

    readonly property var note: DailyNotes.preview
    readonly property string heading: qsTr("Daily Notes")
    readonly property string summary: root.note?.title ?? root.heading
    readonly property string range: DailyNotes.rangeText(root.note)
    readonly property string tipText: root.range !== ""
        ? qsTr("%1 · %2").arg(root.summary).arg(root.range) : root.summary

    implicitWidth: Appearance.m.dockNotesWidth
    implicitHeight: Appearance.m.dockSlot
    selected: Overlay.isOpen(Overlay.dailyNotes) && Overlay.screen === root.screen
    Accessible.role: Accessible.Button
    Accessible.name: root.heading
    Accessible.description: root.note ? root.summary : ""
    onInvoked: Overlay.toggle(Overlay.dailyNotes, root.screen, root.centerX())
    onDraggingChanged: if (root.dragging && root.selected) Overlay.close()
    onPointerOverChanged: root.hoverChanged(Dock.notesSlot.key, root.tipText, root.centerX(), root.pointerOver)

    Icon {
        id: mark
        x: Appearance.s.lg
        anchors.verticalCenter: parent.verticalCenter
        name: root.note?.id === DailyNotes.trackedId ? "pin" : "calendar"
        size: Appearance.m.iconLg
        color: root.selected ? root.scheme.accent : root.scheme.text
    }

    Column {
        anchors.verticalCenter: parent.verticalCenter
        x: mark.x + mark.width + Appearance.s.sm
        width: root.width - x - Appearance.s.lg

        Label {
            id: summaryLabel
            width: parent.width
            text: root.summary
            role: Label.Role.Small
            surface: root.panel
        }

        Label {
            width: parent.width
            visible: root.range !== "" && summaryLabel.implicitHeight + implicitHeight <= root.height
            text: root.range
            role: Label.Role.Caption
            muted: true
            surface: root.panel
        }
    }
}
