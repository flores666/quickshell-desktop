pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"

/*! The dock: how big its icons are, and how far it sits off the screen edge. */
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

    Label {
        width: root.width
        text: qsTr("The dock reserves no space; windows sit under it either way.")
        role: Label.Role.Caption
        faint: true
        wrapMode: Text.Wrap
    }
}
