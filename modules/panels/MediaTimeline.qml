pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/components"
import "root:/config"
import "root:/services"

/*! Track changes and seeks share one presentation animation. Actual values
    remain current for dispatch; the playback clock advances without easing. */
Slider {
    id: root

    property bool tracking: false
    readonly property bool animating: motion.running
    readonly property PlayerState subject: Players.selected
    readonly property var track: root.subject ? root.subject.track : null
    readonly property bool holding: root.tracking && root.visible && root.subject !== null
        && root.shownKey !== "" && root.subject.changing
    property PlayerState shownSubject: null
    property string shownKey: ""
    property real lastValue: 0
    property real animatedValue: 0
    property bool initialized: false
    property bool clockUpdating: false
    property bool valuePending: false

    displayed: Math.max(0, Math.min(1, root.animatedValue))
    onClampedChanged: {
        if (!root.clockUpdating) root.valuePending = true;
        Qt.callLater(root.sync);
    }
    onSubjectChanged: Qt.callLater(root.sync)
    onTrackChanged: Qt.callLater(root.sync)
    onHoldingChanged: Qt.callLater(root.sync)
    onTrackingChanged: {
        if (root.initialized) {
            if (root.tracking) root.readClock();
            root.snap();
        }
    }
    onVisibleChanged: {
        if (root.initialized) {
            if (root.visible && root.tracking) root.readClock();
            root.snap();
        }
    }
    Component.onCompleted: {
        if (root.tracking) root.readClock();
        root.snap();
    }

    function snap(): void {
        const subject = Players.selected;
        const supported = subject && subject.player && subject.player.positionSupported && subject.track.length > 0;
        const value = supported ? root.clamped : 0;
        motion.stop();
        root.animatedValue = value;
        root.lastValue = value;
        root.shownSubject = subject;
        root.shownKey = subject?.track.key ?? "";
        root.valuePending = false;
        root.initialized = true;
    }

    function readClock(): void {
        root.clockUpdating = true;
        Players.refreshPosition();
        // Force the dependent bindings while this event is still identified
        // as a local clock read, rather than a seek from the player.
        const value = root.clamped;
        root.clockUpdating = false;
        if (!root.valuePending && !root.holding && !root.animating
            && root.subject === root.shownSubject && (root.track?.key ?? "") === root.shownKey) {
            root.animatedValue = value;
            root.lastValue = value;
        }
    }

    function sync(): void {
        // Metadata, length and position bindings do not update together.
        // Coalesce their notifications before deciding whether the track changed.
        if (root.holding) {
            motion.stop();
            root.valuePending = false;
            return;
        }
        const key = root.track?.key ?? "";
        const changed = root.subject !== root.shownSubject || key !== root.shownKey;
        if (root.initialized && root.shownKey !== "" && key !== ""
            && (changed || (root.valuePending && root.clamped !== root.lastValue))
            && root.tracking && root.visible && root.animatedValue !== root.clamped) {
            motion.to = root.clamped;
            // SmoothedAnimation retains velocity across restarts. Never stop
            // or assign its value first: rapid drags would lose continuity.
            motion.restart();
        } else if (!root.animating || !root.tracking || !root.visible) {
            root.snap();
            return;
        }
        root.shownSubject = root.subject;
        root.shownKey = key;
        root.lastValue = root.clamped;
        root.valuePending = false;
        root.initialized = true;
    }

    SmoothedAnimation {
        id: motion
        target: root
        property: "animatedValue"
        duration: Appearance.t.mediaChange
        velocity: -1
        maximumEasingTime: Appearance.t.mediaEasingTime
        reversingMode: SmoothedAnimation.Immediate
    }

    // Only reads Quickshell's local extrapolation; never queries the player.
    SystemClock {
        enabled: root.visible && root.tracking && Players.playing && Players.length > 0
            && Players.hasPlayer && Players.current.positionSupported && !root.animating && !root.holding
        precision: SystemClock.Seconds
        onDateChanged: root.readClock()
    }
}
