pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    Commands systemd runs on a schedule (Tasks): the user's tasks, each with
    when it runs and how it last went, and in their place, while one is new
    or being changed, its editor. Below them, the user's other timers — the
    system's own and whatever else set one — to see, not to change.

    The list is read as the tab opens, for those other timers, which the
    shell hears nothing of; its own tasks it hears of as they run.
*/
Item {
    id: root

    property var manager: null
    /*! The task in the editor, `{}` for a new one; null for the list. */
    property var editing: null

    Component.onCompleted: Tasks.read()

    Label {
        x: Appearance.s.xl
        y: (root.manager.barHeight - height) / 2
        text: qsTr("Scheduled")
        role: Label.Role.Subtitle
    }

    TextButton {
        anchors.right: parent.right
        anchors.rightMargin: Appearance.s.xl
        y: (root.manager.barHeight - height) / 2
        visible: root.editing === null
        icon: "add"
        text: qsTr("New Task")
        onClicked: root.editing = {}
    }

    Flickable {
        id: scroller

        anchors.fill: parent
        anchors.topMargin: root.manager.barHeight + Appearance.s.xl
        anchors.leftMargin: Appearance.s.xl
        anchors.rightMargin: Appearance.s.xl
        clip: true
        contentHeight: page.implicitHeight + Appearance.s.xl
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: page

            width: scroller.width - scrollbar.footprint
            spacing: Appearance.s.lg

            Loader {
                width: page.width
                active: root.editing !== null
                visible: this.active
                sourceComponent: TaskEditor {
                    width: page.width
                    task: root.editing
                    onDone: root.editing = null
                }
            }

            SettingGroup {
                width: page.width
                visible: root.editing === null
                title: qsTr("Tasks")

                Repeater {
                    model: Tasks.tasks

                    TaskRow {
                        width: parent.width
                        onEdit: task => root.editing = task
                    }
                }

                Label {
                    width: parent.width
                    visible: Tasks.tasks.length === 0
                    text: qsTr("None yet. A task runs a command on a schedule or at login, through systemd, "
                        + "whether or not the desktop is up.")
                    role: Label.Role.Small
                    muted: true
                    wrapMode: Text.Wrap
                }
            }

            SettingGroup {
                width: page.width
                visible: root.editing === null && Tasks.others.length > 0
                title: qsTr("Other timers")

                Repeater {
                    model: Tasks.others

                    MenuRow {
                        required property var modelData

                        width: parent.width
                        flush: true
                        title: this.modelData.unit
                        subtitle: [
                            this.modelData.next > 0 ? qsTr("next %1").arg(Tasks.formatWhen(this.modelData.next)) : "",
                            this.modelData.last > 0 ? qsTr("last %1").arg(Tasks.formatWhen(this.modelData.last)) : ""
                        ].filter(s => s !== "").join(" · ") || qsTr("Not scheduled")
                    }
                }
            }
        }
    }

    ThinScrollBar { id: scrollbar; flickable: scroller }
}
