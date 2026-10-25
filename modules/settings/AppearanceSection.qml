pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    The design system: theme, the two colour seeds the rest of the palette is
    derived from, the type, and the two numbers every surface in the shell is
    drawn with, and how much of their glass the popups lay down.

    The last of those used to sit under the top panel labelled "Everywhere",
    which was an admission that it did not belong there. A border and a corner
    radius are no more the panel's than they are the dock's.
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

        Label {
            width: parent.width
            text: qsTr("Both themes are hand-tuned; the colors below apply to each separately.")
            role: Label.Role.Caption
            faint: true
            wrapMode: Text.Wrap
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
        title: qsTr("Surfaces")

        SettingRow {
            width: parent.width
            key: "border"
            label: qsTr("Border")
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
            subtitle: qsTr("Panels keep the same radius as Hyprland's windows")
            onClicked: Settings.setRoundnessFollowsWindows(!Settings.roundnessFollowsWindows)

            ToggleSwitch {
                checked: Settings.roundnessFollowsWindows
                onToggled: value => Settings.setRoundnessFollowsWindows(value)
            }
        }

        // While the corners follow the windows this setting drives nothing, so it
        // is not offered; window rounding is under Windows.
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
    }

    SettingGroup {
        width: root.width
        title: qsTr("Popups")

        SettingRow {
            width: parent.width
            key: "popupOpacity"
            label: qsTr("Opacity")
            min: Tuning.spec.popupOpacity.min
            max: Tuning.spec.popupOpacity.max
            value: Tuning.pick("popupOpacity")
            suffix: qsTr("%")
        }

        /*! Hyprland's blur radius: only the compositor can blur what is behind
            a surface, and it has one strength for everything it blurs. Absent
            while blur is off (Windows) or cannot be read. */
        SettingRow {
            id: blurRow
            width: parent.width
            visible: CompositorOptions.value("hyprBlur") !== 0 && CompositorOptions.known("hyprBlurSize")
            key: "hyprBlurSize"
            label: qsTr("Blur")
            min: CompositorOptions.spec.hyprBlurSize.min
            max: CompositorOptions.spec.hyprBlurSize.max
            value: CompositorOptions.value("hyprBlurSize")
            suffix: ""
        }

        Label {
            width: parent.width
            visible: blurRow.visible
            text: qsTr("Blur is the compositor's: the panels and see-through windows take it too.")
            role: Label.Role.Caption
            faint: true
            wrapMode: Text.Wrap
        }
    }
}
