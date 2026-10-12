pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.UPower
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    The power-profiles-daemon profile, as a row of choices: one button per
    profile, the one in force wearing the accent the way an engaged tile does.
*/
Item {
    id: root

    readonly property var options: Power.hasPerformance
        ? [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance]
        : [PowerProfile.PowerSaver, PowerProfile.Balanced]

    implicitWidth: 300
    implicitHeight: 36

    Row {
        anchors.fill: parent
        spacing: Appearance.s.sm

        Repeater {
            model: root.options

            Clickable {
                id: seg
                required property int modelData

                readonly property bool current: Power.profile === seg.modelData

                width: (root.width - Appearance.s.sm * (root.options.length - 1)) / root.options.length
                height: parent.height
                radius: Appearance.r.md
                background: seg.current ? Appearance.c.accentSoft : Appearance.c.raised
                onClicked: Power.setProfile(seg.modelData)

                Behavior on background {
                    ColorAnimation { duration: Appearance.t.fast; easing.type: Appearance.t.standardEasing }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: Appearance.s.sm

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: Power.profileIcon(seg.modelData)
                        size: Appearance.m.iconSm
                        color: seg.current ? Appearance.c.accent : Appearance.c.textMuted
                    }

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Power.profileLabel(seg.modelData)
                        role: Label.Role.Caption
                        color: seg.current ? Appearance.c.text : Appearance.c.textMuted
                        font.weight: seg.current ? Font.DemiBold : Font.Normal
                    }
                }
            }
        }
    }
}
