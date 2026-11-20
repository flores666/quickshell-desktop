pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import "root:/config"
import "root:/components"
import "root:/services"

DockDraggable {
    id: root

    readonly property bool caughtUp: DailyNotes.caughtUp
    readonly property var note: DailyNotes.dockPreview
    readonly property string heading: qsTr("Daily Notes")
    readonly property string summary: root.caughtUp ? qsTr("No tasks") : (root.note?.title ?? root.heading)
    readonly property string deadlineText: DailyNotes.deadlineText(root.note?.deadline ?? "")
    readonly property string progressText: root.caughtUp
        ? qsTr("All caught up") : DailyNotes.progressText(DailyNotes.todayChecklist)
    readonly property real progress: !root.caughtUp && DailyNotes.todayChecklist.total > 0
        ? DailyNotes.todayChecklist.done / DailyNotes.todayChecklist.total : 0
    readonly property string tipText: root.deadlineText !== ""
        ? qsTr("%1 · %2 · %3").arg(root.summary).arg(root.deadlineText).arg(root.progressText)
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

    Item {
        id: badge
        anchors.left: parent.left
        anchors.leftMargin: Appearance.s.md
        anchors.verticalCenter: parent.verticalCenter
        width: Appearance.m.dockNotesBadge
        height: width
        visible: root.caughtUp

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: Appearance.m.controlBorder
                strokeColor: root.scheme.borderStrong
                fillGradient: RadialGradient {
                    centerX: badge.width / 2
                    centerY: centerX
                    centerRadius: centerX
                    focalX: centerX
                    focalY: centerY
                    GradientStop { position: 0; color: root.scheme.raised }
                    GradientStop { position: 1; color: root.scheme.borderStrong }
                }
                PathRectangle { width: badge.width; height: width; radius: width / 2 }
            }
        }

        Icon {
            anchors.centerIn: parent
            name: "check"
            size: Appearance.m.iconLg
            color: root.scheme.text
        }
    }

    Column {
        anchors.left: root.caughtUp ? badge.right : parent.left
        anchors.leftMargin: root.caughtUp ? Appearance.s.xl : Appearance.s.lg
        anchors.right: ring.left
        anchors.rightMargin: Appearance.s.sm
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.caughtUp ? Math.min(0, root.height - summaryLabel.implicitHeight - detailLabel.implicitHeight) : 0

        Label {
            id: summaryLabel
            width: parent.width
            text: root.summary
            role: Label.Role.Small
            font.weight: Font.DemiBold
            surface: root.panel
        }

        Label {
            id: detailLabel
            width: parent.width
            visible: root.caughtUp || summaryLabel.implicitHeight + implicitHeight <= root.height
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
