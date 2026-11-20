pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"

/*!
    A text input's rounded fill stays the same under hover and focus.
    The input itself shows the caret when it has the keyboard.

    A Clickable over the input gives the well a text cursor and lets presses
    reach the input.
    Anything that must take its own hover and presses — a clear button, a
    reveal toggle — goes in `trailing`, which sits above it.
*/
Item {
    id: root

    property color color: Appearance.c.sunken
    default property alias content: holder.data
    property alias trailing: trailingHolder.data

    implicitWidth: Appearance.m.fieldWidth
    implicitHeight: Appearance.m.fieldHeight

    Rectangle {
        anchors.fill: parent
        radius: Appearance.r.md
        color: root.color
    }

    Item {
        id: holder
        anchors.fill: parent
    }

    Clickable {
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
