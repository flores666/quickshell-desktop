pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.UPower
import "root:/config"
import "root:/components"
import "root:/services"

/*! A three-way segmented control for the power-profiles-daemon profile. */
Item {
    id: root

    readonly property var options: Power.hasPerformance
        ? [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance]
        : [PowerProfile.PowerSaver, PowerProfile.Balanced]

    implicitWidth: 300
    implicitHeight: 34

    Rectangle {
        anchors.fill: parent
        radius: Appearance.r.sm
        color: Appearance.c.sunken
    }

    Row {
        anchors.fill: parent
        anchors.margins: 3

        Repeater {
            model: root.options

            Clickable {
                id: seg
                required property int modelData

                readonly property bool current: Power.profile === seg.modelData

                width: (root.width - 6) / root.options.length
                height: parent.height
                radius: Appearance.r.xs
                background: seg.current ? Appearance.c.surface : "transparent"
                onClicked: Power.setProfile(seg.modelData)

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
                    }
                }
            }
        }
    }
}
