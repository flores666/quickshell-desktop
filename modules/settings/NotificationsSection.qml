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

    spacing: Appearance.s.lg

    MenuRow {
        width: root.width
        title: qsTr("Do Not Disturb")
        subtitle: qsTr("Hold notifications in history without showing them")
        icon: "dnd"
        onClicked: Settings.setDoNotDisturb(!Settings.doNotDisturb)

        ToggleSwitch {
            anchors.verticalCenter: parent.verticalCenter
            checked: Settings.doNotDisturb
            onToggled: value => Settings.setDoNotDisturb(value)
        }
    }

    SettingRow {
        width: root.width
        key: "notificationTimeout"
        label: qsTr("Dwell")
        min: 1500
        max: 30000
        step: 500
        value: Notifs.defaultTimeout
        suffix: qsTr("ms")
    }

    Label {
        width: root.width
        text: qsTr("Urgent notifications ignore the dwell and wait to be dismissed.")
        role: Label.Role.Caption
        faint: true
        wrapMode: Text.Wrap
    }
}
