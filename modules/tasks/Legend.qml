pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"

/*!
    Which line of a chart is which: per series a dot in its colour, its name,
    and, where given, its reading now. The text keeps the text's colours; the
    dot alone carries the series'.

    `entries` is `[{ label, color, value }]`, `value` optional.
*/
Row {
    id: root

    property var entries: []

    spacing: Appearance.s.lg

    Repeater {
        model: root.entries

        Row {
            id: entry

            required property var modelData

            spacing: Appearance.s.xs

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Appearance.m.chartDot * 2
                height: width
                radius: width / 2
                color: entry.modelData.color
            }

            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: entry.modelData.label
                role: Label.Role.Small
                muted: true
            }

            Label {
                anchors.verticalCenter: parent.verticalCenter
                visible: (entry.modelData.value ?? "") !== ""
                text: entry.modelData.value ?? ""
                role: Label.Role.Small
                font.features: { "tnum": 1 }
            }
        }
    }
}
