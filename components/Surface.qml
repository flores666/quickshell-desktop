pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"

/*!
    A glass panel: the base of every bar, dock, popover and card.

    The surface colour at the theme's glass opacity, edged with a hairline and
    lifted by a Shadow. What shows through is blurred by the compositor, which
    blurs a shell surface wherever it is more than half opaque (see the layer
    rule in hyprland.conf) — so the shadow around a panel stays crisp paint and
    only the panel itself frosts. A card resting on another surface passes one
    of the washes (`raised`) as its colour instead, and is glass by inheritance.
*/
Item {
    id: root

    property color color: Appearance.c.chrome
    property int radius: Appearance.r.md
    property int elevation: 2
    property bool bordered: true
    property color borderColor: Appearance.c.border
    default property alias content: inner.data

    Shadow {
        anchors.fill: parent
        radius: root.radius
        level: root.elevation
    }

    Rectangle {
        id: inner
        anchors.fill: parent
        radius: root.radius
        color: root.color
        border.width: root.bordered ? Appearance.m.border : 0
        border.color: root.borderColor
        antialiasing: root.radius > 0
    }
}
