pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"

/*!
    One fact on a card: what it is, its value, and where it is a share of
    something (`fraction` 0 to 1), a bar of it in the colour of the reading it
    belongs to. With no share (`fraction` below 0) the bar's room is kept, so
    cards side by side stand as tall.
*/
Card {
    id: root

    property string title: ""
    property string value: ""
    property real fraction: -1
    property color ink: Appearance.c.accent

    implicitHeight: column.implicitHeight + root.padding * 2

    Column {
        id: column

        x: root.padding
        y: root.padding
        width: root.width - root.padding * 2
        spacing: Appearance.s.xs

        Label {
            width: column.width
            text: root.title
            role: Label.Role.Small
            muted: true
        }

        Label {
            width: column.width
            text: root.value
            font.weight: Font.Medium
            font.features: { "tnum": 1 }
        }

        UsageBar {
            width: column.width
            opacity: root.fraction < 0 ? 0 : 1
            fraction: Math.max(0, root.fraction)
            color: root.ink
        }
    }
}
