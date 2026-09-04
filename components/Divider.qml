pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"

/*! A 1px hairline. Give it a width or height from the surrounding layout. */
Rectangle {
    id: root
    property bool vertical: false
    implicitWidth: root.vertical ? 1 : 0
    implicitHeight: root.vertical ? 0 : 1
    color: Appearance.c.border
}
