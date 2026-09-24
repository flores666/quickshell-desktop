pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

/*! How the pointer feels. The touchpad half is absent on a machine without
    one. Defaults are whatever hyprland.conf sets. */
Column {
    id: root

    spacing: Appearance.s.lg

    component HyprRow: SettingRow {
        readonly property var limits: CompositorOptions.spec[this.key]

        width: root.width
        min: this.limits.min
        max: this.limits.max
        suffix: qsTr("%")
        step: 5
        known: CompositorOptions.known(this.key)
        // Speeds are centred on 100, Hyprland's neutral.
        value: this.known ? CompositorOptions.value(this.key) : 100
    }

    Label {
        text: qsTr("Mouse")
        role: Label.Role.Small
        muted: true
    }

    HyprRow { key: "hyprMouseSpeed"; label: qsTr("Speed") }
    SettingToggle {
        width: root.width
        key: "hyprMouseAccel"
        title: qsTr("Acceleration")
        subtitle: qsTr("Faster movements travel further")
    }
    HyprRow { key: "hyprMouseScroll"; label: qsTr("Scroll speed") }

    Label {
        width: root.width
        text: qsTr("Applies to every pointer without its own device block in hyprland.conf.")
        role: Label.Role.Caption
        faint: true
        wrapMode: Text.Wrap
    }

    Divider { width: root.width; visible: CompositorOptions.hasTouchpad }

    Column {
        width: root.width
        visible: CompositorOptions.hasTouchpad
        spacing: Appearance.s.lg

        Label {
            text: qsTr("Touchpad")
            role: Label.Role.Small
            muted: true
        }

        HyprRow { key: "hyprTouchpadSpeed"; label: qsTr("Speed") }
        HyprRow { key: "hyprTouchpadScroll"; label: qsTr("Scroll speed") }
        SettingToggle { width: root.width; key: "hyprNaturalScroll"; title: qsTr("Natural scrolling"); subtitle: qsTr("Content moves with your fingers") }
        SettingToggle { width: root.width; key: "hyprTapToClick"; title: qsTr("Tap to click") }
    }
}
