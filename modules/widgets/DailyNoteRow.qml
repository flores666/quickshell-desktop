pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

Clickable {
    id: root

    required property var note
    signal editRequested(string id)
    readonly property string range: DailyNotes.rangeText(root.note)
    readonly property bool done: root.note?.done ?? false
    readonly property bool tracked: root.note !== null && DailyNotes.trackedId === root.note.id
    readonly property real trailingWidth: more.width + Appearance.s.xs
        + (root.tracked ? pin.width + Appearance.s.xs : 0)

    implicitHeight: Math.max(more.height, labels.implicitHeight + Appearance.s.xs * 2)
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.ArrowCursor
    enabled: DailyNotes.ready && root.note !== null
    Accessible.role: Accessible.CheckBox
    Accessible.name: root.note?.title ?? ""
    Accessible.description: root.range
    Accessible.checked: root.done
    Accessible.checkable: true
    Accessible.onToggleAction: root.toggleDone()
    onClicked: root.toggleDone()
    onRightClicked: root.openMenu()

    function toggleDone(): void {
        if (root.enabled)
            DailyNotes.toggleDone(root.note.id);
    }

    function openMenu(): void {
        const note = root.note;
        if (!root.enabled || !Overlay.isOpen(Overlay.dailyNotes))
            return;
        const id = note.id;
        const entries = [];
        if (!note.done) {
            entries.push({
                label: root.tracked ? qsTr("Stop Tracking") : qsTr("Track"),
                icon: "pin",
                run: () => DailyNotes.toggleTracking(id)
            });
        }
        entries.push(
            { label: qsTr("Edit"), icon: "settings", run: () => root.editRequested(id) },
            { label: qsTr("Delete"), icon: "trash", danger: true, run: () => DailyNotes.remove(id) }
        );
        Overlay.openMenu(more, entries);
    }

    Rectangle {
        id: checkmark
        x: Appearance.s.xs
        anchors.verticalCenter: parent.verticalCenter
        width: Appearance.m.iconLg
        height: width
        radius: Appearance.r.xs
        color: root.done ? Appearance.c.accent : "transparent"
        border.width: Appearance.m.controlBorder
        border.color: root.done ? Appearance.c.accent : Appearance.c.borderStrong

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
        anchors.verticalCenter: parent.verticalCenter
        x: checkmark.x + checkmark.width + Appearance.s.md
        width: Math.max(0, root.width - x - root.trailingWidth)

        Label {
            width: parent.width
            text: root.note?.title ?? ""
            muted: root.done
            font.strikeout: root.done
            wrapMode: Text.Wrap
            elide: Text.ElideNone
        }

        Label {
            width: parent.width
            visible: root.range !== ""
            text: root.range
            role: Label.Role.Small
            muted: true
        }
    }

    Icon {
        id: pin
        x: more.x - width - Appearance.s.xs
        anchors.verticalCenter: parent.verticalCenter
        visible: root.tracked
        name: "pin"
        size: Appearance.m.iconSm
        color: Appearance.c.accent
    }

    IconButton {
        id: more
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        size: Appearance.m.compactButton
        icon: "more"
        cursorShape: Qt.ArrowCursor
        iconColor: root.hovered || more.hovered || more.activeFocus ? Appearance.c.text : Appearance.c.textFaint
        Accessible.role: Accessible.Button
        Accessible.name: qsTr("Task actions")
        onClicked: root.openMenu()
    }
}
