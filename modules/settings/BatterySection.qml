pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

/*! The battery: whether it charges all the way. Listed only where UPower can
    hold it short of full (Power.hasChargeLimit); the choice is UPower's, kept
    across reboots, not the shell's. */
Column {
    id: root

    spacing: Appearance.s.md

    SettingGroup {
        width: root.width

        MenuRow {
            width: parent.width
            flush: true
            title: qsTr("Limit charging")
            // Where the firmware picks the level, the kernel does not say it.
            subtitle: Power.chargeLimit > 0
                ? qsTr("Stop at %1% to extend battery life").arg(Power.chargeLimit)
                : qsTr("Stop below full, usually at 80%, to extend battery life")
            onClicked: Power.setChargeLimited(!Power.chargeLimited)

            ToggleSwitch {
                checked: Power.chargeLimited
                onToggled: value => Power.setChargeLimited(value)
            }
        }
    }
}
