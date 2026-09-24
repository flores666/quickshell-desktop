pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

/*! Hyprland's windows: the space around them, their frame, and the effects
    drawn on them. Defaults are whatever hyprland.conf sets. */
Column {
    id: root

    spacing: Appearance.s.lg

    component HyprRow: SettingRow {
        readonly property var limits: CompositorOptions.spec[this.key]

        width: root.width
        min: this.limits.min
        max: this.limits.max
        known: CompositorOptions.known(this.key)
        value: this.known ? CompositorOptions.value(this.key) : this.min
    }

    Label {
        text: qsTr("Layout")
        role: Label.Role.Small
        muted: true
    }

    HyprRow { key: "hyprGapsIn"; label: qsTr("Gap around each window") }
    HyprRow { key: "hyprGapsOut"; label: qsTr("Gap from the screen edge") }
    HyprRow { key: "hyprBorder"; label: qsTr("Border") }
    HyprRow { key: "hyprRounding"; label: qsTr("Corner radius") }

    Divider { width: root.width }

    Label {
        text: qsTr("Effects")
        role: Label.Role.Small
        muted: true
    }

    SettingToggle { width: root.width; key: "hyprBlur"; title: qsTr("Blur") }
    SettingToggle { width: root.width; key: "hyprAnimations"; title: qsTr("Animations") }
    HyprRow { key: "hyprActiveOpacity"; label: qsTr("Focused window opacity"); suffix: qsTr("%") }
    HyprRow { key: "hyprInactiveOpacity"; label: qsTr("Other windows' opacity"); suffix: qsTr("%") }

    Label {
        width: root.width
        text: qsTr("Changes apply at once and are kept by the shell; hyprland.conf is never rewritten.")
        role: Label.Role.Caption
        faint: true
        wrapMode: Text.Wrap
    }
}
