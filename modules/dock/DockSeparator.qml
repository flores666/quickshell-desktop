pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"

/*! A divider that sits inside an existing dock gap. */
Rectangle {
    implicitWidth: 1
    implicitHeight: Appearance.m.dockDivider
    color: Appearance.c.border
}
