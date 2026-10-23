pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    The right-hand status group, and the button that opens quick settings.

    Only indicators that mean something on this machine appear: no battery on a
    desktop, no Bluetooth without an adapter, and the microphone glyph only
    while it is actually in use. VPNs have a button of their own (VpnButton).
*/
BarButton {
    id: root

    required property ShellScreen screen

    selected: Overlay.isOpen(Overlay.quickSettings)
    padding: Appearance.s.md

    onClicked: {
        Overlay.toggle(Overlay.quickSettings, root.screen, root.windowCenterX());
    }

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        visible: Audio.micInUse
        name: Audio.micIcon
        size: Appearance.m.iconSm
        color: Audio.micMuted ? root.scheme.textMuted : root.scheme.accent
    }

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        visible: Settings.doNotDisturb
        name: "dnd"
        size: Appearance.m.iconSm
        color: root.scheme.textMuted
    }

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        visible: Bt.available && Bt.enabled
        name: Bt.icon
        size: Appearance.m.iconSm
        color: root.scheme.text
    }

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        name: Network.icon
        size: Appearance.m.iconSm
        color: root.scheme.text
    }

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        name: Audio.volumeIcon
        size: Appearance.m.iconSm
        color: root.scheme.text
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        visible: Power.hasBattery
        spacing: Appearance.s.xs

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: Power.icon
            size: Appearance.m.iconSm
            color: Power.critical ? root.scheme.danger
                : Power.low ? root.scheme.warning : root.scheme.text
        }

        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(Power.percentage) + "%"
            role: Label.Role.Small
            muted: true
            scheme: root.scheme
        }
    }
}
