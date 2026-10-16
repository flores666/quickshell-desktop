pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    Everything measured, put back at once: every size, gap, timing and
    Hyprland option this panel has changed returns to what it shipped with —
    hyprland.conf's own value, for those.

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
        title: qsTr("Reset")

        MenuRow {
            width: parent.width
            flush: true
            icon: "refresh"
            title: qsTr("Reset all settings")
            subtitle: root.anything
                ? qsTr("Sizes, gaps, timings and window options go back to their defaults")
                : qsTr("Everything is at its default")

            TextButton {
                text: qsTr("Reset all")
                kind: TextButton.Kind.Danger
                compact: true
                enabled: root.anything
                onClicked: Settings.resetOverrides()
            }
        }
    }

    Label {
        width: root.width
        text: qsTr("Colors, the font and the wallpaper are kept; each has its own way back where it is chosen.")
        role: Label.Role.Caption
        faint: true
        wrapMode: Text.Wrap
    }
}
