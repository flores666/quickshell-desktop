pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"

/*! Text with the shell's typography applied. Use instead of bare Text. */
Text {
    id: root

    enum Role { Body, Caption, Small, Subtitle, Title, Display }

    property int role: Label.Role.Body
    property bool muted: false
    property bool faint: false

    color: root.faint ? Appearance.c.textFaint
        : root.muted ? Appearance.c.textMuted
        : Appearance.c.text
    font.family: Appearance.fontFamily
    font.pixelSize: switch (root.role) {
        case Label.Role.Caption: return Appearance.font.caption;
        case Label.Role.Small: return Appearance.font.small;
        case Label.Role.Subtitle: return Appearance.font.subtitle;
        case Label.Role.Title: return Appearance.font.title;
        case Label.Role.Display: return Appearance.font.display;
        default: return Appearance.font.body;
    }
    font.weight: root.role === Label.Role.Title || root.role === Label.Role.Subtitle
        ? Font.DemiBold : Font.Normal
    renderType: Text.NativeRendering
    elide: Text.ElideRight
    textFormat: Text.PlainText
    verticalAlignment: Text.AlignVCenter
}
