pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

/*! Hyprland's windows: the space around them, their frame, and the effects
    drawn on them. Defaults are whatever hyprland.conf sets. */
Column {
    id: root

    spacing: Appearance.s.xl

    component HyprRow: SettingRow {
        readonly property var limits: CompositorOptions.spec[this.key]

        width: parent.width
        min: this.limits.min
        max: this.limits.max
        known: CompositorOptions.known(this.key)
        value: this.known ? CompositorOptions.value(this.key) : this.min
    }

    SettingGroup {
        width: root.width
        title: qsTr("Layout")

        HyprRow { key: "hyprGapsIn"; label: qsTr("Gap around each window") }
        HyprRow { key: "hyprGapsOut"; label: qsTr("Gap from the screen edge") }
        HyprRow { key: "hyprBorder"; label: qsTr("Border") }
        HyprRow { key: "hyprRounding"; label: qsTr("Corner radius") }
    }

    SettingGroup {
        width: root.width
        title: qsTr("Effects")

        SettingToggle { width: parent.width; key: "hyprBlur"; title: qsTr("Blur") }
        SettingToggle { width: parent.width; key: "hyprAnimations"; title: qsTr("Animations") }
        HyprRow { key: "hyprActiveOpacity"; label: qsTr("Focused window opacity"); suffix: qsTr("%") }
        HyprRow { key: "hyprInactiveOpacity"; label: qsTr("Other windows' opacity"); suffix: qsTr("%") }
    }
}
