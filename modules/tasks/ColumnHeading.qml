pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"

/*!
    A column's heading in the process list: a click sorts by it, again the
    other way, and the column it sorts by carries an arrow.
*/
Clickable {
    id: root

    property string title: ""
    property bool alignRight: true
    property bool active: false
    property bool descending: true

    implicitHeight: Appearance.m.fieldHeight - Appearance.s.sm
    radius: Appearance.r.sm

    Row {
        anchors.verticalCenter: parent.verticalCenter
        x: root.alignRight ? root.width - width - Appearance.s.sm : Appearance.s.sm
        spacing: Appearance.s.xxs
        layoutDirection: root.alignRight ? Qt.RightToLeft : Qt.LeftToRight

        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: root.title
            role: Label.Role.Small
            font.weight: root.active ? Font.DemiBold : Font.Normal
            muted: !root.active
        }

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.active
            name: root.descending ? "chevron-down" : "chevron-up"
            size: Appearance.m.iconSm
            color: Appearance.c.textMuted
        }
    }
}
