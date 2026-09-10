pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"

/*! A labelled slider with an optional mute button and detail chevron. */
Item {
    id: root

    property string icon: ""
    property real value: 0
    property bool hasPage: false
    property bool toggleEnabled: false
    property bool muted: false

    signal moved(real value)
    signal iconClicked
    signal pageRequested

    implicitWidth: 300
    implicitHeight: 36

    IconButton {
        id: leading
        anchors.verticalCenter: parent.verticalCenter
        icon: root.icon
        size: 32
        enabled: root.toggleEnabled
        focusable: root.toggleEnabled
        hoverEnabled: root.toggleEnabled
        iconColor: root.muted ? Appearance.c.textMuted : Appearance.c.text
        onClicked: root.iconClicked()
    }

    Slider {
        anchors.verticalCenter: parent.verticalCenter
        x: leading.x + leading.width + Appearance.s.sm
        // Always stop where a chevron would be, whether or not this row has
        // one, so a stack of rows shares a right edge.
        width: trailing.x - x - Appearance.s.sm
        value: root.value
        fillColor: root.muted ? Appearance.c.textFaint : Appearance.c.accent
        onMoved: v => root.moved(v)
    }

    IconButton {
        id: trailing
        anchors.verticalCenter: parent.verticalCenter
        x: root.width - width
        visible: root.hasPage
        icon: "chevron-right"
        iconSize: Appearance.m.iconSm
        size: 30
        onClicked: root.pageRequested()
    }
}
