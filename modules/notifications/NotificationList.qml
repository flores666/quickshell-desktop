pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"

/*! The notification centre: everything received this session, newest first. */
Item {
    id: root

    implicitHeight: 320

    Item {
        id: heading
        width: parent.width
        height: 32

        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("Notifications")
            role: Label.Role.Subtitle
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.s.xs

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "dnd"
                size: 28
                iconSize: Appearance.m.iconSm
                accented: Settings.doNotDisturb
                onClicked: Settings.setDoNotDisturb(!Settings.doNotDisturb)
            }

            TextButton {
                anchors.verticalCenter: parent.verticalCenter
                compact: true
                text: qsTr("Clear all")
                icon: "trash"
                enabled: Notifs.count > 0
                onClicked: Notifs.clearAll()
            }
        }
    }

    ListView {
        id: list

        anchors.top: heading.bottom
        anchors.topMargin: Appearance.s.md
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        spacing: Appearance.s.md
        // Diffed, so a new arrival inserts a row instead of rebuilding them all.
        model: ScriptModel { values: Notifs.history }
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: 0

        delegate: NotificationCard {
            required property var modelData

            width: list.width
            notification: this.modelData
            onDismissed: Notifs.remove(this.modelData)
        }

        add: Transition {
            NumberAnimation {
                property: "opacity"; from: 0; to: 1
                duration: Appearance.t.base
                easing.type: Appearance.t.standardEasing
            }
        }
        remove: Transition {
            NumberAnimation {
                property: "opacity"; to: 0
                duration: Appearance.t.fast
                easing.type: Appearance.t.standardEasing
            }
        }
        displaced: Transition {
            NumberAnimation {
                properties: "y"
                duration: Appearance.t.base
                easing.type: Appearance.t.standardEasing
            }
            // A row displaced while it is still fading in has its add
            // transition cut short, and would stay as faint as it had got:
            // in a burst, every row but the newest stayed invisible.
            NumberAnimation {
                property: "opacity"; to: 1
                duration: Appearance.t.base
                easing.type: Appearance.t.standardEasing
            }
        }
    }

    Column {
        anchors.centerIn: list
        spacing: Appearance.s.md
        visible: Notifs.count === 0

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: Settings.doNotDisturb ? "dnd" : "bell"
            size: 28
            color: Appearance.c.textFaint
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Settings.doNotDisturb ? qsTr("Do Not Disturb is on") : qsTr("No Notifications")
            faint: true
        }
    }

    ThinScrollBar { flickable: list }
}
