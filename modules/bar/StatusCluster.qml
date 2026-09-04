pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    The right-hand status group, and the button that opens quick settings.

    Only indicators that mean something on this machine appear: no battery on a
    desktop, no Bluetooth without an adapter, and the microphone and VPN glyphs
    only while they are actually in use.
*/
BarButton {
    id: root

    required property ShellScreen screen

    selected: Overlay.isOpen(Overlay.quickSettings)
    padding: Appearance.s.md

    onClicked: {
        Overlay.anchorX = root.windowCenterX();
        Overlay.toggle(Overlay.quickSettings, root.screen);
    }

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        visible: Network.vpnActive
        name: "vpn"
        size: Appearance.m.icon
        color: Appearance.c.success
    }

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        visible: Audio.micInUse
        name: Audio.micIcon
        size: Appearance.m.icon
        color: Audio.micMuted ? Appearance.c.textMuted : Appearance.c.accent
    }

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        visible: Settings.doNotDisturb
        name: "dnd"
        size: Appearance.m.icon
        color: Appearance.c.textMuted
    }

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        visible: Bt.available && Bt.enabled
        name: Bt.icon
        size: Appearance.m.icon
    }

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        name: Network.icon
        size: Appearance.m.icon
    }

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        name: Audio.volumeIcon
        size: Appearance.m.icon
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        visible: Power.hasBattery
        spacing: Appearance.s.xs

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: Power.icon
            size: Appearance.m.icon
            color: Power.critical ? Appearance.c.danger
                : Power.low ? Appearance.c.warning : Appearance.c.text
        }

        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(Power.percentage) + "%"
            role: Label.Role.Small
            muted: true
        }
    }

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        name: "chevron-down"
        size: Appearance.m.iconSm
        color: Appearance.c.textMuted
    }
}
