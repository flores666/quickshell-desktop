pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    The design system: theme, the two colour seeds the rest of the palette is
    derived from, the type, and the two numbers every surface in the shell is
    drawn with.

    The last of those used to sit under the top panel labelled "Everywhere",
    which was an admission that it did not belong there. A border and a corner
    radius are no more the panel's than they are the dock's.
*/
Column {
    id: root

    spacing: Appearance.s.lg

    MenuRow {
        width: root.width
        title: qsTr("Dark style")
        subtitle: qsTr("Both themes are hand-tuned; the seeds below apply to each separately")
        icon: "night-light"
        onClicked: Settings.toggleTheme()

        ToggleSwitch {
            anchors.verticalCenter: parent.verticalCenter
            checked: Appearance.dark
            onToggled: value => Settings.setTheme(value ? "dark" : "light")
        }
    }

    Divider { width: root.width }

    ColorsSection { width: root.width }

    Divider { width: root.width }

    FontSection { width: root.width }

    Divider { width: root.width }

    Label {
        text: qsTr("Surfaces")
        role: Label.Role.Small
        muted: true
    }

    SettingRow {
        width: root.width
        key: "border"
        label: qsTr("Border")
        min: Tuning.spec.border.min
        max: Tuning.spec.border.max
        value: Appearance.m.border
    }

    SettingRow {
        width: root.width
        key: "roundness"
        label: qsTr("Corner roundness")
        min: Tuning.spec.roundness.min
        max: Tuning.spec.roundness.max
        value: Tuning.pick("roundness")
        suffix: qsTr("%")
        step: 5
    }
}
