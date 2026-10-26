pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

/*! Notifications: whether they are shown at all, and for how long. The range
    here belongs to Notifs, which clamps what lands in settings.json the same
    way. */
Column {
    id: root

    spacing: Appearance.s.md

    SettingGroup {
        width: root.width

        MenuRow {
            width: parent.width
            title: qsTr("Do Not Disturb")
            flush: true
            subtitle: qsTr("Hold notifications in history without showing them")
            icon: "dnd"
            onClicked: Settings.setDoNotDisturb(!Settings.doNotDisturb)

            ToggleSwitch {
                checked: Settings.doNotDisturb
                onToggled: value => Settings.setDoNotDisturb(value)
            }
        }

        SettingRow {
            width: parent.width
            key: "notificationTimeout"
            label: qsTr("Dwell")
            min: Notifs.timeoutRange.min
            max: Notifs.timeoutRange.max
            step: 500
            value: Notifs.defaultTimeout
            suffix: qsTr("ms")
        }
    }
}
