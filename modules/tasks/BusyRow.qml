pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"

/*!
    One process in a "most" list (RankedList): its application's icon where
    one matches, its name, and its figure at the right (`format`). One that
    went quiet within the minute, ranked still for what it did, is drawn
    muted: its text muted, its icon faded.

    `entry` is one of `Activity.top`'s, `{ pid, name, value, now }`.
*/
Item {
    id: root

    property var entry: null
    property var format: v => String(v)

    readonly property bool quiet: !(root.entry?.now ?? true)

    implicitHeight: Appearance.m.touchTarget

    ProcessIcon {
        id: icon
        anchors.verticalCenter: parent.verticalCenter
        name: root.entry?.name ?? ""
        opacity: root.quiet ? Appearance.m.quiet : 1
    }

    Label {
        anchors.verticalCenter: parent.verticalCenter
        x: icon.width + Appearance.s.md
        width: figure.x - x - Appearance.s.md
        text: root.entry?.name ?? ""
        muted: root.quiet
    }

    Label {
        id: figure
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: root.entry ? root.format(root.entry.value) : ""
        role: Label.Role.Small
        muted: root.quiet
        font.features: { "tnum": 1 }
    }
}
