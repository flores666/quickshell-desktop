pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

/*! The dock: how big its icons are, how far it sits off the screen edge, and
    how long it waits before it slides away. */
Column {
    id: root

    spacing: Appearance.s.lg

    SettingRow {
        width: root.width
        key: "dockIcon"
        label: qsTr("Icon size")
        min: Tuning.spec.dockIcon.min
        max: Tuning.spec.dockIcon.max
        value: Appearance.m.dockIcon
    }

    SettingRow {
        width: root.width
        key: "screenGap"
        label: qsTr("Gap from the edge")
        min: Tuning.spec.screenGap.min
        max: Tuning.spec.screenGap.max
        value: Appearance.m.screenGap
    }

    /*! A timing rather than a size, so the range is the one Dock clamps to
        rather than anything in Tuning. */
    SettingRow {
        width: root.width
        key: "dockHideDelay"
        label: qsTr("Hide delay")
        min: 0
        max: 5000
        step: 100
        value: Dock.hideDelay
        suffix: qsTr("ms")
    }

    Label {
        width: root.width
        text: qsTr("The dock reserves no space; windows sit under it either way.")
        role: Label.Role.Caption
        faint: true
        wrapMode: Text.Wrap
    }
}
