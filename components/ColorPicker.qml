pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/services"

/*!
    A colour picker: a saturation-value plane above a hue strip.

    It can be held to a band of saturation and value (see Appearance.seedRange),
    and then offers nothing outside it: the plane spans the band alone, so every
    point on it is a colour the caller accepts. Both are drawn as plain
    gradients, which is exact for HSV — a colour is its value times a blend of
    white and the pure hue by its saturation.

    Emits moved() while dragging and committed() when the gesture ends, as
    Slider does, and like Slider takes no wheel. The arrow keys move the knob
    of whichever part has focus.
*/
Column {
    id: root

    /*! The colour shown. Followed until the user takes hold of the picker. */
    property color value: "#808080"
    property var saturationRange: [0, 1]
    property var valueRange: [0, 1]

    signal moved(string value)
    signal committed(string value)

    property real hue: 0
    property real saturation: 0
    property real brightness: 0
    readonly property color current: Qt.hsva(root.hue, root.saturation, root.brightness, 1)
    readonly property bool dragging: planeArea.pressed || stripArea.pressed

    readonly property real sMin: root.saturationRange[0]
    readonly property real sSpan: root.saturationRange[1] - root.saturationRange[0]
    readonly property real vMin: root.valueRange[0]
    readonly property real vSpan: root.valueRange[1] - root.valueRange[0]
    readonly property color pureHue: Qt.hsva(root.hue, 1, 1, 1)
    readonly property real step: 0.02

    spacing: Appearance.s.md

    onValueChanged: root.sync()
    Component.onCompleted: root.sync()

    /*! Takes up `value`, unless it is only the echo of the picker's own. */
    function sync(): void {
        if (root.dragging || root.value.toString() === root.current.toString())
            return;
        // A grey has no hue; keeping the last one leaves the strip where it was.
        if (root.value.hsvHue >= 0)
            root.hue = root.value.hsvHue;
        root.saturation = root.clamp(root.value.hsvSaturation, root.saturationRange);
        root.brightness = root.clamp(root.value.hsvValue, root.valueRange);
    }

    function clamp(x: real, span: var): real {
        return Math.max(span[0], Math.min(span[1], x));
    }

    function tint(s: real): color {
        return Qt.rgba(1 - (1 - root.pureHue.r) * s, 1 - (1 - root.pureHue.g) * s,
            1 - (1 - root.pureHue.b) * s, 1);
    }

    function pickPlane(px: real, py: real): void {
        const fx = Math.max(0, Math.min(1, px / plane.width));
        const fy = Math.max(0, Math.min(1, py / plane.height));
        root.saturation = root.sMin + fx * root.sSpan;
        root.brightness = root.vMin + (1 - fy) * root.vSpan;
        root.moved(root.current.toString());
    }

    function pickHue(px: real): void {
        // Short of 1: hue 1 is hue 0 again, and would jump the knob back.
        root.hue = Math.max(0, Math.min(0.999, px / strip.width));
        root.moved(root.current.toString());
    }

    function nudge(event: var, apply: var): void {
        const dx = event.key === Qt.Key_Right ? 1 : event.key === Qt.Key_Left ? -1 : 0;
        const dy = event.key === Qt.Key_Up ? 1 : event.key === Qt.Key_Down ? -1 : 0;
        if (dx === 0 && dy === 0)
            return;
        InputMode.keyboardUsed();
        apply(dx * root.step, dy * root.step);
        root.moved(root.current.toString());
        root.committed(root.current.toString());
        event.accepted = true;
    }

    Rectangle {
        id: plane

        width: root.width
        height: Appearance.m.pickerPlane
        radius: Appearance.r.sm
        activeFocusOnTab: root.enabled
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: root.tint(root.sMin) }
            GradientStop { position: 1; color: root.tint(root.sMin + root.sSpan) }
        }

        Rectangle {
            // Darkens by 1 - value: the top edge is the band's brightest.
            anchors.fill: parent
            radius: parent.radius
            border.width: 1
            border.color: Appearance.c.border
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 1 - (root.vMin + root.vSpan)) }
                GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 1 - root.vMin) }
            }
        }

        PickerKnob {
            fill: root.current
            focused: plane.activeFocus
            x: (root.sSpan > 0 ? (root.saturation - root.sMin) / root.sSpan : 0) * plane.width - width / 2
            y: (root.vSpan > 0 ? 1 - (root.brightness - root.vMin) / root.vSpan : 0) * plane.height - height / 2
            pressed: planeArea.pressed
        }

        MouseArea {
            id: planeArea
            anchors.fill: parent
            preventStealing: true
            cursorShape: Qt.CrossCursor
            onPressed: event => {
                InputMode.pointerUsed();
                plane.forceActiveFocus();
                root.pickPlane(event.x, event.y);
            }
            onPositionChanged: event => root.pickPlane(event.x, event.y)
            onReleased: root.committed(root.current.toString())
        }

        Keys.onPressed: event => root.nudge(event, (dx, dy) => {
            root.saturation = root.clamp(root.saturation + dx * root.sSpan, root.saturationRange);
            root.brightness = root.clamp(root.brightness + dy * root.vSpan, root.valueRange);
        })
    }

    Rectangle {
        id: strip

        width: root.width
        height: Appearance.m.pickerStrip
        radius: height / 2
        activeFocusOnTab: root.enabled
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0 / 6; color: Qt.hsva(0 / 6, 1, 1, 1) }
            GradientStop { position: 1 / 6; color: Qt.hsva(1 / 6, 1, 1, 1) }
            GradientStop { position: 2 / 6; color: Qt.hsva(2 / 6, 1, 1, 1) }
            GradientStop { position: 3 / 6; color: Qt.hsva(3 / 6, 1, 1, 1) }
            GradientStop { position: 4 / 6; color: Qt.hsva(4 / 6, 1, 1, 1) }
            GradientStop { position: 5 / 6; color: Qt.hsva(5 / 6, 1, 1, 1) }
            GradientStop { position: 6 / 6; color: Qt.hsva(0, 1, 1, 1) }
        }

        PickerKnob {
            fill: root.pureHue
            focused: strip.activeFocus
            x: root.hue * strip.width - width / 2
            anchors.verticalCenter: parent.verticalCenter
            pressed: stripArea.pressed
        }

        MouseArea {
            id: stripArea
            anchors.fill: parent
            preventStealing: true
            cursorShape: Qt.PointingHandCursor
            onPressed: event => {
                InputMode.pointerUsed();
                strip.forceActiveFocus();
                root.pickHue(event.x);
            }
            onPositionChanged: event => root.pickHue(event.x)
            onReleased: root.committed(root.current.toString())
        }

        Keys.onPressed: event => root.nudge(event, (dx, dy) => {
            root.hue = Math.max(0, Math.min(0.999, root.hue + (dx + dy) * root.step));
        })
    }

    component PickerKnob: Rectangle {
        property color fill
        property bool focused: false
        property bool pressed: false

        width: Appearance.m.pickerKnob
        height: Appearance.m.pickerKnob
        radius: height / 2
        color: this.fill
        border.width: 2
        // Whichever theme's text reads on the colour under it: a knob on a
        // dark background plane would vanish in a surface-coloured ring.
        border.color: Appearance.luminance(this.fill) > 0.18
            ? Appearance.day.text : Appearance.night.text
        scale: this.pressed ? 1.15 : 1

        Behavior on scale {
            NumberAnimation { duration: Appearance.t.fast; easing.type: Appearance.t.standardEasing }
        }

        Shadow {
            anchors.fill: parent
            radius: parent.radius
            level: 1
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            radius: width / 2
            color: "transparent"
            border.width: 2
            border.color: Appearance.c.accent
            visible: parent.focused && InputMode.keyboard
        }
    }
}
