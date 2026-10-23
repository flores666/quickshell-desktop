pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    Opens the VPN menu. Present only while there is a VPN to offer, and lit
    while one of them is up.
*/
BarButton {
    id: root

    required property ShellScreen screen

    visible: Vpn.available
    selected: Overlay.isOpen(Overlay.vpnMenu)
    padding: Appearance.s.md

    onClicked: {
        Overlay.anchorX = root.windowCenterX();
        Overlay.toggle(Overlay.vpnMenu, root.screen);
    }

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        name: "vpn"
        size: Appearance.m.iconSm
        color: Vpn.anyActive ? root.scheme.success : root.scheme.textMuted
    }
}
