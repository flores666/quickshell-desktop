pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"

/*!
    A full-width row for menus and settings lists: leading icon, title, optional
    subtitle, and a trailing slot for a switch, chevron or status text.
*/
Clickable {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property color iconColor: Appearance.c.text
    property int spacing: Appearance.s.lg
    default property alias trailing: trailingSlot.data

    // Deliberately a constant: the text column is sized from the row's actual
    // width, so deriving the row width from the text would form a binding loop.
    implicitWidth: Appearance.m.popoverWidth
    implicitHeight: Math.max(44, texts.implicitHeight + Appearance.s.md * 2)
    radius: Appearance.r.sm

    Icon {
        id: leading
        anchors.verticalCenter: parent.verticalCenter
        x: Appearance.s.lg
        visible: root.icon !== ""
        name: root.icon
        size: Appearance.m.icon
        color: root.iconColor
    }

    Column {
        id: texts
        anchors.verticalCenter: parent.verticalCenter
        x: leading.visible ? leading.x + leading.width + root.spacing : Appearance.s.lg
        width: trailingSlot.x - x - root.spacing
        spacing: 1

        Label {
            width: parent.width
            text: root.title
            font.weight: Font.Medium
        }

        Label {
            width: parent.width
            visible: root.subtitle !== ""
            text: root.subtitle
            role: Label.Role.Small
            muted: true
        }
    }

    Item {
        id: trailingSlot
        anchors.verticalCenter: parent.verticalCenter
        x: root.width - width - Appearance.s.lg
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
        width: implicitWidth
        height: implicitHeight
    }
}
