pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

Item {
    id: root

    required property string day
    required property bool canGoBack
    required property bool canGoForward
    required property bool actionsEnabled
    signal makeCategory(Item anchor)
    signal previousDay
    signal nextDay

    height: Math.max(actions.height, date.implicitHeight)

    Label {
        id: date
        anchors.left: parent.left
        anchors.right: actions.left
        anchors.rightMargin: Appearance.s.sm
        anchors.verticalCenter: parent.verticalCenter
        text: Qt.formatDate(DailyNotes.dateFor(root.day), "ddd, d MMM")
        role: Label.Role.Subtitle
    }

    Row {
        id: actions
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Appearance.s.xs
        enabled: root.actionsEnabled

        IconButton {
            objectName: "newNoteCategory"
            size: Appearance.m.compactButton
            icon: "add"
            enabled: DailyNotes.ready
            Accessible.role: Accessible.Button
            Accessible.name: qsTr("Add category")
            onClicked: root.makeCategory(this)
        }

        IconButton {
            objectName: "previousNoteDay"
            size: Appearance.m.compactButton
            icon: "chevron-left"
            enabled: root.canGoBack
            Accessible.role: Accessible.Button
            Accessible.name: qsTr("Previous day with tasks")
            onClicked: root.previousDay()
        }

        IconButton {
            objectName: "nextNoteDay"
            size: Appearance.m.compactButton
            icon: "chevron-right"
            enabled: root.canGoForward
            Accessible.role: Accessible.Button
            Accessible.name: qsTr("Next day with tasks")
            onClicked: root.nextDay()
        }
    }
}
