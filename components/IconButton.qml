pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"

/*! A square icon-only button. The default chrome control of the shell. */
Clickable {
    id: root

    property string icon
    property int iconSize: Appearance.m.icon
    property int size: Appearance.m.touchTarget
    property color iconColor: root.accented ? Appearance.c.accentText : Appearance.c.text
    /*! Filled with the accent colour, e.g. an engaged toggle. */
    property bool accented: false

    implicitWidth: root.size
    implicitHeight: root.size
    radius: Appearance.r.full
    background: root.accented ? Appearance.c.accent : "transparent"

    Icon {
        anchors.centerIn: parent
        name: root.icon
        size: root.iconSize
        color: root.iconColor

        Behavior on color {
            ColorAnimation { duration: Appearance.t.fast; easing.type: Appearance.t.standardEasing }
        }
    }
}
