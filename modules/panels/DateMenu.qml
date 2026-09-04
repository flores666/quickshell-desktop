pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"
import "root:/modules/common"
import "root:/modules/notifications"

/*!
    The centre panel, opened from the clock: media controls, the notification
    centre, and a month view — the three things a clock click is expected to
    reach on a GNOME-style desktop.
*/
ShellOverlay {
    id: root

    overlayId: Overlay.dateMenu
    cardWidth: 660
    cardHeight: 420

    Row {
        anchors.fill: parent
        anchors.margins: Appearance.s.lg
        spacing: Appearance.s.lg

        Column {
            id: left

            width: 352
            height: parent.height
            spacing: Appearance.s.lg

            MediaCard {
                id: media
                width: parent.width
                tracking: root.shown
            }

            NotificationList {
                width: parent.width
                // The column has a fixed height, so this cannot feed back.
                implicitHeight: left.height
                    - (media.visible ? media.height + left.spacing : 0)
            }
        }

        Divider {
            vertical: true
            height: parent.height
        }

        Column {
            width: parent.width - left.width - Appearance.s.lg * 2 - 1
            height: parent.height
            spacing: Appearance.s.lg

            Label {
                width: parent.width
                text: Time.dateLong
                role: Label.Role.Subtitle
                horizontalAlignment: Text.AlignHCenter
            }

            Calendar {
                width: parent.width
            }
        }
    }
}
