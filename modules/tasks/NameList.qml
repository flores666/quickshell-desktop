pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"

/*!
    One of earlyoom's lists: the process names in it, each with a way out,
    and whatever was written into it by hand that is not a name, kept and
    shown as written, removable whole.
*/
Column {
    id: root

    property var names: []
    property string extra: ""
    property string empty: ""

    signal removed(string name)
    signal removedExtra

    spacing: Appearance.s.xs

    Repeater {
        model: root.names

        MenuRow {
            id: entry

            required property string modelData

            width: root.width
            flush: true
            title: this.modelData

            IconButton {
                icon: "remove"
                size: Appearance.m.touchTarget - Appearance.s.sm
                iconSize: Appearance.m.iconSm
                onClicked: root.removed(entry.modelData)
            }
        }
    }

    MenuRow {
        width: root.width
        visible: root.extra !== ""
        flush: true
        title: root.extra
        subtitle: qsTr("Written by hand")

        IconButton {
            icon: "remove"
            size: Appearance.m.touchTarget - Appearance.s.sm
            iconSize: Appearance.m.iconSm
            onClicked: root.removedExtra()
        }
    }

    Label {
        width: root.width
        visible: root.names.length === 0 && root.extra === ""
        text: root.empty
        role: Label.Role.Small
        muted: true
        wrapMode: Text.Wrap
    }
}
