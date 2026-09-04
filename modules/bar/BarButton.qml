pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"

/*! A pill-shaped item in the top bar. Content goes in as children. */
Clickable {
    id: root

    property int padding: Appearance.s.md
    property alias contentItem: content
    default property alias barContent: content.data

    implicitWidth: content.implicitWidth + root.padding * 2
    implicitHeight: Appearance.m.barItemHeight
    radius: Appearance.r.full
    focusable: false

    /*! Horizontal centre of this button in its window's coordinates. */
    function windowCenterX(): real {
        const surface = root.QsWindow.contentItem;
        return surface ? root.mapToItem(surface, root.width / 2, 0).x : 0;
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: Appearance.s.sm
    }
}
