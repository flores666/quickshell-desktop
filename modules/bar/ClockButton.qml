pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    The centre of the bar: the date and clock.  Opens the date menu, which holds
    the calendar, notifications and the media controls.
*/
BarButton {
    id: root

    required property ShellScreen screen

    selected: Overlay.isOpen(Overlay.dateMenu)
    padding: Appearance.s.md

    onClicked: {
        Overlay.anchorX = root.windowCenterX();
        Overlay.toggle(Overlay.dateMenu, root.screen);
    }

    Label {
        anchors.verticalCenter: parent.verticalCenter
        text: Time.dateShort
        muted: true
    }

    Label {
        anchors.verticalCenter: parent.verticalCenter
        text: Time.time
        role: Label.Role.Subtitle
        font.weight: Font.DemiBold
        font.features: ({ "tnum": 1 })
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        visible: Notifs.count > 0 || Settings.doNotDisturb
        width: 6
        height: 6
        radius: 3
        color: Settings.doNotDisturb ? Appearance.c.textFaint : Appearance.c.accent
    }
}
