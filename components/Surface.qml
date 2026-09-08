pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"

/*!
    An opaque rounded panel: the base of every bar, dock, popover and card.
    Always fully opaque — the design system has no translucent surfaces.
*/
Item {
    id: root

    property color color: Appearance.c.surface
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
