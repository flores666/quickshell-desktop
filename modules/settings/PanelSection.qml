pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"

/*! The top bar: how tall it stands and how far off the edges it sits. */
Column {
    id: root

    spacing: Appearance.s.lg

    SettingRow {
        width: root.width
        key: "barHeight"
        label: qsTr("Height")
        min: Tuning.spec.barHeight.min
        max: Tuning.spec.barHeight.max
        value: Appearance.m.barHeight
    }

    SettingRow {
        width: root.width
        key: "barGap"
        label: qsTr("Gap above")
        min: Tuning.spec.barGap.min
        max: Tuning.spec.barGap.max
        value: Appearance.m.barGap
    }

    SettingRow {
        width: root.width
        key: "barSideGap"
        label: qsTr("Gap at the sides")
        min: Tuning.spec.barSideGap.min
        max: Tuning.spec.barSideGap.max
        value: Appearance.m.barSideGap
    }

    Label {
        width: root.width
        text: qsTr("Height and the gap above it are taken from every window on the screen.")
        role: Label.Role.Caption
        faint: true
        wrapMode: Text.Wrap
    }
}
