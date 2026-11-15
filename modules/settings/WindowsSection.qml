pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"

/*! Window spacing and opacity. Shared frames and effects are in Appearance. */
Column {
    id: root

    spacing: Appearance.s.xl

    SettingGroup {
        width: root.width
        title: qsTr("Spacing")

        CompositorSettingRow { key: "hyprGapsIn"; label: qsTr("Between windows"); displayMultiplier: 2 }
        CompositorSettingRow { key: "hyprGapsOut"; label: qsTr("Side and bottom margins") }

        Label {
            width: parent.width
            text: qsTr("The top margin follows the top panel's gap above and below.")
            role: Label.Role.Caption
            faint: true
            wrapMode: Text.Wrap
        }
    }

    SettingGroup {
        width: root.width
        title: qsTr("Opacity")

        CompositorSettingRow { key: "hyprActiveOpacity"; label: qsTr("Focused window"); suffix: qsTr("%") }
        CompositorSettingRow { key: "hyprInactiveOpacity"; label: qsTr("Other windows"); suffix: qsTr("%") }
    }
}
