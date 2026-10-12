pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

/*! The dock: how big its icons are, how far it sits off the screen edge, and
    how long it waits before it slides away. */
Column {
    id: root

    spacing: Appearance.s.md

    SettingGroup {
        width: root.width

        SettingRow {
            width: parent.width
            key: "dockIcon"
            label: qsTr("Icon size")
            min: Tuning.spec.dockIcon.min
            max: Tuning.spec.dockIcon.max
            value: Appearance.m.dockIcon
        }

        SettingRow {
            width: parent.width
            key: "screenGap"
            label: qsTr("Gap from the edge")
            min: Tuning.spec.screenGap.min
            max: Tuning.spec.screenGap.max
            value: Appearance.m.screenGap
        }

        /*! A timing rather than a size, so the range is the one Dock clamps to
            rather than anything in Tuning. */
        SettingRow {
            width: parent.width
            key: "dockHideDelay"
            label: qsTr("Hide delay")
            min: Dock.hideDelayRange.min
            max: Dock.hideDelayRange.max
            step: 100
            value: Dock.hideDelay
            suffix: qsTr("ms")
        }
    }

    Label {
        width: root.width
        text: qsTr("The dock reserves no space; windows sit under it either way.")
        role: Label.Role.Caption
        faint: true
        wrapMode: Text.Wrap
    }
}
