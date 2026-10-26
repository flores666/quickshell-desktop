pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"

/*!
    What an entity tab's thing is, on a card: its glyph at the left, then
    line by line what it is. A strong line (the first, unless a line says)
    is a name with its figure at the right, in the body's size; the rest are
    details, small, the label muted and its value at the right, a glyph
    before the label where one is given, in its series' colour. Where the
    thing has a capacity, a bar of how full it is.

    `lines` is `[{ text, value, icon, ink, strong }]`, or `{ bar, ink }` for
    a bar (its share, 0 to 1); a line with neither text nor value is left
    out. The delegates are kept by place, not rebuilt as the figures change.
*/
Card {
    id: root

    property string icon: ""
    property var lines: []

    readonly property var drawn: root.lines.filter(l => l.bar !== undefined
        || (l.text ?? "") !== "" || (l.value ?? "") !== "")

    implicitHeight: column.implicitHeight + root.padding * 2

    Icon {
        id: glyph
        x: root.padding
        anchors.verticalCenter: parent.verticalCenter
        name: root.icon
        size: Appearance.m.iconXl
        color: Appearance.c.textMuted
    }

    Column {
        id: column

        x: glyph.x + glyph.width + Appearance.s.lg
        y: root.padding
        width: root.width - x - root.padding
        spacing: Appearance.s.sm

        Repeater {
            model: root.drawn.length

            Item {
                id: line

                required property int index

                readonly property var spec: root.drawn[line.index] ?? ({})
                readonly property bool bar: line.spec.bar !== undefined
                readonly property bool strong: line.spec.strong ?? line.index === 0
                readonly property bool glyphed: (line.spec.icon ?? "") !== ""

                width: column.width
                height: line.bar ? Appearance.m.gaugeHeight : Math.max(label.implicitHeight, value.implicitHeight)

                UsageBar {
                    anchors.fill: parent
                    visible: line.bar
                    fraction: line.spec.bar ?? 0
                    color: line.spec.ink ?? Appearance.c.accent
                }

                Icon {
                    id: mark
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !line.bar && line.glyphed
                    name: line.spec.icon ?? ""
                    size: Appearance.m.iconSm
                    color: line.spec.ink ?? Appearance.c.textMuted
                }

                Label {
                    id: label
                    anchors.verticalCenter: parent.verticalCenter
                    x: line.glyphed ? mark.width + Appearance.s.sm : 0
                    width: Math.min(implicitWidth, line.width - x - value.implicitWidth - Appearance.s.lg)
                    visible: !line.bar
                    text: line.spec.text ?? ""
                    role: line.strong ? Label.Role.Body : Label.Role.Small
                    muted: !line.strong
                    font.weight: line.strong ? Font.Medium : Font.Normal
                }

                Label {
                    id: value
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !line.bar
                    text: line.spec.value ?? ""
                    role: line.strong ? Label.Role.Body : Label.Role.Small
                    font.weight: line.strong ? Font.Medium : Font.Normal
                    font.features: { "tnum": 1 }
                }
            }
        }
    }
}
