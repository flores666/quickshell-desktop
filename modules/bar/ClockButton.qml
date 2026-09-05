pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    The centre of the bar: the clock, with a compact now-playing chip beside it
    whenever a player is actually playing something.  Opens the date menu, which
    holds the calendar, notifications and full media controls.
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

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        visible: Players.playing
        name: "play"
        size: Appearance.m.iconSm
        color: Appearance.c.accent
    }

    Label {
        anchors.verticalCenter: parent.verticalCenter
        visible: Players.playing && text !== ""
        text: Players.summary
        role: Label.Role.Small
        muted: true
        width: Math.min(implicitWidth, 200)
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        visible: Players.playing
        width: 1
        height: 12
        color: Appearance.c.border
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
