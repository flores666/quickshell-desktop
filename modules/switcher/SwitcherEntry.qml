pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

/*! One window in the switcher: its application's icon in a slot that the
    highlight fills while it is the one chosen. A minimized window's icon is
    faint, as its dock icon's dot would be missing. */
Clickable {
    id: root

    required property var entry
    required property int index
    /*! Below 1 when the row would not fit across the screen at full size. */
    property real fit: 1

    implicitWidth: Math.round((Appearance.m.switcherIcon + Appearance.m.switcherInset * 2) * root.fit)
    implicitHeight: root.implicitWidth
    radius: Appearance.r.md
    focusable: false
    selected: root.index === Switcher.index

    onHoveredChanged: if (root.hovered) Switcher.point(root.index)
    onClicked: Switcher.choose(root.index)

    AppIcon {
        anchors.centerIn: parent
        source: root.entry.icon
        size: Math.round(Appearance.m.switcherIcon * root.fit)
        optical: true
        opacity: root.entry.minimized ? 0.5 : 1
    }
}
