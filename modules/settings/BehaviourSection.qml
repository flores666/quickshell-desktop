pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

/*! How long things wait. The ranges here belong to the services that act on
    them, which clamp what lands in settings.json the same way. */
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
        label: qsTr("Notification dwell")
        min: 1500
        max: 30000
        step: 500
        value: Notifs.defaultTimeout
        suffix: qsTr("ms")
    }

    SettingRow {
        width: root.width
        key: "dockHideDelay"
        label: qsTr("Dock hide delay")
        min: 0
        max: 3000
        step: 100
        value: Dock.hideDelay
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
