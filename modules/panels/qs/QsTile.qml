pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"

/*!
    A quick-settings tile: an icon, a title, a status line, and — when the
    feature has a detail page — a chevron button inside it that opens it.

    Engaged reads as the tile filled with the accent, as much glass as the
    card under it (Appearance.popupAccent), everything on it in the ink that
    reads best there, and the icon's disc a wash of that ink.
*/
Item {
    id: root

    property string icon: ""
    property string title: ""
    property string status: ""
    property bool active: false
    property bool busy: false
    property bool hasPage: false
    property bool toggleEnabled: true

    signal toggled
    signal pageRequested

    implicitWidth: 168
    implicitHeight: 58

    Clickable {
        id: main
        anchors.fill: parent
        radius: Appearance.r.lg
        // A read-only tile still reads at full strength; it just does not react.
        hoverEnabled: root.toggleEnabled
        pressEnabled: root.toggleEnabled
        focusable: root.toggleEnabled
        background: root.active ? Appearance.popupAccent : Appearance.c.raised
        onClicked: if (root.toggleEnabled) root.toggled()

        Behavior on background {
            ColorAnimation { duration: Appearance.t.fast; easing.type: Appearance.t.standardEasing }
        }

        Rectangle {
            id: bubble
            x: Appearance.s.md + Appearance.s.xxs
            anchors.verticalCenter: parent.verticalCenter
            width: 34
            height: 34
            radius: height / 2
            color: root.active ? Appearance.popupAccentLayer : Appearance.c.sunken

            Behavior on color {
                ColorAnimation { duration: Appearance.t.fast; easing.type: Appearance.t.standardEasing }
            }

            Icon {
                anchors.centerIn: parent
                visible: !root.busy
                name: root.icon
                size: Appearance.m.icon
                color: root.active ? Appearance.popupAccentInk : Appearance.c.text
            }

            Spinner {
                anchors.centerIn: parent
                visible: root.busy
                size: Appearance.m.icon
                color: root.active ? Appearance.popupAccentInk : Appearance.c.text
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            x: bubble.x + bubble.width + Appearance.s.md
            width: (root.hasPage ? chevron.x : main.width) - x - Appearance.s.sm
            spacing: 0

            Label {
                width: parent.width
                text: root.title
                role: Label.Role.Small
                color: root.active ? Appearance.popupAccentInk : Appearance.c.text
                font.weight: Font.DemiBold

                Behavior on color {
                    ColorAnimation { duration: Appearance.t.fast; easing.type: Appearance.t.standardEasing }
                }
            }

            Label {
                width: parent.width
                visible: root.status !== ""
                text: root.status
                role: Label.Role.Caption
                color: root.active ? Appearance.popupAccentInkMuted : Appearance.c.textMuted

                Behavior on color {
                    ColorAnimation { duration: Appearance.t.fast; easing.type: Appearance.t.standardEasing }
                }
            }
        }
    }

    // Its own target, above the tile's, so opening the detail page never
    // toggles the feature by accident.
    IconButton {
        id: chevron
        anchors.right: parent.right
        anchors.rightMargin: Appearance.s.sm
        anchors.verticalCenter: parent.verticalCenter
        visible: root.hasPage
        icon: "chevron-right"
        iconSize: Appearance.m.iconSm
        size: 28
        iconColor: root.active ? Appearance.popupAccentInkMuted : Appearance.c.textMuted
        onClicked: root.pageRequested()
    }
}
