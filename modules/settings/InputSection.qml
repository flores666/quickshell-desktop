pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

/*! How the pointer feels. The touchpad half is absent on a machine without
    one. Defaults are whatever hyprland.lua sets. */
Column {
    id: root

    spacing: Appearance.s.xl

    component HyprRow: CompositorSettingRow {
        suffix: qsTr("%")
        step: 5
        // Speeds are centred on 100, Hyprland's neutral.
        value: this.known ? CompositorOptions.value(this.key) : 100
    }

    SettingGroup {
        width: root.width
        title: qsTr("Mouse")

        HyprRow { key: "hyprMouseSpeed"; label: qsTr("Pointer speed") }
        SettingToggle {
            width: parent.width
            key: "hyprMouseAccel"
            title: qsTr("Acceleration")
            subtitle: qsTr("Faster movements travel further")
        }
        HyprRow { key: "hyprMouseScroll"; label: qsTr("Scroll speed") }
    }

    SettingGroup {
        width: root.width
        visible: CompositorOptions.hasTouchpad
        title: qsTr("Touchpad")

        HyprRow { key: "hyprTouchpadSpeed"; label: qsTr("Pointer speed") }
        HyprRow { key: "hyprTouchpadScroll"; label: qsTr("Scroll speed") }
        SettingToggle { width: parent.width; key: "hyprNaturalScroll"; title: qsTr("Natural scrolling"); subtitle: qsTr("Content moves with your fingers") }
        SettingToggle { width: parent.width; key: "hyprTapToClick"; title: qsTr("Tap to click") }
    }
}
