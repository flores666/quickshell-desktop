pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

/*! A quick toggle and a warmer-to-the-right scale on the Colors sub-page. */
Rectangle {
    id: root

    implicitHeight: content.implicitHeight + Appearance.s.md * 2
    radius: Appearance.r.lg
    color: Appearance.c.raised

    Column {
        id: content
        x: Appearance.s.md
        y: Appearance.s.md
        width: parent.width - Appearance.s.md * 2
        spacing: Appearance.s.xs

        MenuRow {
            width: parent.width
            flush: true
            enabled: NightLight.available
            icon: "night-light"
            iconColor: NightLight.enabled ? PopupStyle.warning : Appearance.c.text
            title: qsTr("Night Light")
            subtitle: NightLight.starting ? qsTr("Starting…")
                : !NightLight.available ? qsTr("Unavailable")
                : NightLight.enabled ? qsTr("Screen temperature · %1 K").arg(NightLight.temperature)
                : qsTr("Off")
            onClicked: NightLight.setEnabled(!NightLight.enabled)
            Accessible.name: title
            Accessible.description: subtitle

            ToggleSwitch {
                checked: NightLight.available && NightLight.enabled
                onToggled: on => NightLight.setEnabled(on)
                Accessible.name: qsTr("Night Light")
            }
        }

        Slider {
            width: parent.width
            enabled: NightLight.available && NightLight.enabled
            value: NightLight.warmth
            stepSize: NightLight.step / (NightLight.maximum - NightLight.minimum)
            fillColor: PopupStyle.warning
            onMoved: value => NightLight.setWarmth(value)
            Accessible.name: qsTr("Screen temperature")
            Accessible.description: qsTr("%1 K. Move right for a warmer screen.").arg(NightLight.temperature)
        }

        Item {
            width: parent.width
            implicitHeight: less.implicitHeight

            Label {
                id: less
                text: qsTr("Less warm")
                role: Label.Role.Caption
                muted: true
            }

            Label {
                anchors.right: parent.right
                text: qsTr("Warmer")
                role: Label.Role.Caption
                muted: true
            }
        }
    }
}
