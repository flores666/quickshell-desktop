pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"

/*!
    One of the bar's end groups: the controls that belong together, in a row.

    Nothing is drawn behind it. The bar is a slim capsule, and a well inside it
    would only be a second, smaller capsule; the gap between the groups is what
    divides it, and each control's own hover wash — a capsule concentric with
    the bar's ends — is what shows its extent.
*/
Item {
    id: root

    default property alias content: row.data

    implicitWidth: row.implicitWidth
    implicitHeight: Appearance.m.barItemHeight

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Appearance.s.xxs
    }
}
