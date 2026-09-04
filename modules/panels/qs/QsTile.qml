pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"

/*!
    A quick-settings tile: an icon, a title, a status line, and — when the
    feature has a detail page — a separate chevron target that opens it.
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
    implicitHeight: 56

    Clickable {
        id: main
        anchors.fill: parent
        anchors.rightMargin: root.hasPage ? 34 : 0
        radius: Appearance.r.md
        // A read-only tile still reads at full strength; it just does not react.
        hoverEnabled: root.toggleEnabled
        pressEnabled: root.toggleEnabled
        focusable: root.toggleEnabled
        background: root.active ? Appearance.c.accent : Appearance.c.raised
        onClicked: if (root.toggleEnabled) root.toggled()

        Rectangle {
            id: bubble
            x: Appearance.s.md
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 32
            radius: 16
            color: root.active ? Qt.alpha(Appearance.c.accentText, 0.16) : Appearance.c.sunken

            Icon {
                anchors.centerIn: parent
                visible: !root.busy
                name: root.icon
                size: Appearance.m.icon
                color: root.active ? Appearance.c.accentText : Appearance.c.text
            }

            Spinner {
                anchors.centerIn: parent
                visible: root.busy
                size: Appearance.m.icon
                color: root.active ? Appearance.c.accentText : Appearance.c.text
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            x: bubble.x + bubble.width + Appearance.s.md
            width: main.width - x - Appearance.s.md
            spacing: 0

            Label {
                width: parent.width
                text: root.title
                role: Label.Role.Small
                font.weight: Font.DemiBold
                color: root.active ? Appearance.c.accentText : Appearance.c.text
            }

            Label {
                width: parent.width
                visible: root.status !== ""
                text: root.status
                role: Label.Role.Caption
                color: root.active ? Qt.alpha(Appearance.c.accentText, 0.8) : Appearance.c.textMuted
            }
        }
    }

    // The chevron is its own target so opening the detail page never toggles
    // the feature by accident.
    Clickable {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 34
        height: parent.height
        visible: root.hasPage
        radius: Appearance.r.md
        background: root.active ? Appearance.c.accent : Appearance.c.raised
        onClicked: root.pageRequested()

        Icon {
            anchors.centerIn: parent
            name: "chevron-right"
            size: Appearance.m.iconSm
            color: root.active ? Appearance.c.accentText : Appearance.c.textMuted
        }
    }

    // Hide the seam where the two rounded targets meet.
    Rectangle {
        visible: root.hasPage
        anchors.verticalCenter: parent.verticalCenter
        x: parent.width - 34 - Appearance.r.md
        width: Appearance.r.md * 2
        height: parent.height
        color: root.active ? Appearance.c.accent : Appearance.c.raised
        z: -1
    }
}
