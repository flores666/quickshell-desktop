pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"

/*!
    The well every text input sits in: a rounded fill with no border, a wash
    under the pointer, and a stronger one while its input has the keyboard.

    The hover comes from a Clickable, as every widget's state does, laid over
    the input and taking no buttons: a press goes straight through to the text
    beneath it, and the pointer reads as a text cursor anywhere in the well.
    Anything that must take its own hover and presses — a clear button, a
    reveal toggle — goes in `trailing`, which sits above it.
*/
Item {
    id: root

    /*! Whether the input inside has the keyboard. */
    property bool focused: false
    property color color: Appearance.c.sunken
    default property alias content: holder.data
    property alias trailing: trailingHolder.data

    implicitWidth: 240
    implicitHeight: Appearance.m.fieldHeight

    Rectangle {
        anchors.fill: parent
        radius: Appearance.r.md
        color: root.color

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: root.focused ? Appearance.c.selectLayer
                : pointer.hovered ? Appearance.c.hoverLayer : "transparent"

            Behavior on color {
                ColorAnimation { duration: Appearance.t.instant; easing.type: Appearance.t.standardEasing }
            }
        }
    }

    Item {
        id: holder
        anchors.fill: parent
    }

    Clickable {
        id: pointer
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        cursorShape: Qt.IBeamCursor
        focusable: false
        showStateLayer: false
    }

    Item {
        id: trailingHolder
        anchors.fill: parent
    }
}
