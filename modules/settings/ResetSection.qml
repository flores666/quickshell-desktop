pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    Everything measured, put back at once: every size, gap, opacity, timing
    and Hyprland option this panel has changed returns to what it shipped with —
    hyprland.lua's own value, for those.

    The color, font and wallpaper choices are picked from a list rather than
    measured, and each list carries its own way back, so this is only ever
    about the numbers. Each row elsewhere also puts back its own value.
*/
Column {
    id: root

    readonly property bool anything: Settings.overrideKeys.some(k => Settings.isOverridden(k))

    spacing: Appearance.s.md

    SettingGroup {
        width: root.width

        MenuRow {
            width: parent.width
            flush: true
            icon: "refresh"
            title: qsTr("Reset adjustments")
            subtitle: root.anything
                ? qsTr("Sizes, gaps, opacity, timings and window options go back to their defaults")
                : qsTr("All adjustable values are at their defaults")

            TextButton {
                text: qsTr("Reset")
                kind: TextButton.Kind.Danger
                compact: true
                enabled: root.anything
                onClicked: Settings.resetOverrides()
            }
        }

        Label {
            width: parent.width
            text: qsTr("Keeps your theme, colors, font family, wallpaper, and panel and dock switches.")
            role: Label.Role.Caption
            faint: true
            wrapMode: Text.Wrap
        }
    }
}
