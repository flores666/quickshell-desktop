pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"

InputField {
    id: root

    required property bool canSave
    property string destinationName
    property string destinationHint
    property string saveLabel: qsTr("Save task")
    property bool containFocus: false
    readonly property Item inputNeighbor: root.containFocus ? (save.enabled ? save : root.input) : null

    height: Math.max(implicitHeight, Appearance.m.compactButton + Appearance.s.xs * 2)
    rightInset: width - actions.x + Appearance.s.sm
    placeholder: qsTr("Type to add new task")
    placeholderColor: Appearance.c.textMuted
    input.Accessible.name: qsTr("New task")
    input.KeyNavigation.tab: root.inputNeighbor
    input.KeyNavigation.backtab: root.inputNeighbor

    trailing: Row {
        id: actions
        anchors.right: parent.right
        anchors.rightMargin: Appearance.s.xs
        anchors.verticalCenter: parent.verticalCenter
        spacing: Appearance.s.xs

        Label {
            objectName: "quickNoteDestination"
            anchors.verticalCenter: parent.verticalCenter
            visible: text !== ""
            width: Math.min(implicitWidth, root.width / 3)
            text: root.destinationName === "" ? root.destinationHint : qsTr("To %1").arg(root.destinationName)
            role: Label.Role.Small
            muted: true
            horizontalAlignment: Text.AlignRight
            Accessible.ignored: true
        }

        IconButton {
            id: save
            size: Appearance.m.compactButton
            icon: "check"
            enabled: root.canSave
            KeyNavigation.tab: root.containFocus ? root.input : null
            KeyNavigation.backtab: root.containFocus ? root.input : null
            Accessible.role: Accessible.Button
            Accessible.name: root.saveLabel
            onClicked: root.accepted()
        }
    }
}
