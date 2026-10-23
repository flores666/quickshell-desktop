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
    /*! How much of its glass it lays down: its fill, hairline and shadow
        together, its content untouched — the bar and the dock at the user's
        opacity (Appearance.barOpacity). Each faded by its own alpha, so it
        never passes through another colour, and eased, so a step (a reset,
        the dock taking up the bar's) fades rather than jumps. */
    property real glass: 1
    default property alias content: inner.data

    Behavior on glass {
        NumberAnimation { duration: Appearance.t.base; easing.type: Appearance.t.standardEasing }
    }

    Shadow {
        anchors.fill: parent
        radius: root.radius
        level: root.elevation
        opacity: root.glass
    }

    Rectangle {
        id: inner
        anchors.fill: parent
        radius: root.radius
        color: Qt.alpha(root.color, root.color.a * root.glass)
        border.width: root.bordered ? Appearance.m.border : 0
        border.color: Qt.alpha(root.borderColor, root.borderColor.a * root.glass)
        antialiasing: root.radius > 0
    }
}
