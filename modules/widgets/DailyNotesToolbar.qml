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
    property bool categoryEntryOpen: false
    readonly property bool canAddCategory: DailyNotes.canAddCategory(root.day, name.text)
    signal categoryAdded
    signal previousDay
    signal nextDay

    height: Math.max(actions.height, date.implicitHeight)

    function containsCategoryEntry(scenePosition: point): bool {
        return reveal.contains(reveal.mapFromItem(null, scenePosition))
            || add.contains(add.mapFromItem(null, scenePosition));
    }

    function addCategory(): void {
        if (!root.categoryEntryOpen || !root.enabled || !root.actionsEnabled || !root.canAddCategory)
            return;
        if (DailyNotes.addCategory(root.day, name.text) === null) {
            name.input.forceActiveFocus();
            return;
        }
        root.categoryEntryOpen = false;
        root.categoryAdded();
    }

    Label {
        id: date
        anchors.left: parent.left
        anchors.right: reveal.left
        anchors.rightMargin: Appearance.s.sm
        anchors.verticalCenter: parent.verticalCenter
        text: Qt.formatDate(DailyNotes.dateFor(root.day), "ddd, d MMM")
        role: Label.Role.Subtitle
    }

    Item {
        id: reveal

        anchors.right: actions.left
        anchors.verticalCenter: parent.verticalCenter
        width: root.categoryEntryOpen ? name.width + Appearance.s.xs : 0
        height: actions.height
        visible: root.categoryEntryOpen || reveal.width > 0
        clip: true

        Behavior on width {
            NumberAnimation { duration: Appearance.t.popupMove; easing.type: Appearance.t.resizeEasing }
        }

        InputField {
            id: name

            objectName: "newNoteCategoryName"
            width: Math.max(0, Math.min(implicitWidth, actions.x - Appearance.s.xs))
            height: reveal.height
            enabled: root.categoryEntryOpen && root.actionsEnabled
            placeholder: qsTr("Category name")
            placeholderColor: Appearance.c.textMuted
            input.color: Appearance.c.textMuted
            input.Accessible.name: qsTr("Category name")
            onAccepted: root.addCategory()
        }
    }

    Row {
        id: actions
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Appearance.s.xs
        enabled: root.actionsEnabled

        IconButton {
            id: add
            objectName: "newNoteCategory"
            size: Appearance.m.compactButton
            icon: root.categoryEntryOpen ? "check" : "add"
            enabled: DailyNotes.ready && (!root.categoryEntryOpen || root.canAddCategory)
            Accessible.role: Accessible.Button
            Accessible.name: root.categoryEntryOpen ? qsTr("Save category") : qsTr("Add category")
            onClicked: {
                if (root.categoryEntryOpen) {
                    root.addCategory();
                } else {
                    name.text = "";
                    root.categoryEntryOpen = true;
                    name.input.forceActiveFocus();
                }
            }
        }

        IconButton {
            objectName: "previousNoteDay"
            size: Appearance.m.compactButton
            icon: "chevron-left"
            enabled: root.canGoBack
            Accessible.role: Accessible.Button
            Accessible.name: qsTr("Previous day with notes")
            onClicked: root.previousDay()
        }

        IconButton {
            objectName: "nextNoteDay"
            size: Appearance.m.compactButton
            icon: "chevron-right"
            enabled: root.canGoForward
            Accessible.role: Accessible.Button
            Accessible.name: qsTr("Next day with notes")
            onClicked: root.nextDay()
        }
    }
}
