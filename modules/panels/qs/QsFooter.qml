pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

Item {
    id: root
    signal profileRequested
    signal powerRequested
    implicitHeight: Math.max(Appearance.m.touchTarget, battery.implicitHeight)

    Row {
        id: battery
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(0, actions.x - Appearance.s.sm)
        visible: Power.hasBattery
        spacing: Appearance.s.sm
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: Power.icon
            size: Appearance.m.icon
            color: Power.critical ? PopupStyle.danger : Appearance.c.text
        }
        Label {
            width: battery.width - Appearance.m.icon - battery.spacing
            readonly property string detail: Power.limitLabel || Power.timeLabel
            text: this.detail !== ""
                ? qsTr("%1% · %2").arg(Math.round(Power.percentage)).arg(this.detail)
                : qsTr("%1%").arg(Math.round(Power.percentage))
            role: Label.Role.Small
            color: PopupStyle.muted
            wrapMode: Text.Wrap
        }
    }
    Row {
        id: actions
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Appearance.s.xs
        QsIconButton {
            objectName: "profile"
            enabled: Power.hasProfiles
            icon: Power.profileIcon(Power.profile)
            label: qsTr("Power profile")
            Accessible.description: Power.hasProfiles ? Power.profileLabel(Power.profile) : qsTr("Unavailable")
            onClicked: root.profileRequested()
        }
        QsIconButton {
            objectName: "settings"
            icon: "settings"
            label: qsTr("Settings")
            onClicked: Overlay.openUnanchored(Overlay.settings)
        }
        QsIconButton {
            objectName: "power"
            icon: "shutdown"
            label: qsTr("Power")
            onClicked: root.powerRequested()
        }
    }
}
