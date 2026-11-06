pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"

/*! Capsule with independent mute/device actions and a real backend readout. */
Item {
    id: root
    property string icon: ""
    property string label: ""
    property real value: 0
    property bool hasPage: false
    property bool toggleEnabled: false
    property bool muted: false
    readonly property color controlColor: root.muted || !root.enabled
        ? Appearance.c.textMuted : PopupStyle.indicator
    signal moved(real value)
    signal iconClicked
    signal pageRequested

    implicitWidth: Appearance.m.qsRowWidth
    implicitHeight: Math.max(Appearance.m.qsRowHeight, percentage.implicitHeight + Appearance.s.md * 2)

    Rectangle {
        anchors.fill: parent
        radius: Appearance.r.capsule(height)
        color: PopupStyle.wash
    }

    QsIconButton {
        id: leadingButton
        objectName: "mute"
        x: Appearance.s.xs
        anchors.verticalCenter: parent.verticalCenter
        visible: root.toggleEnabled
        icon: root.icon
        label: root.muted ? qsTr("Unmute %1").arg(root.label) : qsTr("Mute %1").arg(root.label)
        size: Appearance.m.touchTarget
        iconColor: root.enabled ? Appearance.c.text : Appearance.c.textMuted
        Accessible.checkable: true
        Accessible.checked: root.muted
        onClicked: root.iconClicked()
    }

    Icon {
        x: leadingButton.x + (leadingButton.width - width) / 2
        anchors.verticalCenter: parent.verticalCenter
        visible: !root.toggleEnabled
        name: root.icon
        size: Appearance.m.icon
        color: root.enabled ? Appearance.c.text : Appearance.c.textDisabled
    }

    Slider {
        id: slider
        objectName: "level"
        anchors.verticalCenter: parent.verticalCenter
        x: leadingButton.x + leadingButton.width + Appearance.s.sm
        width: Math.max(0, percentage.x - x - Appearance.s.md)
        value: root.value
        fillColor: root.controlColor
        knobColor: root.controlColor
        Accessible.role: Accessible.Slider
        Accessible.name: root.label
        Accessible.description: !root.enabled ? qsTr("Unavailable")
            : root.muted ? qsTr("%1 · Muted").arg(percentage.text) : percentage.text
        readonly property real minimumValue: 0
        readonly property real maximumValue: 1
        onMoved: v => root.moved(v)
    }

    Label {
        id: percentage
        objectName: "percentage"
        x: trailing.x - width - Appearance.s.xs
        width: Math.max(implicitWidth, Appearance.m.qsPercentageWidth * Appearance.font.scale)
        anchors.verticalCenter: parent.verticalCenter
        text: root.enabled ? qsTr("%1%").arg(Math.round(root.value * 100)) : qsTr("—")
        role: Label.Role.Caption
        color: !root.enabled ? Appearance.c.textDisabled
            : root.muted ? Appearance.c.textMuted : PopupStyle.muted
        horizontalAlignment: Text.AlignRight
    }

    QsIconButton {
        id: trailing
        objectName: "devices"
        anchors.verticalCenter: parent.verticalCenter
        x: root.width - width - Appearance.s.xs
        visible: root.hasPage
        icon: "chevron-right"
        label: qsTr("%1 devices").arg(root.label)
        iconSize: Appearance.m.iconSm
        size: Appearance.m.qsChevron
        onClicked: root.pageRequested()
    }
}
