pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"

Clickable {
    id: root

    required property string category
    required property var group
    required property color fill
    required property matrix4x4 cardTransform
    property bool taskDestination: false
    property bool reorderEnabled: false
    property bool carried: false
    property real lift: 0
    property real layoutScale: 1
    signal selectRequested(string category)
    signal editRequested(string id)
    signal deleteRequested(string category)
    signal gripStarted(point cursor, point origin, point grab, real heldFor)
    signal gripMoved(point cursor)
    signal gripReleased(point cursor)
    signal gripCanceled
    signal stepRequested(int delta)

    readonly property int count: root.group?.notes.size ?? 0

    implicitHeight: contents.implicitHeight + Appearance.s.md * 2
    height: implicitHeight
    radius: Appearance.r.lg
    transform: Matrix4x4 { matrix: root.cardTransform }
    focusable: false
    showStateLayer: false
    opacity: 1
    cursorShape: Qt.ArrowCursor
    onClicked: if (DailyNotes.ready) root.selectRequested(root.category)

    // Observe presses through the card's Clickables and take the grab only
    // after Qt recognizes a drag. Until then each control owns its click.
    DragHandler {
        id: drag
        target: null
        enabled: root.reorderEnabled
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad | PointerDevice.Stylus
        acceptedButtons: Qt.LeftButton
        grabPermissions: PointerHandler.CanTakeOverFromItems | PointerHandler.ApprovesCancellation
        cursorShape: Qt.ClosedHandCursor

        onGrabChanged: (transition, point) => {
            if (transition === PointerDevice.GrabExclusive) {
                InputMode.pointerUsed();
                grip.forceActiveFocus(Qt.MouseFocusReason);
                root.gripStarted(point.scenePosition, drag.centroid.scenePressPosition,
                    drag.centroid.pressPosition, point.timeHeld);
            } else if (transition === PointerDevice.UngrabExclusive && point.state === EventPoint.Released) {
                root.gripReleased(point.scenePosition);
            } else if (transition === PointerDevice.UngrabExclusive || transition === PointerDevice.CancelGrabExclusive) {
                root.gripCanceled();
            }
        }
        onCentroidChanged: if (drag.active) root.gripMoved(drag.centroid.scenePosition)
    }

    Loader {
        id: shadow
        anchors.fill: parent
        active: root.lift > 0
        sourceComponent: Shadow {
            anchors.fill: shadow
            radius: root.radius
            level: 4
            hollow: true
            opacity: root.lift
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.fill
    }

    Column {
        id: contents

        x: Appearance.s.md
        y: Appearance.s.md
        width: Math.max(0, root.width - x * 2)
        spacing: Appearance.s.xxs

        Item {
            width: contents.width
            height: Math.max(remove.height, title.implicitHeight, count.implicitHeight)

            Label {
                id: title
                anchors.left: parent.left
                anchors.right: count.left
                anchors.rightMargin: Appearance.s.sm
                anchors.verticalCenter: parent.verticalCenter
                text: root.category
                role: Label.Role.Subtitle
                wrapMode: Text.Wrap
                elide: Text.ElideNone
            }

            Label {
                id: count
                anchors.right: destination.left
                anchors.rightMargin: Appearance.s.xs
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("%1 / %2").arg(root.group?.done ?? 0).arg(root.count)
                role: Label.Role.Small
                muted: true
            }

            Clickable {
                id: grip
                objectName: "dragNoteCategory"
                anchors.left: parent.left
                anchors.right: destination.left
                height: parent.height
                enabled: DailyNotes.ready
                showStateLayer: false
                cursorShape: Qt.ArrowCursor
                Accessible.role: Accessible.Button
                Accessible.name: qsTr("Select %1").arg(title.text)
                Accessible.description: root.reorderEnabled ? qsTr("Use the Up and Down arrow keys to reorder.") : ""
                onClicked: root.selectRequested(root.category)
                Keys.onUpPressed: {
                    InputMode.keyboardUsed();
                    root.stepRequested(-1);
                }
                Keys.onDownPressed: {
                    InputMode.keyboardUsed();
                    root.stepRequested(1);
                }
            }

            IconButton {
                id: destination
                objectName: "selectNoteDestination"
                anchors.right: remove.left
                anchors.verticalCenter: parent.verticalCenter
                enabled: DailyNotes.ready
                size: Appearance.m.compactButton
                iconSize: Appearance.m.iconSm
                icon: "target"
                accented: root.taskDestination
                cursorShape: Qt.ArrowCursor
                Accessible.role: Accessible.Button
                Accessible.name: qsTr("Add new tasks to %1").arg(title.text)
                Accessible.checkable: true
                Accessible.checked: root.taskDestination
                onClicked: root.selectRequested(root.category)
            }

            IconButton {
                id: remove
                objectName: "deleteNoteCategory"
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                enabled: DailyNotes.ready
                size: Appearance.m.compactButton
                icon: "trash"
                iconSize: Appearance.m.iconSm
                iconColor: PopupStyle.danger
                cursorShape: Qt.ArrowCursor
                Accessible.role: Accessible.Button
                Accessible.name: qsTr("Delete category %1").arg(title.text)
                onClicked: root.deleteRequested(root.category)
            }
        }

        Repeater {
            model: ScriptModel { values: root.group ? [...root.group.notes.keys()] : [] }

            DailyNoteRow {
                required property string modelData

                width: contents.width
                note: root.group?.notes.get(this.modelData) ?? null
                onEditRequested: id => root.editRequested(id)
            }
        }
    }
}
