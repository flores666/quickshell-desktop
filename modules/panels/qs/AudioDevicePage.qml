pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Pipewire
import "root:/config"
import "root:/components"
import "root:/services"

/*! Choose the default output or input device. */
Item {
    id: root

    property bool output: true

    readonly property var devices: root.output ? Audio.sinks : Audio.sources
    readonly property PwNode current: root.output ? Audio.sink : Audio.source

    implicitHeight: Math.min(320, list.contentHeight + Appearance.s.md)

    ListView {
        id: list

        anchors.fill: parent
        clip: true
        model: root.devices
        spacing: 1
        boundsBehavior: Flickable.StopAtBounds

        delegate: MenuRow {
            id: devRow
            required property PwNode modelData

            width: list.width
            icon: Audio.deviceIcon(devRow.modelData)
            title: Audio.nodeLabel(devRow.modelData)
            selected: devRow.modelData === root.current
            iconColor: devRow.modelData === root.current ? Appearance.c.accent : Appearance.c.text

            onClicked: {
                if (root.output)
                    Audio.setSink(devRow.modelData);
                else
                    Audio.setSource(devRow.modelData);
            }

            Icon {
                visible: devRow.modelData === root.current
                name: "check"
                size: Appearance.m.icon
                color: Appearance.c.accent
            }
        }
    }

    ThinScrollBar { flickable: list }
}
