pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Bluetooth
import "root:/config"
import "root:/components"
import "root:/services"

/*! Paired and nearby Bluetooth devices. Discovery runs only while visible. */
Item {
    id: root


    implicitHeight: Math.min(340, header.height + list.contentHeight + Appearance.s.md)

    Component.onCompleted: Bt.setDiscovering(true)
    Component.onDestruction: Bt.setDiscovering(false)

    Row {
        id: header
        width: parent.width
        height: 40
        spacing: Appearance.s.md

        Label {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - toggle.width - spinner.width - parent.spacing * 2
            text: Bt.enabled ? qsTr("Devices") : qsTr("Bluetooth is off")
            role: Label.Role.Small
            muted: true
        }

        Spinner {
            id: spinner
            anchors.verticalCenter: parent.verticalCenter
            visible: Bt.discovering
            size: Appearance.m.iconSm
        }

        ToggleSwitch {
            id: toggle
            anchors.verticalCenter: parent.verticalCenter
            checked: Bt.enabled
            enabled: !Bt.blocked && !Bt.busy
            onToggled: v => Bt.setEnabled(v)
        }
    }

    ListView {
        id: list

        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        model: Bt.enabled ? Bt.listed : []
        spacing: 1
        boundsBehavior: Flickable.StopAtBounds

        delegate: MenuRow {
            id: btRow
            required property BluetoothDevice modelData

            width: list.width
            icon: Bt.deviceIcon(btRow.modelData)
            iconColor: btRow.modelData.connected ? Appearance.c.accent : Appearance.c.text
            title: Bt.deviceName(btRow.modelData)
            subtitle: btRow.modelData.pairing ? qsTr("Pairing…")
                : btRow.modelData.state === BluetoothDeviceState.Connecting ? qsTr("Connecting…")
                : btRow.modelData.connected
                    ? (btRow.modelData.batteryAvailable
                        ? qsTr("Connected · %1%").arg(Math.round(btRow.modelData.battery * 100))
                        : qsTr("Connected"))
                : btRow.modelData.paired ? qsTr("Paired") : ""
            selected: btRow.modelData.connected

            onClicked: Bt.toggleConnection(btRow.modelData)
        }
    }

    Label {
        anchors.centerIn: parent
        visible: Bt.enabled && Bt.listed.length === 0
        text: qsTr("Searching…")
        muted: true
    }

    ThinScrollBar { flickable: list }
}
