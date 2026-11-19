pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import "root:/config"
import "root:/components"
import "root:/services"

DockDraggable {
    id: root

    readonly property var note: DailyNotes.preview
    readonly property string heading: qsTr("Daily Notes")
    readonly property string summary: root.note?.title ?? root.heading
    readonly property string range: DailyNotes.rangeText(root.note)
    readonly property string progressText: DailyNotes.progressText(DailyNotes.todayChecklist)
    readonly property real progress: DailyNotes.todayChecklist.total > 0
        ? DailyNotes.todayChecklist.done / DailyNotes.todayChecklist.total : 0
    readonly property string tipText: root.range !== ""
        ? qsTr("%1 · %2 · %3").arg(root.summary).arg(root.range).arg(root.progressText)
        : qsTr("%1 · %2").arg(root.summary).arg(root.progressText)

    implicitWidth: Appearance.m.dockNotesWidth
    implicitHeight: Appearance.m.dockSlot
    background: root.scheme.raised
    selected: Overlay.isOpen(Overlay.dailyNotes) && Overlay.screen === root.screen
    Accessible.role: Accessible.Button
    Accessible.name: root.heading
    Accessible.description: root.tipText
    onInvoked: Overlay.toggle(Overlay.dailyNotes, root.screen, root.centerX())
    onDraggingChanged: if (root.dragging && root.selected) Overlay.close()
    onPointerOverChanged: root.hoverChanged(Dock.notesSlot.key, root.tipText, root.centerX(), root.pointerOver)

    Column {
        anchors.left: parent.left
        anchors.leftMargin: Appearance.s.lg
        anchors.right: ring.left
        anchors.rightMargin: Appearance.s.sm
        anchors.verticalCenter: parent.verticalCenter

        Label {
            id: summaryLabel
            width: parent.width
            text: root.summary
            role: Label.Role.Small
            font.weight: Font.DemiBold
            surface: root.panel
        }

        Label {
            width: parent.width
            visible: summaryLabel.implicitHeight + implicitHeight <= root.height
            text: root.progressText
            role: Label.Role.Caption
            muted: true
            surface: root.panel
        }
    }

    Rectangle {
        id: ring

        anchors.right: parent.right
        anchors.rightMargin: Appearance.s.md
        anchors.verticalCenter: parent.verticalCenter
        width: Appearance.m.dockNotesRing
        height: width
        radius: width / 2
        color: "transparent"
        border.width: Appearance.m.dockNotesRingStroke
        border.color: root.scheme.borderStrong

        Shape {
            anchors.fill: parent
            visible: root.progress > 0
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: ring.border.width
                strokeColor: root.scheme.accent
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: ring.width / 2
                    centerY: ring.height / 2
                    radiusX: (ring.width - ring.border.width) / 2
                    radiusY: radiusX
                    startAngle: -90
                    sweepAngle: root.progress * 360
                }
            }
        }
    }
}
