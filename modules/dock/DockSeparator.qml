pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"

/*! The hairline between a dock's application group and its edge controls. */
Rectangle {
    implicitWidth: Appearance.m.dockDividerWidth
    implicitHeight: Appearance.m.dockDivider
    color: Appearance.c.border
}
