pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"

/*! Connectivity cards and compact modes share independent main/detail targets. */
Item {
    id: root
    property string icon: ""
    property string title: ""
    property string status: ""
    property bool active: false
    property bool busy: false
    property bool hasPage: false
    property bool toggleEnabled: true
    property bool compact: false
    signal toggled
    signal pageRequested

    readonly property color ink: root.active && root.enabled ? PopupStyle.tileAccent.ink : Appearance.c.text
    readonly property color iconInk: root.enabled && root.toggleEnabled ? root.ink : Appearance.c.textMuted
    implicitWidth: Appearance.m.qsTileWidth
    implicitHeight: Math.max(root.compact ? Appearance.m.qsModeHeight : Appearance.m.qsTileHeight,
        caption.implicitHeight + Appearance.s.md * 2)

    Clickable {
        id: main
        objectName: "toggle"
        anchors.fill: parent
        radius: Appearance.r.lg
        hoverEnabled: root.toggleEnabled
        pressEnabled: root.toggleEnabled
        focusable: root.toggleEnabled
        selected: root.active
        showStateLayer: !root.active || main.hovered || main.pressed
        background: root.active && root.enabled ? PopupStyle.tileAccent.fill : PopupStyle.wash
        Accessible.role: Accessible.CheckBox
        Accessible.name: root.title
        Accessible.description: root.status
        Accessible.checkable: root.toggleEnabled
        Accessible.checked: root.active
        onClicked: if (root.enabled && root.toggleEnabled) root.toggled()

        GlassFinish {
            anchors.fill: parent
            radius: main.radius
            borderWidth: Appearance.m.border
            opacity: Appearance.popupOpacity
        }

        Item {
            id: glyph
            x: Appearance.s.md
            anchors.verticalCenter: parent.verticalCenter
            width: Appearance.m.icon
            height: Appearance.m.touchTarget
            Icon {
                objectName: "deviceIcon"
                anchors.centerIn: parent
                visible: !root.busy
                name: root.icon
                size: Appearance.m.icon
                color: root.iconInk
            }
            Spinner {
                anchors.centerIn: parent
                visible: root.busy
                size: Appearance.m.icon
                color: root.iconInk
            }
        }

        Column {
            id: caption
            anchors.verticalCenter: parent.verticalCenter
            x: glyph.x + glyph.width + Appearance.s.sm
            width: (root.hasPage ? chevron.x : parent.width - Appearance.s.md) - x
            spacing: Appearance.s.xxs

            Label {
                width: parent.width
                text: root.title
                role: Label.Role.Caption
                color: root.ink
                wrapMode: Text.Wrap
                elide: Text.ElideNone
            }

            Label {
                width: parent.width
                visible: !root.compact && root.status !== ""
                text: root.status
                role: Label.Role.Caption
                color: root.ink
            }
        }
    }

    QsIconButton {
        id: chevron
        objectName: "details"
        x: root.width - width - Appearance.s.sm
        anchors.verticalCenter: parent.verticalCenter
        visible: root.hasPage
        icon: "chevron-right"
        label: qsTr("%1 details").arg(root.title)
        tipBelow: true
        iconSize: Appearance.m.iconSm
        size: Appearance.m.compactButton
        iconColor: root.ink
        onClicked: root.pageRequested()
    }
}
