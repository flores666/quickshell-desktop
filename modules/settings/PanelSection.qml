pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"

/*! The top bar: how tall it stands, how far off the edges it sits, and how
    much of its glass it lays down. */
Column {
    id: root

    spacing: Appearance.s.md

    SettingGroup {
        width: root.width

        SettingRow {
            width: parent.width
            key: "barHeight"
            label: qsTr("Height")
            min: Tuning.spec.barHeight.min
            max: Tuning.spec.barHeight.max
            value: Appearance.m.barHeight
        }

        SettingRow {
            width: parent.width
            key: "barGap"
            label: qsTr("Gap above")
            min: Tuning.spec.barGap.min
            max: Tuning.spec.barGap.max
            value: Appearance.m.barGap
        }

        SettingRow {
            width: parent.width
            key: "barSideGap"
            label: qsTr("Gap at the sides")
            min: Tuning.spec.barSideGap.min
            max: Tuning.spec.barSideGap.max
            value: Appearance.m.barSideGap
        }

        SettingRow {
            width: parent.width
            key: "barOpacity"
            label: qsTr("Opacity")
            min: Tuning.spec.barOpacity.min
            max: Tuning.spec.barOpacity.max
            value: Tuning.pick("barOpacity")
            suffix: qsTr("%")
        }
    }
}
