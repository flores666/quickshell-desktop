pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

/*! The dock: whether it hides, how much of its glass it lays down — its own
    share or the top panel's — how big its icons are, and how long it waits
    before it slides away, and its magnification wave. */
Column {
    id: root

    spacing: Appearance.s.md

    SettingGroup {
        width: root.width

        MenuRow {
            width: parent.width
            flush: true
            title: qsTr("Auto-hide")
            subtitle: qsTr("Slide away when not in use; point at the bottom edge to bring it back")
            onClicked: Settings.setDockAutoHide(!Settings.dockAutoHide)

            ToggleSwitch {
                checked: Settings.dockAutoHide
                onToggled: value => Settings.setDockAutoHide(value)
            }
        }

        MenuRow {
            width: parent.width
            flush: true
            title: qsTr("Match top panel")
            subtitle: qsTr("Use the top panel's opacity")
            onClicked: Settings.setDockOpacityFollowsBar(!Settings.dockOpacityFollowsBar)

            ToggleSwitch {
                checked: Settings.dockOpacityFollowsBar
                onToggled: value => Settings.setDockOpacityFollowsBar(value)
            }
        }

        // While the dock takes the top panel's this setting drives nothing, so
        // it is not offered.
        SettingRow {
            width: parent.width
            visible: !Settings.dockOpacityFollowsBar
            key: "dockOpacity"
            label: qsTr("Opacity")
            min: Tuning.spec.dockOpacity.min
            max: Tuning.spec.dockOpacity.max
            value: Tuning.pick("dockOpacity")
            suffix: qsTr("%")
        }

        SettingRow {
            width: parent.width
            key: "dockIcon"
            label: qsTr("Icon size")
            min: Tuning.spec.dockIcon.min
            max: Tuning.spec.dockIcon.max
            value: Appearance.m.dockIcon
        }

        /*! A timing rather than a size, so the range is the one Dock clamps to
            rather than anything in Tuning. A dock that never hides has no use
            for it, so it is not offered then. */
        SettingRow {
            width: parent.width
            visible: Settings.dockAutoHide
            key: "dockHideDelay"
            label: qsTr("Hide delay")
            min: Dock.hideDelayRange.min
            max: Dock.hideDelayRange.max
            step: 100
            value: Dock.hideDelay
            suffix: qsTr("ms")
        }
    }

    SettingGroup {
        width: root.width
        title: qsTr("Magnification")

        MenuRow {
            width: parent.width
            flush: true
            title: qsTr("Magnify icons")
            subtitle: qsTr("Enlarge icons near the pointer")
            onClicked: Settings.setDockMagnificationEnabled(!Settings.dockMagnificationEnabled)

            ToggleSwitch {
                checked: Settings.dockMagnificationEnabled
                onToggled: value => Settings.setDockMagnificationEnabled(value)
            }
        }

        SettingRow {
            width: parent.width
            visible: Settings.dockMagnificationEnabled
            key: "dockZoom"
            label: qsTr("Zoom amount")
            min: Tuning.spec.dockZoom.min
            max: Tuning.spec.dockZoom.max
            value: Tuning.pick("dockZoom")
            suffix: qsTr("%")
        }

        SettingRow {
            width: parent.width
            visible: Settings.dockMagnificationEnabled
            key: "dockMagnificationDuration"
            label: qsTr("Response time")
            min: Dock.magnificationDurationRange.min
            max: Dock.magnificationDurationRange.max
            step: 10
            value: Dock.magnificationDuration
            suffix: qsTr("ms")
        }

        SettingRow {
            width: parent.width
            visible: Settings.dockMagnificationEnabled
            key: "dockWaveWidth"
            label: qsTr("Wave width")
            min: Tuning.spec.dockWaveWidth.min
            max: Tuning.spec.dockWaveWidth.max
            step: 5
            value: Tuning.pick("dockWaveWidth")
            suffix: qsTr("%")
        }
    }
}
