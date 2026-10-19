pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

/*! The dock: whether it hides, whether it has a background, how big its icons
    are, and how long it waits before it slides away. */
Column {
    id: root

    spacing: Appearance.s.md

    SettingGroup {
        width: root.width

        MenuRow {
            width: parent.width
            flush: true
            title: qsTr("Auto-hide")
            subtitle: qsTr("Slide away when not in use; point at the bottom edge to bring it back")
            onClicked: Settings.setDockAutoHide(!Settings.dockAutoHide)

            ToggleSwitch {
                checked: Settings.dockAutoHide
                onToggled: value => Settings.setDockAutoHide(value)
            }
        }

        MenuRow {
            width: parent.width
            flush: true
            title: qsTr("Background")
            subtitle: qsTr("The glass panel behind the icons")
            onClicked: Settings.setDockBackground(!Settings.dockBackground)

            ToggleSwitch {
                checked: Settings.dockBackground
                onToggled: value => Settings.setDockBackground(value)
            }
        }

        SettingRow {
            width: parent.width
            key: "dockIcon"
            label: qsTr("Icon size")
            min: Tuning.spec.dockIcon.min
            max: Tuning.spec.dockIcon.max
            value: Appearance.m.dockIcon
        }

        /*! A timing rather than a size, so the range is the one Dock clamps to
            rather than anything in Tuning. A dock that never hides has no use
            for it, so it is not offered then. */
        SettingRow {
            width: parent.width
            visible: Settings.dockAutoHide
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
        text: Settings.dockAutoHide
            ? qsTr("The dock reserves no space; windows sit under it.")
            : qsTr("Windows stop above the dock, the way they stop below the bar.")
        role: Label.Role.Caption
        faint: true
        wrapMode: Text.Wrap
    }
}
