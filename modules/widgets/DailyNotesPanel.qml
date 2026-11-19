pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"
import "root:/modules/common"

ShellOverlay {
    id: root

    overlayId: Overlay.dailyNotes
    placement: ShellOverlay.Placement.AboveDock
    cardWidth: root.screen ? Math.min(Appearance.m.popoverWidth, root.screen.width - Appearance.s.md * 2)
        : Appearance.m.popoverWidth
    cardHeight: Math.min(Appearance.m.dailyNotesHeight, root.height)
    initialFocusItem: addTaskButton

    property string selectedDay: ""
    property var draft: null
    readonly property string day: root.draft?.day ?? (root.selectedDay || DailyNotes.today)
    readonly property var days: [...new Set([...DailyNotes.days, DailyNotes.today])].sort()
    readonly property string previousDay: {
        for (let i = root.days.length - 1; i >= 0; --i) {
            if (root.days[i] < root.day)
                return root.days[i];
        }
        return "";
    }
    readonly property string nextDay: root.days.find(day => day > root.day) ?? ""
    readonly property var notes: root.rendered ? DailyNotes.forDay(root.day) : []

    onShownChanged: if (root.shown) root.showDay(DailyNotes.today)
    onRenderedChanged: if (!root.rendered) root.draft = null
    onDayChanged: if (root.rendered) list.positionViewAtBeginning()

    function showDay(day: string): void {
        root.draft = null;
        root.selectedDay = day === DailyNotes.today ? "" : day;
        list.positionViewAtBeginning();
    }

    function edit(id: string): void {
        if (!root.shown || !DailyNotes.ready)
            return;
        const note = id === "" ? { id, day: root.day, title: "", start: "", end: "" } : DailyNotes.find(id);
        if (note)
            root.draft = note;
    }

    Connections {
        target: Settings
        function onDailyNotesEnabledChanged(): void {
            if (root.shown && !Settings.dailyNotesEnabled)
                Overlay.close();
        }
    }

    Item {
        anchors.fill: parent
        anchors.margins: Appearance.s.lg
        enabled: root.shown

        Item {
            id: header
            width: parent.width
            height: Appearance.m.touchTarget

            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Daily Notes")
                role: Label.Role.Title
            }

            TextButton {
                id: addTaskButton
                objectName: "addNote"
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Add Task")
                icon: "add"
                compact: true
                kind: TextButton.Kind.Accent
                enabled: DailyNotes.ready && root.draft === null
                onClicked: root.edit("")
            }
        }

        Item {
            id: dates
            width: parent.width
            height: Appearance.m.touchTarget
            anchors.top: header.bottom
            anchors.topMargin: Appearance.s.md
            enabled: root.draft === null

            Row {
                id: arrows
                anchors.verticalCenter: parent.verticalCenter

                IconButton {
                    objectName: "previousNoteDay"
                    size: Appearance.m.compactButton
                    icon: "chevron-left"
                    enabled: root.previousDay !== ""
                    Accessible.role: Accessible.Button
                    Accessible.name: qsTr("Previous day with tasks")
                    onClicked: root.showDay(root.previousDay)
                }

                IconButton {
                    size: Appearance.m.compactButton
                    icon: "chevron-right"
                    enabled: root.nextDay !== ""
                    Accessible.role: Accessible.Button
                    Accessible.name: qsTr("Next day with tasks")
                    onClicked: root.showDay(root.nextDay)
                }
            }

            Label {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: arrows.right
                anchors.leftMargin: Appearance.s.sm
                anchors.right: today.left
                anchors.rightMargin: Appearance.s.sm
                text: Qt.formatDate(DailyNotes.dateFor(root.day), Locale.LongFormat)
                role: Label.Role.Small
            }

            TextButton {
                id: today
                objectName: "todayNotes"
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Today")
                compact: true
                enabled: root.day !== DailyNotes.today
                onClicked: root.showDay(DailyNotes.today)
            }
        }

        Divider {
            id: divider
            width: parent.width
            anchors.top: dates.bottom
            anchors.topMargin: Appearance.s.md
        }

        Item {
            id: body
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: divider.bottom
            anchors.topMargin: Appearance.s.md
            anchors.bottom: status.top

            ListView {
                id: list
                anchors.fill: parent
                clip: true
                visible: root.draft === null
                boundsBehavior: Flickable.StopAtBounds
                spacing: Appearance.s.xxs

                model: ScriptModel {
                    values: root.notes.map(note => note.id)
                }

                delegate: DailyNoteRow {
                    required property string modelData

                    width: list.width - scroll.footprint
                    note: DailyNotes.find(this.modelData)
                    onEditRequested: id => root.edit(id)
                }
            }
            ThinScrollBar { id: scroll; flickable: list; visible: root.draft === null && scroll.overflowing }

            Label {
                anchors.centerIn: parent
                visible: root.draft === null && root.notes.length === 0 && DailyNotes.error === ""
                role: Label.Role.Small
                muted: true
                text: DailyNotes.ready ? qsTr("No tasks for this day") : qsTr("Loading…")
            }

            Loader {
                width: parent.width
                active: root.draft !== null
                sourceComponent: DailyNoteEditor {
                    draft: root.draft
                    onFinished: {
                        root.draft = null;
                        addTaskButton.forceActiveFocus();
                    }
                }
            }
        }

        Label {
            id: status
            anchors.bottom: parent.bottom
            width: parent.width
            visible: text !== ""
            height: text === "" ? 0 : implicitHeight + Appearance.s.sm
            text: DailyNotes.error
            color: PopupStyle.danger
            role: Label.Role.Small
        }
    }
}
