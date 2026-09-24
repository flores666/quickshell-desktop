pragma ComponentBehavior: Bound

import QtQuick
// Qualified: Quickshell.Networking has its own `Network` type, which would
// shadow the Network service everywhere in this file.
import Quickshell.Networking as QsNet
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    Wi-Fi networks in range: join one, leave it, and for a saved one change
    its password or forget it.

    Scanning is switched on only while this page is on screen, so the radio is
    not kept busy by a panel nobody is looking at.
*/
Item {
    id: root

    /*! The network the password prompt is for; null while it is not shown. */
    property QsNet.WifiNetwork pending: null
    property bool changing: false
    /*! The saved network whose actions are open, by name. */
    property string expanded: ""

    function ask(network: QsNet.WifiNetwork, changing: bool, reason: string): void {
        root.pending = network;
        root.changing = changing;
        prompt.reason = reason;
        prompt.open();
    }

    implicitHeight: root.pending
        ? prompt.implicitHeight
        : Math.min(340, header.height + failure.height + list.contentHeight + Appearance.s.md)

    Component.onCompleted: Network.setScanning(true)
    Component.onDestruction: Network.setScanning(false)

    Connections {
        target: Network
        function onPasswordRequested(network: QsNet.WifiNetwork, reason: string): void {
            root.ask(network, false, reason);
        }
    }

    WifiPasswordPrompt {
        id: prompt

        width: parent.width
        visible: root.pending !== null
        networkName: root.pending?.name ?? ""
        changing: root.changing

        onCancelled: root.pending = null
        onAccepted: psk => {
            if (root.changing)
                Network.changePassword(root.pending, psk);
            else
                Network.connectWithPassword(root.pending, psk);
            root.pending = null;
            root.expanded = "";
        }
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

    Label {
        id: failure
        anchors.top: header.bottom
        width: parent.width
        height: visible ? implicitHeight + Appearance.s.sm : 0
        visible: root.pending === null && Network.failure !== ""
        text: Network.failure
        role: Label.Role.Small
        color: Appearance.c.danger
        wrapMode: Text.Wrap
    }

    ListView {
        id: list

        anchors.top: failure.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        visible: root.pending === null
        model: Network.wifiEnabled && root.pending === null ? Network.wifiNetworks : []
        spacing: 1
        boundsBehavior: Flickable.StopAtBounds

        delegate: Column {
            id: net
            required property QsNet.WifiNetwork modelData

            readonly property bool secured: net.modelData.security !== QsNet.WifiSecurityType.Open
            readonly property bool open: root.expanded === net.modelData.name && net.modelData.known
            property bool confirmingForget: false

            // Clear of the scrollbar, which floats over the list's trailing
            // edge, so a row's highlight never runs underneath it.
            width: list.width - (scrollbar.overflowing ? scrollbar.footprint : 0)
            onOpenChanged: net.confirmingForget = false

            MenuRow {
                width: parent.width
                icon: Network.signalIcon(net.modelData.signalStrength)
                iconColor: net.modelData.connected ? Appearance.c.accent : Appearance.c.text
                title: net.modelData.name
                subtitle: net.modelData.connected ? qsTr("Connected")
                    : net.modelData.stateChanging ? qsTr("Connecting…")
                    : net.modelData.known ? qsTr("Saved") : ""
                selected: net.modelData.connected

                onClicked: {
                    if (net.modelData.connected)
                        Network.disconnect(net.modelData);
                    else
                        Network.connect(net.modelData);
                }

                Row {
                    spacing: Appearance.s.xs

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: net.secured && !net.modelData.connected
                        name: "wifi-locked"
                        size: Appearance.m.iconSm
                        color: Appearance.c.textFaint
                    }

                    IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: net.modelData.known
                        icon: "more"
                        iconSize: Appearance.m.iconSm
                        size: 28
                        selected: net.open
                        onClicked: root.expanded = net.open ? "" : net.modelData.name
                    }
                }
            }

            // Set off from the row above and the network below, and lined up
            // with the row's icon.
            Item {
                visible: net.open
                width: parent.width
                height: visible ? actions.implicitHeight + Appearance.s.sm + Appearance.s.md : 0

                Row {
                    id: actions
                    x: Appearance.s.lg
                    y: Appearance.s.sm
                    spacing: Appearance.s.sm

                    TextButton {
                        visible: net.secured
                        compact: true
                        text: qsTr("Change password")
                        onClicked: root.ask(net.modelData, true, "")
                    }

                    // Forgetting throws the saved password away, so it takes a
                    // second click to mean it.
                    TextButton {
                        compact: true
                        text: net.confirmingForget ? qsTr("Forget “%1”?").arg(net.modelData.name) : qsTr("Forget")
                        kind: TextButton.Kind.Danger
                        onClicked: {
                            if (!net.confirmingForget) {
                                net.confirmingForget = true;
                                return;
                            }
                            Network.forget(net.modelData);
                            root.expanded = "";
                        }
                    }
                }
            }
        }
    }

    Label {
        anchors.centerIn: parent
        visible: root.pending === null && Network.wifiEnabled && Network.wifiNetworks.length === 0
        text: qsTr("Searching…")
        muted: true
    }

    ThinScrollBar { id: scrollbar; flickable: list; visible: root.pending === null && overflowing }
}
