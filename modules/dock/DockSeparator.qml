pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"

/*! The hairline between the applications and the launcher. The dock draws it
    in the gap before the launcher's slot, where it takes no room of its own:
    the launcher stands one step from its neighbour, as every icon does. */
Rectangle {
    implicitWidth: 1
    implicitHeight: Appearance.m.dockDivider
    color: Appearance.c.border
}
