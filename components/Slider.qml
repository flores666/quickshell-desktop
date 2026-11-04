pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/services"

/*!
    A continuous slider. Dragged with the pointer, or moved with the arrow keys
    when it has focus.

    Emits moved() while dragging and committed() when the interaction ends, so
    callers can throttle expensive work (like writing to a device) to the end of
    a gesture if they need to.

    No wheel handler, deliberately: a wheel belongs to whatever surface is
    scrolling, and a slider that took it would change a value under a pointer
    that was only passing over it.
*/
Clickable {
    id: root

    property real value: 0            // 0..1
    property real stepSize: 0.05
    property string icon: ""
    property color fillColor: Appearance.c.accent
    property bool interactive: true

    signal moved(real value)
    signal committed(real value)

    implicitWidth: Appearance.m.sliderWidth
    implicitHeight: Appearance.m.touchTarget
    focusable: root.interactive
    hoverEnabled: root.interactive
    pressEnabled: root.interactive
    acceptedButtons: root.interactive ? Qt.LeftButton : Qt.NoButton
    preventStealing: true
    showStateLayer: false
    focusRingTarget: knob
    focusRingRadius: root.knobSize / 2
    focusRingGap: Appearance.m.knobFocusGap

    readonly property int trackHeight: Appearance.m.sliderTrack
    readonly property int knobSize: Appearance.m.sliderKnob
    readonly property real leading: root.icon !== "" ? Appearance.m.iconLg + Appearance.s.lg : 0
    readonly property real spanX: root.width - root.leading - root.knobSize
    readonly property real clamped: Math.max(0, Math.min(1, root.value))

    function setFromX(px: real): void {
        if (root.spanX <= 0)
            return;
        const v = (px - root.leading - root.knobSize / 2) / root.spanX;
        root.moved(Math.max(0, Math.min(1, v)));
    }

    Icon {
        id: leadIcon
        anchors.verticalCenter: parent.verticalCenter
        visible: root.icon !== ""
        name: root.icon
        size: Appearance.m.iconLg
        color: Appearance.c.textMuted
    }

    Rectangle {
        id: track
        x: root.leading
        width: root.width - root.leading
        height: root.trackHeight
        anchors.verticalCenter: parent.verticalCenter
        radius: height / 2
        color: Appearance.c.sunken

        Rectangle {
            width: Math.max(parent.height, root.knobSize / 2 + root.clamped * root.spanX)
            height: parent.height
            radius: height / 2
            // Disabled reads as off, not as a faded accent: the same grey a
            // muted row uses.
            color: root.enabled ? root.fillColor : Appearance.c.textFaint
        }
    }

    Rectangle {
        id: knob
        x: root.leading + root.clamped * root.spanX
        width: root.knobSize
        height: root.knobSize
        anchors.verticalCenter: parent.verticalCenter
        radius: height / 2
        color: Appearance.c.knob
        border.width: Appearance.m.controlBorder
        border.color: Appearance.c.border
        scale: root.pressed ? Appearance.m.sliderPressedScale : root.hovered ? Appearance.m.sliderHoverScale : 1

        Behavior on scale {
            NumberAnimation { duration: Appearance.t.fast; easing.type: Appearance.t.standardEasing }
        }

        Shadow {
            anchors.fill: parent
            radius: parent.radius
            level: 1
        }
    }

    onPointerPressed: event => root.setFromX(event.x)
    onPointerMoved: event => {
        if (root.pressed)
            root.setFromX(event.x);
    }
    onPointerReleased: root.committed(root.clamped)

    Keys.onPressed: event => {
        let v = root.clamped;
        if (event.key === Qt.Key_Left || event.key === Qt.Key_Down)
            v -= root.stepSize;
        else if (event.key === Qt.Key_Right || event.key === Qt.Key_Up)
            v += root.stepSize;
        else if (event.key === Qt.Key_Home)
            v = 0;
        else if (event.key === Qt.Key_End)
            v = 1;
        else
            return;

        InputMode.keyboardUsed();
        v = Math.max(0, Math.min(1, v));
        root.moved(v);
        root.committed(v);
        event.accepted = true;
    }
}
