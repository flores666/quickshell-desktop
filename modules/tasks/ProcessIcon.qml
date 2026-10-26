pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    A process's application icon: the icon of the desktop entry its name
    matches (Apps.byAppId, as the dock matches a window), and nothing where
    none does — the room stays, so names line up. Looked up as the name
    changes, which for a row kept by pid is once, not on every sample.
*/
Item {
    id: root

    property string name: ""

    readonly property var entry: root.name === "" ? null : Apps.byAppId(root.name)

    implicitWidth: Appearance.m.iconLg
    implicitHeight: Appearance.m.iconLg

    AppIcon {
        anchors.fill: parent
        visible: root.entry !== null
        source: root.entry?.icon ?? ""
        // An entry whose icon the theme lacks shows nothing, not a stand-in.
        fallbackIcon: ""
        size: Appearance.m.iconLg
    }
}
