pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Notifications
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    One notification, used both as a toast and as a row in the notification
    centre.

    Everything shown comes from the application and is treated as untrusted: the
    body is reduced to plain text, both strings are length-capped, and a missing
    or broken image falls back through the app icon to a generic glyph.
*/
Surface {
    id: root

    required property var notification
    /*! Toasts sit on their own; rows in the centre sit on the panel. */
    property bool standalone: false

    readonly property bool critical: Notifs.isCritical(root.notification)
    readonly property string bodyText: Notifs.plainBody(root.notification)
    readonly property var actionList: Notifs.actionsOf(root.notification)

    signal dismissed

    implicitHeight: layout.implicitHeight + Appearance.s.lg * 2
    color: root.standalone ? Appearance.c.surface : Appearance.c.raised
    radius: Appearance.r.md
    elevation: root.standalone ? 3 : 0
    bordered: root.standalone

    Clickable {
        anchors.fill: parent
        radius: root.radius
        focusable: false
        onClicked: Notifs.activate(root.notification)
    }

    Rectangle {
        // A slim urgency marker rather than tinting the whole card.
        visible: root.critical
        x: 0
        y: Appearance.s.lg
        width: 3
        height: parent.height - Appearance.s.lg * 2
        radius: 1.5
        color: Appearance.c.danger
    }

    Column {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Appearance.s.lg
        spacing: Appearance.s.sm

        Item {
            width: parent.width
            height: Math.max(icon.height, headline.implicitHeight)

            AppIcon {
                id: icon
                y: 0
                source: root.notification?.image !== "" ? root.notification.image
                    : (root.notification?.appIcon ?? "")
                fallbackIcon: root.critical ? "warning" : "bell"
                size: 28
            }

            Column {
                id: headline
                x: icon.width + Appearance.s.lg
                width: parent.width - x - closeButton.width - Appearance.s.sm
                spacing: 1

                Row {
                    width: parent.width
                    spacing: Appearance.s.sm

                    Label {
                        width: Math.min(implicitWidth, parent.width - age.implicitWidth - Appearance.s.sm)
                        text: Notifs.summaryOf(root.notification)
                        font.weight: Font.DemiBold
                    }

                    Label {
                        id: age
                        anchors.verticalCenter: parent.verticalCenter
                        text: Notifs.relativeLabel(root.notification, Time.now)
                        role: Label.Role.Caption
                        faint: true
                    }
                }

                Label {
                    width: parent.width
                    visible: root.bodyText !== ""
                    text: root.bodyText
                    role: Label.Role.Small
                    muted: true
                    wrapMode: Text.Wrap
                    maximumLineCount: root.standalone ? 3 : 6
                }
            }

            IconButton {
                id: closeButton
                anchors.right: parent.right
                y: -Appearance.s.xs
                icon: "close"
                size: 24
                iconSize: Appearance.m.iconSm
                focusable: false
                onClicked: root.dismissed()
            }
        }

        Row {
            visible: root.actionList.length > 0
            width: parent.width
            spacing: Appearance.s.md

            Repeater {
                model: root.actionList

                TextButton {
                    id: actionButton
                    required property NotificationAction modelData

                    text: actionButton.modelData.text
                    implicitHeight: 28

                    onClicked: Notifs.invoke(root.notification, actionButton.modelData)
                }
            }
        }
    }
}
