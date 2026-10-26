pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"
import "root:/modules/common"

/*!
    The VPN menu, opened from the bar: each NetworkManager connection the
    user listed, and v2rayN's active server, each with a switch (v2rayN's
    only in TUN mode). Each row says how long its VPN took to answer.
*/
ShellOverlay {
    id: root

    overlayId: Overlay.vpnMenu
    cardHeight: column.implicitHeight + Appearance.s.md * 2

    // Latency has no event of its own: every row is measured as the menu
    // opens, which is when it is read.
    onShownChanged: {
        if (root.shown) {
            Vpn.measure();
            V2rayn.measure();
        }
    }

    Column {
        id: column

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Appearance.s.md
        spacing: 1

        Repeater {
            // Names, so a row keeps its delegate (and its hover) while the
            // connection's state and latency change under it.
            model: ScriptModel { values: Vpn.connections }

            MenuRow {
                id: row

                required property string modelData

                width: column.width
                icon: "vpn"
                iconColor: Vpn.isActive(row.modelData) ? Appearance.c.success : Appearance.c.text
                title: row.modelData
                subtitle: Vpn.status(row.modelData)
                // Vpn ignores a switch asked for while one is under way; the
                // status line says so, rather than a dimmed row.
                onClicked: Vpn.toggle(row.modelData)

                ToggleSwitch {
                    // On from the moment it is asked to connect; the status
                    // line says how far it has got.
                    checked: Vpn.isActive(row.modelData) || Vpn.states[row.modelData] === "activating"
                    onToggled: Vpn.toggle(row.modelData)
                }
            }
        }

        MenuRow {
            width: column.width
            visible: V2rayn.available
            icon: "vpn"
            iconColor: V2rayn.active ? Appearance.c.success : Appearance.c.text
            title: "v2rayN"
            subtitle: V2rayn.status
            // Without TUN mode there is no switch to reach, and the row
            // only reports; v2rayN is switched in its own window then.
            hoverEnabled: V2rayn.canSwitch
            pressEnabled: V2rayn.canSwitch
            focusable: V2rayn.canSwitch
            onClicked: V2rayn.toggle()

            ToggleSwitch {
                visible: V2rayn.canSwitch
                checked: !V2rayn.direct
                onToggled: V2rayn.toggle()
            }
        }
    }
}
