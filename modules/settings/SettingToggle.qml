pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    One on/off Hyprland option: SettingRow's counterpart for a switch.

    Like SettingRow it offers a way back only once there is something to undo,
    and going back means "whatever hyprland.conf says", not "off".
*/
MenuRow {
    id: root

    required property string key

    flush: true

    readonly property bool checked: CompositorOptions.value(root.key) === 1
    readonly property bool overridden: Settings.isOverridden(root.key)

    onClicked: CompositorOptions.set(root.key, root.checked ? 0 : 1)

    // Not anchored: the trailing slot sizes itself from its children, so a
    // child centred on it forms a binding loop.
    Row {
        spacing: Appearance.s.xs

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.overridden
            icon: "refresh"
            iconSize: Appearance.m.iconSm
            size: 22
            iconColor: Appearance.c.textMuted
            onClicked: Settings.setOverride(root.key, -1)
        }

        ToggleSwitch {
            anchors.verticalCenter: parent.verticalCenter
            checked: root.checked
            onToggled: value => CompositorOptions.set(root.key, value ? 1 : 0)
        }
    }
}
