pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    One scheduled task: its name, when it runs and runs next, and how its last
    run went; a switch to turn it off and on, a button to run it now, and a
    menu (right click, the Menu key, or its button) to edit or delete it.
*/
Clickable {
    id: root

    required property var modelData
    readonly property var task: root.modelData

    signal edit(var task)

    implicitHeight: texts.implicitHeight + Appearance.s.md * 2
    radius: Appearance.r.sm
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: root.edit(root.task)
    onRightClicked: root.openMenu()

    function openMenu(): void {
        Overlay.openMenu(more, [
            { label: qsTr("Edit"), icon: "settings", run: () => root.edit(root.task) },
            { label: qsTr("Run Now"), icon: "play", run: () => Tasks.runNow(root.task.id) },
            { label: qsTr("Delete"), icon: "trash", danger: true, run: () => Tasks.remove(root.task.id) }
        ]);
    }

    readonly property string when: {
        const words = TaskUnits.describe(root.task.schedule);
        if (!root.task.enabled)
            return qsTr("%1 · off").arg(words);
        return root.task.next > 0 ? qsTr("%1 · next %2").arg(words).arg(Tasks.formatWhen(root.task.next)) : words;
    }

    readonly property string outcome: {
        switch (root.task.result) {
        case "running": return qsTr("Running…");
        case "success": return qsTr("Ran %1 · succeeded").arg(Tasks.formatWhen(root.task.last));
        case "failed":
            return qsTr("Ran %1 · failed with status %2").arg(Tasks.formatWhen(root.task.last)).arg(root.task.status);
        }
        return qsTr("Not run yet");
    }

    Column {
        id: texts
        anchors.verticalCenter: parent.verticalCenter
        x: Appearance.s.lg
        width: controls.x - x - Appearance.s.lg
        spacing: 1

        Label {
            width: parent.width
            text: root.task.name
            font.weight: Font.Medium
            elide: Text.ElideRight
        }

        Label {
            width: parent.width
            text: root.when
            role: Label.Role.Small
            muted: true
            elide: Text.ElideRight
        }

        Label {
            width: parent.width
            text: root.outcome
            role: Label.Role.Small
            color: root.task.result === "failed" ? Appearance.c.danger : Appearance.c.textMuted
            elide: Text.ElideRight
        }
    }

    Row {
        id: controls
        anchors.verticalCenter: parent.verticalCenter
        x: root.width - width - Appearance.s.md
        spacing: Appearance.s.xs

        ToggleSwitch {
            anchors.verticalCenter: parent.verticalCenter
            checked: root.task.enabled
            onToggled: value => Tasks.setEnabled(root.task.id, value)
        }

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: "play"
            enabled: root.task.result !== "running"
            onClicked: Tasks.runNow(root.task.id)
        }

        IconButton {
            id: more
            anchors.verticalCenter: parent.verticalCenter
            icon: "more"
            onClicked: root.openMenu()
        }
    }
}
