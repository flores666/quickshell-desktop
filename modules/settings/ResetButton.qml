pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

/*! Puts one override back to its built-in value; shown only while it is set. */
IconButton {
    id: root

    required property string key

    visible: Settings.isOverridden(root.key)
    icon: "refresh"
    iconSize: Appearance.m.iconSm
    size: 22
    iconColor: Appearance.c.textMuted
    onClicked: Settings.setOverride(root.key, -1)
}
