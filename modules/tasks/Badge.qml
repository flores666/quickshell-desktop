pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"

/*!
    A word beside a name, in a capsule: what earlyoom makes of a process.
*/
Rectangle {
    id: root

    property alias text: word.text
    /*! The word's colour. */
    property color ink: Appearance.c.text

    implicitWidth: word.implicitWidth + Appearance.s.md * 2
    implicitHeight: word.implicitHeight + Appearance.s.xxs * 2
    radius: Appearance.r.capsule(root.height)
    color: Appearance.c.raised
    border.width: Appearance.m.border
    border.color: Appearance.c.border

    Label {
        id: word
        anchors.centerIn: parent
        role: Label.Role.Caption
        font.weight: Font.Medium
        color: root.ink
    }
}
