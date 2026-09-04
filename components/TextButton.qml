pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"

/*! A labelled button, optionally with a leading icon. */
Clickable {
    id: root

    enum Kind { Normal, Accent, Danger }

    property string text
    property string icon: ""
    property int kind: TextButton.Kind.Normal

    readonly property color fill: switch (root.kind) {
        case TextButton.Kind.Accent: return Appearance.c.accent;
        case TextButton.Kind.Danger: return Appearance.c.danger;
        default: return Appearance.c.raised;
    }
    readonly property color ink: root.kind === TextButton.Kind.Normal
        ? Appearance.c.text : Appearance.c.accentText

    implicitWidth: row.implicitWidth + Appearance.s.xl * 2
    implicitHeight: 34
    radius: Appearance.r.sm
    background: root.fill

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Appearance.s.md

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.icon !== ""
            name: root.icon
            size: Appearance.m.icon
            color: root.ink
        }

        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: root.ink
            font.weight: Font.Medium
        }
    }
}
