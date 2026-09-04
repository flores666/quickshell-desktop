pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/services"

/*!
    A continuous slider.

    Emits moved() while dragging and committed() when the interaction ends, so
    callers can throttle expensive work (like writing to a device) to the end of
    a gesture if they need to.
*/
Item {
    id: root

    property real value: 0            // 0..1
    property real stepSize: 0.05
    property string icon: ""
    property color fillColor: Appearance.c.accent
    property bool interactive: true

    signal moved(real value)
    signal committed(real value)

    implicitWidth: 160
    implicitHeight: 32
    activeFocusOnTab: root.enabled && root.interactive
    opacity: root.enabled ? 1 : 0.42

    readonly property int trackHeight: 6
    readonly property int knobSize: 18
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
            color: root.fillColor
        }
    }

    Rectangle {
        id: knob
        x: root.leading + root.clamped * root.spanX
        width: root.knobSize
        height: root.knobSize
        anchors.verticalCenter: parent.verticalCenter
        radius: height / 2
        color: Appearance.c.surface
        border.width: 1
        border.color: Appearance.c.borderStrong
        scale: drag.pressed ? 1.12 : hover.hovered ? 1.06 : 1

        Behavior on scale {
            NumberAnimation { duration: Appearance.t.fast; easing.type: Appearance.t.standardEasing }
        }

        Shadow {
            anchors.fill: parent
            radius: parent.radius
            level: 1
        }
    }

    Rectangle {
        anchors.fill: knob
        anchors.margins: -3
        radius: width / 2
        color: "transparent"
        border.width: 2
        border.color: Appearance.c.accent
        visible: root.activeFocus && InputMode.keyboard
    }

    HoverHandler {
        id: hover
        enabled: root.enabled && root.interactive
        cursorShape: Qt.PointingHandCursor
    }

    MouseArea {
        id: drag
        anchors.fill: parent
        enabled: root.enabled && root.interactive
        preventStealing: true

        onPressed: event => {
            InputMode.pointerUsed();
            root.forceActiveFocus();
            root.setFromX(event.x);
        }
        onPositionChanged: event => {
            if (drag.pressed)
                root.setFromX(event.x);
        }
        onReleased: root.committed(root.clamped)
        onWheel: event => {
            const dir = event.angleDelta.y > 0 ? 1 : -1;
            const v = Math.max(0, Math.min(1, root.clamped + dir * root.stepSize));
            root.moved(v);
            root.committed(v);
        }
    }

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
