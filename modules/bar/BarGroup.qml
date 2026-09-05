pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"

/*!
    One of the bar's three areas: a shallow rounded well the controls sit in.

    The bar is one panel; these are what divide it into left, centre and right
    without a rule drawn anywhere. A single step of lift off the panel is all
    that marks them, which is what keeps them reading as parts of the bar rather
    than as widgets floating on top of it.
*/
Rectangle {
    id: root

    default property alias content: row.data

    implicitWidth: row.implicitWidth + Appearance.s.xxs * 2
    implicitHeight: Appearance.m.barItemHeight
    // One step in from the panel's corner, by the same inset that separates
    // them, so the two curves stay concentric.
    radius: Appearance.r.md
    color: Appearance.c.raised

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Appearance.s.xxs
    }
}
