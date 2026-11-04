pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Quickshell
import Quickshell.Wayland
import "root:/components"

// Exercise the shared Clickable path with real Qt pointer and key events.
Item {
    id: root
    property int commits: 0
    Check { id: check }
    TestEvent { id: input }
    PanelWindow {
        implicitWidth: 360
        implicitHeight: 300
        WlrLayershell.namespace: "shell-drag-test"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        Flickable {
            id: scroll
            anchors.fill: parent
            contentHeight: 700
            Slider {
                id: slider
                width: 200
                value: 0.25
                onMoved: v => slider.value = v
                onCommitted: root.commits++
            }
            ColorPicker {
                id: picker
                y: 80; width: 200
                value: "#ff0000"
            }
        }
    }

    function exercise(): void {
        check.equal("slider accepts a press", input.mousePress(slider, 100, 16, Qt.LeftButton, Qt.NoModifier, -1), true);
        check.equal("press comes from Clickable", slider.pressed, true);
        check.equal("pointer focus has no ring", slider.focusVisible, false);
        input.mouseMove(slider, 190, 16, -1, Qt.LeftButton, Qt.NoModifier);
        input.mouseRelease(slider, 190, 16, Qt.LeftButton, Qt.NoModifier, -1);
        check.equal("slider follows the drag", slider.value > 0.9, true);
        check.equal("one commit on release", root.commits, 1);
        input.keyClick(Qt.Key_Home, Qt.NoModifier, -1);
        check.near("Home reaches zero", slider.value, 0);
        check.equal("keyboard focus has a ring", slider.focusVisible, true);
        input.keyClick(Qt.Key_Right, Qt.NoModifier, -1);
        check.near("arrow uses the slider step", slider.value, slider.stepSize);
        const plane = picker.children[0], strip = picker.children[1];
        input.mousePress(plane, 100, 56, Qt.LeftButton, Qt.NoModifier, -1);
        check.equal("picker press uses Clickable", plane.pressed && picker.dragging, true);
        input.mouseMove(plane, 200, 0, -1, Qt.LeftButton, Qt.NoModifier);
        input.mouseRelease(plane, 200, 0, Qt.LeftButton, Qt.NoModifier, -1);
        check.near("plane reaches full saturation", picker.saturation, 1);
        check.near("plane reaches full brightness", picker.brightness, 1);
        input.mousePress(strip, 100, 7, Qt.LeftButton, Qt.NoModifier, -1);
        input.mouseRelease(strip, 100, 7, Qt.LeftButton, Qt.NoModifier, -1);
        check.near("strip maps hue", picker.hue, 0.5);
        input.keyClick(Qt.Key_Right, Qt.NoModifier, -1);
        check.near("strip keyboard nudges hue", picker.hue, 0.52);
        check.equal("picker keyboard focus has a ring", strip.focusVisible, true);
        slider.enabled = false;
        check.equal("disabled state suppresses focus", slider.focusVisible, false);
        slider.enabled = true;
        input.mouseWheel(slider, 100, 16, Qt.NoButton, Qt.NoModifier, 0, -120, -1);
        check.near("wheel leaves slider value alone", slider.value, slider.stepSize);
        check.near("wheel leaves picker value alone", picker.hue, 0.52);
        frames.phase = 1;
        frames.ticks = 0;
        frames.running = true;
    }

    FrameAnimation {
        id: frames
        property int ticks: 0
        property int phase: 0
        running: true
        onTriggered: {
            if (++frames.ticks < 4) return;
            frames.running = false;
            if (frames.phase === 0) root.exercise();
            else {
                check.equal("wheel reaches the scrolling surface", scroll.contentY > 0, true);
                check.done();
            }
        }
    }
}
