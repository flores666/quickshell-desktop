pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    One rate on a card, as large as a figure gets in the task manager: what
    it is beside its glyph, which is drawn in the colour of its line in the
    chart below, and how much a second now ("–" before there is a reading).
*/
Card {
    id: root

    property string title: ""
    property string icon: ""
    /*! Its series' colour: the glyph's, never the text's. */
    property color ink: Appearance.c.text
    /*! Bytes a second, -1 for no reading. */
    property real rate: -1

    implicitHeight: column.implicitHeight + root.padding * 2

    Column {
        id: column

        x: root.padding
        y: root.padding
        width: root.width - root.padding * 2
        spacing: Appearance.s.xs

        Row {
            spacing: Appearance.s.sm

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: root.icon
                color: root.ink
            }

            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: root.title
                role: Label.Role.Small
                muted: true
            }
        }

        Label {
            width: column.width
            text: Usage.formatRate(root.rate)
            role: Label.Role.Title
            font.features: { "tnum": 1 }
        }
    }
}
