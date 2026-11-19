pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

Column {
    id: root

    required property var draft
    signal finished

    readonly property bool validTimes: DailyNotes.validRange(start.text.trim(), end.text.trim())
    readonly property bool canSave: DailyNotes.ready && taskTitle.text.trim() !== "" && root.validTimes

    spacing: Appearance.s.md

    function save(): void {
        if (root.canSave && DailyNotes.save(root.draft.day, root.draft.id, taskTitle.text, start.text, end.text))
            root.finished();
    }

    Component.onCompleted: Qt.callLater(() => taskTitle.input.forceActiveFocus())

    Label {
        text: root.draft.id === "" ? qsTr("New Task") : qsTr("Edit Task")
        role: Label.Role.Subtitle
    }

    InputField {
        id: taskTitle
        objectName: "noteTitle"
        width: root.width
        text: root.draft.title
        placeholder: qsTr("Task name")
        onAccepted: root.save()
    }

    Label {
        text: qsTr("Time window (optional)")
        role: Label.Role.Small
        muted: true
    }

    Row {
        width: root.width
        spacing: Appearance.s.md

        InputField {
            id: start
            objectName: "noteStart"
            width: (parent.width - parent.spacing) / 2
            text: root.draft.start
            placeholder: qsTr("Start (HH:MM)")
            onAccepted: end.input.forceActiveFocus()
        }

        InputField {
            id: end
            objectName: "noteEnd"
            width: start.width
            text: root.draft.end
            placeholder: qsTr("End (HH:MM)")
            onAccepted: root.save()
        }
    }

    Label {
        width: root.width
        visible: !root.validTimes
        text: qsTr("Enter both times in HH:MM, with the end after the start.")
        role: Label.Role.Small
        color: PopupStyle.danger
        wrapMode: Text.WordWrap
    }

    Row {
        anchors.right: parent.right
        spacing: Appearance.s.md

        TextButton {
            text: qsTr("Cancel")
            compact: true
            onClicked: root.finished()
        }

        TextButton {
            objectName: "saveNote"
            text: qsTr("Save")
            compact: true
            kind: TextButton.Kind.Accent
            enabled: root.canSave
            onClicked: root.save()
        }
    }
}
