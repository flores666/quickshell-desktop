pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Networking
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    Wi-Fi networks in range.

    Scanning is switched on only while this page is on screen, so the radio is
    not kept busy by a panel nobody is looking at.
*/
Item {
    id: root


    /*! Set when a network needs a passphrase we do not already have. */
    property WifiNetwork pending: null

    implicitHeight: root.pending
        ? prompt.implicitHeight
        : Math.min(340, header.height + list.contentHeight + Appearance.s.md)

    Component.onCompleted: Network.setScanning(true)
    Component.onDestruction: Network.setScanning(false)

    Connections {
        target: Network
        function onPasswordRequested(network: WifiNetwork): void {
            root.pending = network;
            psk.text = "";
            Qt.callLater(() => psk.forceActiveFocus());
        }
    }

    Column {
        id: prompt

        width: parent.width
        visible: root.pending !== null
        spacing: Appearance.s.lg

        Label {
            width: parent.width
            text: qsTr("Enter the password for “%1”").arg(root.pending?.name ?? "")
            role: Label.Role.Small
            muted: true
            wrapMode: Text.Wrap
        }

        Item {
            width: parent.width
            height: Appearance.m.fieldHeight

            Rectangle {
                anchors.fill: parent
                radius: Appearance.r.sm
                color: Appearance.c.sunken
                border.width: 1
                border.color: psk.activeFocus ? Appearance.c.accent : Appearance.c.border
            }

            TextInput {
                id: psk

                anchors.fill: parent
                anchors.leftMargin: Appearance.s.lg
                anchors.rightMargin: Appearance.s.lg
                verticalAlignment: TextInput.AlignVCenter
                echoMode: reveal.selected ? TextInput.Normal : TextInput.Password
                passwordCharacter: "•"
                color: Appearance.c.text
                font.family: Appearance.fontFamily
                font.pixelSize: Appearance.font.body
                selectionColor: Appearance.c.accent
                selectedTextColor: Appearance.c.accentText
                clip: true
                renderType: Text.NativeRendering
                onAccepted: root.confirm()
            }
        }

        Row {
            width: parent.width
            spacing: Appearance.s.md

            IconButton {
                id: reveal
                icon: reveal.selected ? "conceal" : "reveal"
                size: 34
                selected: false
                onClicked: reveal.selected = !reveal.selected
            }

            Item {
                width: parent.width - reveal.width - cancel.width - connect.width - parent.spacing * 3
                height: 1
            }

            TextButton {
                id: cancel
                text: qsTr("Cancel")
                onClicked: root.pending = null
            }

            TextButton {
                id: connect
                text: qsTr("Connect")
                kind: TextButton.Kind.Accent
                enabled: psk.text.length >= 8
                onClicked: root.confirm()
            }
        }
    }

    function confirm(): void {
        if (!root.pending || psk.text.length < 8)
            return;
        Network.connectWithPassword(root.pending, psk.text);
        root.pending = null;
        psk.text = "";
    }

    Row {
        id: header
        width: parent.width
        height: 40
        visible: root.pending === null
        spacing: Appearance.s.md

        Label {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - toggle.width - parent.spacing
            text: Network.wifiEnabled ? qsTr("Available networks") : qsTr("Wi-Fi is off")
            role: Label.Role.Small
            muted: true
        }

        ToggleSwitch {
            id: toggle
            anchors.verticalCenter: parent.verticalCenter
            checked: Network.wifiEnabled
            enabled: Network.wifiHardwareEnabled
            onToggled: v => Network.setWifiEnabled(v)
        }
    }

    ListView {
        id: list

        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        visible: root.pending === null
        model: Network.wifiEnabled && root.pending === null ? Network.wifiNetworks : []
        spacing: 1
        boundsBehavior: Flickable.StopAtBounds

        delegate: MenuRow {
            id: netRow
            required property WifiNetwork modelData

            width: list.width
            icon: Network.signalIcon(netRow.modelData.signalStrength)
            iconColor: netRow.modelData.connected ? Appearance.c.accent : Appearance.c.text
            title: netRow.modelData.name
            subtitle: netRow.modelData.connected ? qsTr("Connected")
                : netRow.modelData.stateChanging ? qsTr("Connecting…")
                : netRow.modelData.known ? qsTr("Saved") : ""
            selected: netRow.modelData.connected

            onClicked: {
                if (netRow.modelData.connected)
                    Network.disconnect(netRow.modelData);
                else
                    Network.connect(netRow.modelData);
            }

            Icon {
                visible: netRow.modelData.security !== WifiSecurityType.Open
                    && !netRow.modelData.connected
                name: "wifi-locked"
                size: Appearance.m.iconSm
                color: Appearance.c.textFaint
            }
        }
    }

    Label {
        anchors.centerIn: parent
        visible: root.pending === null && Network.wifiEnabled && Network.wifiNetworks.length === 0
        text: qsTr("Searching…")
        muted: true
    }

    ThinScrollBar { flickable: list; visible: root.pending === null && overflowing }
}
