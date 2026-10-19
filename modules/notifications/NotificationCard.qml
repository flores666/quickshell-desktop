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
    color: root.standalone ? Appearance.c.chrome : Appearance.c.raised
    radius: root.standalone ? Appearance.r.lg : Appearance.r.md
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

    // Sized by bindings rather than positioners: the body's wrap is only
    // known once the card's width is, and a Column would take that in on the
    // next frame, after the notification centre has placed the row by the
    // height it had (see AGENTS.md). Nor do they read a part's `visible`,
    // which is false while the date menu is closed: every row collapsed then
    // and grew back as it reopened.
    Item {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Appearance.s.lg
        implicitHeight: header.height
            + (root.actionList.length > 0 ? Appearance.s.sm + actions.implicitHeight : 0)

        Item {
            id: header

            width: parent.width
            height: Math.max(picture.height, headline.implicitHeight)

            AppIcon {
                id: picture
                // The card outlives its notification while it fades out.
                source: (root.notification?.image ?? "") !== "" ? root.notification.image
                    : (root.notification?.appIcon ?? "")
                fallbackIcon: root.critical ? "warning" : "bell"
                size: root.standalone ? 32 : 28
            }

            // Centred on the icon when it is the shorter of the two, as a
            // one-line toast is; a longer one hangs from the top beside it.
            Item {
                id: headline

                anchors.verticalCenter: parent.verticalCenter
                x: picture.width + Appearance.s.lg
                width: parent.width - x - closeButton.width - Appearance.s.sm
                implicitHeight: root.bodyText !== "" ? body.y + body.implicitHeight : summary.implicitHeight

                Row {
                    width: parent.width
                    spacing: Appearance.s.sm

                    Label {
                        id: summary
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
                    id: body
                    y: summary.implicitHeight + 1
                    width: parent.width
                    visible: root.bodyText !== ""
                    text: root.bodyText
                    role: Label.Role.Small
                    muted: true
                    wrapMode: Text.Wrap
                    // A toast is a glance: two lines, and the rest is in the
                    // notification centre.
                    maximumLineCount: root.standalone ? 2 : 6
                }
            }

            IconButton {
                id: closeButton
                anchors.right: parent.right
                anchors.verticalCenter: picture.verticalCenter
                icon: "close"
                size: 24
                iconSize: Appearance.m.iconSm
                focusable: false
                onClicked: root.dismissed()
            }
        }

        Row {
            id: actions
            y: header.height + Appearance.s.sm
            visible: root.actionList.length > 0
            width: parent.width
            spacing: Appearance.s.md

            Repeater {
                model: root.actionList

                TextButton {
                    id: actionButton
                    required property NotificationAction modelData

                    // The action is freed with its notification a moment
                    // before the Repeater drops this delegate.
                    text: actionButton.modelData?.text ?? ""
                    implicitHeight: 28

                    onClicked: Notifs.invoke(root.notification, actionButton.modelData)
                }
            }
        }
    }
}
