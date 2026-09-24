pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    Quick settings' front page: the controls that get used constantly.

    Anything that needs a list is a sub-page, asked for by name through
    `pageRequested`; QuickSettings owns the navigation.
*/
Column {
    id: root

    /*! One of QuickSettings' page names. */
    signal pageRequested(string page)

    spacing: Appearance.s.lg

    Grid {
        width: parent.width
        columns: 2
        columnSpacing: Appearance.s.md
        rowSpacing: Appearance.s.md

        // Controls with nothing behind them are disabled, not removed,
        // so this layout never shifts (the bar still hides them). A
        // wired-only machine shows its wired tile in this slot instead.
        QsTile {
            width: (root.width - Appearance.s.md) / 2
            visible: Network.hasWifi || !Network.hasWired
            enabled: Network.hasWifi
            icon: Network.hasWifi ? Network.icon : "wifi-off"
            title: qsTr("Wi-Fi")
            status: !Network.hasWifi ? qsTr("Unavailable")
                : Network.wifiEnabled ? Network.label : qsTr("Off")
            active: Network.wifiEnabled
            busy: Network.wifiConnecting
            hasPage: Network.hasWifi
            toggleEnabled: Network.wifiHardwareEnabled
            onToggled: Network.setWifiEnabled(!Network.wifiEnabled)
            onPageRequested: root.pageRequested("wifi")
        }

        QsTile {
            width: (root.width - Appearance.s.md) / 2
            visible: !Network.hasWifi && Network.hasWired
            icon: Network.icon
            title: qsTr("Network")
            status: Network.label
            active: Network.wiredConnected
            toggleEnabled: false
        }

        QsTile {
            width: (root.width - Appearance.s.md) / 2
            enabled: Bt.available
            icon: Bt.available ? Bt.icon : "bluetooth-off"
            title: qsTr("Bluetooth")
            status: Bt.available ? Bt.label : qsTr("Unavailable")
            active: Bt.enabled
            busy: Bt.busy
            hasPage: Bt.available
            toggleEnabled: !Bt.blocked
            onToggled: Bt.setEnabled(!Bt.enabled)
            onPageRequested: root.pageRequested("bluetooth")
        }

        QsTile {
            width: (root.width - Appearance.s.md) / 2
            icon: "dnd"
            title: qsTr("Do Not Disturb")
            status: Settings.doNotDisturb ? qsTr("On") : qsTr("Off")
            active: Settings.doNotDisturb
            onToggled: Settings.setDoNotDisturb(!Settings.doNotDisturb)
        }

        QsTile {
            width: (root.width - Appearance.s.md) / 2
            icon: Settings.effectiveDark ? "night-light" : "brightness"
            title: qsTr("Dark Style")
            status: Settings.effectiveDark ? qsTr("On") : qsTr("Off")
            active: Settings.effectiveDark
            hasPage: true
            onToggled: Settings.toggleTheme()
            onPageRequested: root.pageRequested("colors")
        }
    }

    Column {
        width: parent.width
        spacing: Appearance.s.sm

        QsSliderRow {
            width: parent.width
            enabled: Audio.hasSink
            icon: Audio.volumeIcon
            value: Audio.volume
            muted: Audio.muted
            toggleEnabled: true
            hasPage: Audio.sinks.length > 1
            onMoved: v => {
                if (Audio.muted && v > 0)
                    Audio.toggleMute();
                Audio.setVolume(v);
            }
            onIconClicked: Audio.toggleMute()
            onPageRequested: root.pageRequested("output")
        }

        QsSliderRow {
            width: parent.width
            enabled: Audio.hasSource
            icon: Audio.micIcon
            value: Audio.micVolume
            muted: Audio.micMuted
            toggleEnabled: true
            hasPage: Audio.sources.length > 1
            onMoved: v => Audio.setMicVolume(v)
            onIconClicked: Audio.toggleMicMute()
            onPageRequested: root.pageRequested("input")
        }

        QsSliderRow {
            width: parent.width
            enabled: Brightness.available
            icon: Brightness.icon
            value: Brightness.value
            onMoved: v => Brightness.set(v)
        }
    }

    PowerProfileRow {
        width: parent.width
        enabled: Power.hasProfiles
    }

    Divider { width: parent.width }

    Item {
        width: parent.width
        height: 34

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.s.sm

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: Power.hasBattery ? Power.icon : "battery-missing"
                size: Appearance.m.icon
                color: !Power.hasBattery ? Appearance.c.textDisabled
                    : Power.critical ? Appearance.c.danger : Appearance.c.text
            }

            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: !Power.hasBattery ? qsTr("No battery")
                    : Power.timeLabel !== ""
                    ? qsTr("%1% · %2").arg(Math.round(Power.percentage)).arg(Power.timeLabel)
                    : qsTr("%1%").arg(Math.round(Power.percentage))
                role: Label.Role.Small
                muted: true
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.s.xs

            IconButton {
                icon: "settings"
                onClicked: {
                    Overlay.close();
                    Overlay.openUnanchored(Overlay.settings);
                }
            }

            IconButton {
                icon: "lock"
                onClicked: {
                    Overlay.close();
                    Session.lock();
                }
            }

            IconButton {
                icon: "shutdown"
                onClicked: root.pageRequested("power")
            }
        }
    }
}
