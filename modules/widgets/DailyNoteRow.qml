pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

Clickable {
    id: root

    required property var note
    property var draft: null
    property Component editor: null
    signal editRequested(string id, int annotationIndex)
    readonly property string deadlineTime: root.note?.deadline.slice(11) ?? ""
    readonly property bool done: root.note?.done ?? false
    readonly property bool showPreviewPin: DailyNotes.previewPinId === root.note?.id

    implicitHeight: labels.implicitHeight + Appearance.s.xs * 2
    acceptedButtons: Qt.RightButton
    focusable: !root.draft
    focusRingTarget: checkmark
    showStateLayer: !root.draft
    cursorShape: Qt.ArrowCursor
    enabled: DailyNotes.ready && root.note !== null
    Accessible.role: root.draft ? Accessible.Grouping : Accessible.CheckBox
    Accessible.name: root.note?.title ?? ""
    Accessible.description: [root.deadlineTime, root.showPreviewPin ? qsTr("Shown in the Dock") : ""].filter(Boolean).join(" · ")
    Accessible.checked: root.done
    Accessible.checkable: !root.draft
    Accessible.onToggleAction: root.toggleDone()
    onClicked: root.toggleDone()
    onRightClicked: event => root.openMenu(event)

    function toggleDone(): void {
        if (root.enabled && !root.draft)
            DailyNotes.toggleDone(root.note.id);
    }

    function openMenu(event: var): void {
        if (!root.enabled || !Overlay.isOpen(Overlay.dailyNotes))
            return;
        const id = root.note.id;
        const position = event ? root.mapToItem(null, event.x, event.y) : undefined;
        Overlay.openMenu(titleLine, [
            { label: qsTr("Edit"), icon: "settings", run: () => {
                if (titleLine.input)
                    titleLine.input.forceActiveFocus();
                else
                    root.editRequested(id, -1);
            } },
            { label: qsTr("Add note"), icon: "add", run: () => root.editRequested(id, annotations.entries.length) },
            { label: qsTr("Delete"), icon: "trash", danger: true, run: () => DailyNotes.remove(id) }
        ], position);
    }

    Clickable {
        id: checkmark
        objectName: "noteCheckbox"
        x: Appearance.s.xs
        y: labels.y + (titleLine.height - height) / 2
        width: Appearance.m.iconLg
        height: width
        radius: Appearance.r.xs
        background: root.done ? Appearance.c.accent : "transparent"
        acceptedButtons: root.draft ? Qt.NoButton : Qt.LeftButton
        focusable: false
        Accessible.ignored: true
        onClicked: root.toggleDone()

        Rectangle {
            anchors.fill: parent
            radius: checkmark.radius
            color: "transparent"
            border.width: Appearance.m.controlBorder
            border.color: root.done ? Appearance.c.accent : Appearance.c.borderStrong
        }

        Icon {
            anchors.centerIn: parent
            visible: root.done
            name: "check"
            size: Appearance.m.iconSm
            color: Appearance.c.accentText
        }
    }

    Column {
        id: labels
        spacing: Appearance.s.xxs
        y: Appearance.s.xs
        x: checkmark.x + checkmark.width + Appearance.s.md
        width: Math.max(0, root.width - x - Appearance.s.xs)

        DailyNoteText {
            id: titleLine
            width: Math.max(0, labels.width - (root.showPreviewPin ? pin.width + Appearance.s.xs : 0))
            minimumHeight: checkmark.height
            labelName: "noteTitleLabel"
            text: root.note?.title ?? ""
            muted: root.done
            strikeout: root.done
            editor: root.draft && !root.draft.annotation ? root.editor : null
            onEditRequested: root.editRequested(root.note.id, -1)
        }

        DailyNoteDeadlineBadge {
            id: deadlineBadge
            objectName: "noteDeadlineBadge"
            availableWidth: labels.width
            text: root.deadlineTime
            onClicked: Overlay.openMenuContent(deadlineBadge, deadlinePicker, titleLine.input ?? deadlineBadge)
            onClearRequested: DailyNotes.setDeadlineTime(root.note.id, "")
        }

        DailyNoteAnnotations {
            id: annotations
            x: Appearance.s.md
            width: Math.max(0, labels.width - x)
            task: root.note
            returnFocus: titleLine.input ?? root
            draft: root.draft?.annotation ?? null
            editor: root.editor
            onEditRequested: index => root.editRequested(root.note.id, index)
        }
    }

    Icon {
        id: pin
        anchors.right: parent.right
        anchors.rightMargin: Appearance.s.xs
        y: checkmark.y + (checkmark.height - height) / 2
        visible: root.showPreviewPin && !titleLine.editor
        name: "pin"
        size: Appearance.m.iconSm
        color: Appearance.c.accent
    }

    Component {
        id: deadlinePicker

        DailyNoteDeadlinePicker {
            time: root.deadlineTime
            onSelected: time => DailyNotes.setDeadlineTime(root.note.id, time)
        }
    }
}
