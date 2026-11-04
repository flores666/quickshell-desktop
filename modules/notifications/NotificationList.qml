pragma ComponentBehavior: Bound

import QtQuick
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

    Flickable {
        id: list

        anchors.top: heading.bottom
        anchors.topMargin: Appearance.s.md
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        contentHeight: stack.height
        boundsBehavior: Flickable.StopAtBounds
        // The extent follows the moving bottom row, so this clamp progresses
        // with its animation rather than snapping to the new layout height.
        function clampScroll(): void {
            contentY = Math.max(0, Math.min(contentY, Math.max(0, contentHeight - height)));
        }
        onContentHeightChanged: list.clampScroll()
        onHeightChanged: list.clampScroll()

        NotificationStack {
            id: stack
            // Always keep the scrollbar's footprint, so rows never rewrap
            // just because an arrival or removal makes scrolling necessary.
            width: list.width - scrollbar.footprint
            notifications: Notifs.history
            viewportY: list.contentY
            viewportHeight: list.height
        }
    }

    Column {
        anchors.centerIn: list
        spacing: Appearance.s.md
        visible: stack.shown.length === 0

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

    ThinScrollBar { id: scrollbar; flickable: list }
}
