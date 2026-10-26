pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"
import "root:/modules/common"
import "root:/modules/notifications"

/*!
    The centre panel, opened from the clock: media controls, the notification
    centre, and a month view — the three things a clock click is expected to
    reach on a GNOME-style desktop — and under the month how busy the CPU and
    memory are, read only while it is open (UsageCards).
*/
ShellOverlay {
    id: root

    overlayId: Overlay.dateMenu
    cardWidth: 660
    // 420, or what the calendar column needs: the date, the month and the usage cards.
    cardHeight: Math.max(420, dateLabel.implicitHeight + calendar.implicitHeight + usage.implicitHeight
        + rightColumn.spacing * 2 + Appearance.s.lg * 2)

    Row {
        anchors.fill: parent
        anchors.margins: Appearance.s.lg
        spacing: Appearance.s.lg

        Column {
            id: leftColumn

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
                implicitHeight: leftColumn.height
                    - (media.visible ? media.height + leftColumn.spacing : 0)
            }
        }

        Divider {
            vertical: true
            height: parent.height
        }

        Column {
            id: rightColumn

            width: parent.width - leftColumn.width - Appearance.s.lg * 2 - 1
            height: parent.height
            spacing: Appearance.s.lg

            Label {
                id: dateLabel

                width: parent.width
                text: Time.dateLong
                role: Label.Role.Subtitle
                horizontalAlignment: Text.AlignHCenter
            }

            Calendar {
                id: calendar
                width: parent.width
            }

            UsageCards {
                id: usage
                width: parent.width
                tracking: root.shown
            }
        }
    }
}
