pragma ComponentBehavior: Bound

import QtQuick
import "root:/components"
import "root:/services"

SettingGroup {
    id: root

    title: qsTr("Dock")

    MenuRow {
        width: parent.width
        flush: true
        icon: "calendar"
        title: qsTr("Daily Notes")
        subtitle: qsTr("Keep a daily checklist and drag its widget to rearrange the Dock.")
        enabled: Settings.ready
        onClicked: Settings.setDailyNotesEnabled(!Settings.dailyNotesEnabled)

        ToggleSwitch {
            checked: Settings.dailyNotesEnabled
            onToggled: value => Settings.setDailyNotesEnabled(value)
        }
    }
}
