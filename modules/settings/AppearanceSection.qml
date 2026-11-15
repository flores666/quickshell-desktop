pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    Visual choices together: theme, colors, type, frames and shared effects.
    A switch and the value it controls stay in the same section.
*/
Column {
    id: root

    spacing: Appearance.s.xl

    SettingGroup {
        width: root.width
        title: qsTr("Theme")

        Row {
            width: parent.width
            spacing: Appearance.s.md

            ThemeCard {
                width: (parent.width - parent.spacing) / 2
                scheme: Appearance.day
                title: qsTr("Light")
                selected: !Appearance.dark
                onClicked: Settings.setTheme("light")
            }

            ThemeCard {
                width: (parent.width - parent.spacing) / 2
                scheme: Appearance.night
                title: qsTr("Dark")
                selected: Appearance.dark
                onClicked: Settings.setTheme("dark")
            }
        }
    }

    SettingGroup {
        width: root.width
        title: qsTr("Colors")

        ColorsSection { width: parent.width }
    }

    SettingGroup {
        width: root.width
        title: qsTr("Font")

        FontSection { width: parent.width }
    }

    SettingGroup {
        width: root.width
        title: qsTr("Window frame")

        CompositorSettingRow { key: "hyprBorder"; label: qsTr("Border width") }
        CompositorSettingRow { key: "hyprRounding"; label: qsTr("Corner radius") }
    }

    SettingGroup {
        width: root.width
        title: qsTr("Panels and popups")

        SettingRow {
            width: parent.width
            key: "border"
            label: qsTr("Border width")
            min: Tuning.spec.border.min
            max: Tuning.spec.border.max
            value: Appearance.m.border
        }

        /*! Absent when Hyprland's window rounding cannot be read: there would be
            nothing to follow. */
        MenuRow {
            width: parent.width
            visible: CompositorOptions.known("hyprRounding")
            flush: true
            title: qsTr("Match window corners")
            subtitle: qsTr("Use the window corner radius above")
            onClicked: Settings.setRoundnessFollowsWindows(!Settings.roundnessFollowsWindows)

            ToggleSwitch {
                checked: Settings.roundnessFollowsWindows
                onToggled: value => Settings.setRoundnessFollowsWindows(value)
            }
        }

        // While the corners follow the windows this setting drives nothing, so it
        // is not offered; window rounding is directly above.
        SettingRow {
            width: parent.width
            visible: !Appearance.r.followsWindows
            key: "roundness"
            label: qsTr("Corner roundness")
            min: Tuning.spec.roundness.min
            max: Tuning.spec.roundness.max
            value: Tuning.pick("roundness")
            suffix: qsTr("%")
            step: 5
        }

        SettingRow {
            width: parent.width
            key: "popupOpacity"
            label: qsTr("Popup opacity")
            min: Tuning.spec.popupOpacity.min
            max: Tuning.spec.popupOpacity.max
            value: Tuning.pick("popupOpacity")
            suffix: qsTr("%")
        }
    }

    SettingGroup {
        width: root.width
        title: qsTr("Effects")

        SettingToggle { width: parent.width; key: "hyprAnimations"; title: qsTr("Animations") }
        SettingToggle {
            width: parent.width
            key: "hyprBlur"
            title: qsTr("Background blur")
            subtitle: qsTr("Panels, popups, and translucent windows")
        }

        /*! Hyprland's blur radius: only the compositor can blur what is behind
            a surface, and it has one strength for everything it blurs. Absent
            while blur is off or cannot be read. */
        CompositorSettingRow {
            id: blurRow
            width: parent.width
            visible: CompositorOptions.value("hyprBlur") !== 0 && CompositorOptions.known("hyprBlurSize")
            key: "hyprBlurSize"
            label: qsTr("Blur strength")
            suffix: ""
        }
    }
}
