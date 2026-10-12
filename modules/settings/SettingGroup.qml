pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"

/*!
    Settings that belong together, on one card: a heading above it, the rows
    inside it.

    The card is a `raised` wash on the panel's glass, so a pane reads as a few
    distinct groups rather than one long column. Rows inside it take their
    width from `parent.width`, which is the card's, less its padding.
*/
Column {
    id: root

    property string title: ""
    default property alias content: body.data

    spacing: Appearance.s.sm

    Label {
        visible: root.title !== ""
        text: root.title
        role: Label.Role.Small
        font.weight: Font.DemiBold
        muted: true
        leftPadding: Appearance.s.xxs
    }

    Rectangle {
        width: root.width
        height: body.implicitHeight + Appearance.s.lg * 2
        radius: Appearance.r.lg
        color: Appearance.c.raised
        border.width: Appearance.m.border
        border.color: Appearance.c.border

        Column {
            id: body
            x: Appearance.s.lg
            y: Appearance.s.lg
            width: parent.width - Appearance.s.lg * 2
            spacing: Appearance.s.lg
        }
    }
}
