pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"

/*! The carried card uses the window drag's lift, deformation and landing. */
QtObject {
    id: root

    required property bool animated
    property Item tile: null
    property bool held: false
    property point grab: Qt.point(0, 0)
    property point position: Qt.point(0, 0)
    property point landingFrom: Qt.point(0, 0)
    property point lastCursor: Qt.point(0, 0)
    property double lastMotion: 0
    property point velocity: Qt.point(0, 0)
    property real liftProgress: 0
    property real releaseProgress: 0
    property real decay: 0
    property real dropLift: 0
    readonly property WindowDrag style: Appearance.windowDrag
    readonly property real lift: !root.animated ? 0
        : root.held ? root.liftProgress : root.dropLift * Math.max(0, 1 - root.releaseProgress)

    function begin(tile: Item, grab: point, cursor: point, started: double): void {
        landing.stop();
        straighten.stop();
        root.tile = tile;
        root.grab = grab;
        root.lastCursor = cursor;
        root.lastMotion = started;
        root.velocity = Qt.point(0, 0);
        root.decay = 0;
        root.held = true;
        root.liftProgress = 0;
        if (root.animated)
            raise.restart();
    }

    function move(position: point, cursor: point): void {
        root.position = position;
        if (!root.animated || (cursor.x === root.lastCursor.x && cursor.y === root.lastCursor.y))
            return;
        const now = Date.now();
        const dt = Math.max(1, now - root.lastMotion);
        const mix = 1 - Math.exp(-dt / Math.max(1, root.style.settle / 9));
        const pace = 1000 / dt / root.style.velocity;
        const vx = root.velocity.x * root.decay * (1 - mix)
            + Math.max(-1, Math.min(1, (cursor.x - root.lastCursor.x) * pace)) * mix;
        const vy = root.velocity.y * root.decay * (1 - mix)
            + Math.max(-1, Math.min(1, (cursor.y - root.lastCursor.y) * pace)) * mix;
        const length = Math.max(1, Math.hypot(vx, vy));
        root.velocity = Qt.point(vx / length, vy / length);
        root.lastMotion = now;
        root.lastCursor = cursor;
        straighten.restart();
    }

    function release(baseScale: real): void {
        if (!root.held)
            return;
        raise.stop();
        root.landingFrom = Qt.point(root.position.x - baseScale * root.grab.x,
            root.position.y - baseScale * root.grab.y);
        root.dropLift = root.lift;
        root.releaseProgress = 0;
        root.held = false;
        if (root.animated)
            landing.restart();
        else
            root.tile = null;
    }

    function reset(): void {
        raise.stop();
        straighten.stop();
        landing.stop();
        root.held = false;
        root.tile = null;
    }

    function matrixFor(tile: Item, baseScale: real): matrix4x4 {
        // Resting cards scale about their top center; a held card pins the grip.
        const inset = (1 - baseScale) * tile.width / 2;
        if (root.tile !== tile)
            return Qt.matrix4x4(baseScale, 0, 0, inset, 0, baseScale, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1);
        const vx = root.animated ? root.velocity.x * root.decay : 0;
        const vy = root.animated ? root.velocity.y * root.decay : 0;
        const scale = baseScale * (1 + (root.style.scale - 1) * root.lift);
        const stretch = root.style.deformation * Math.hypot(vx, vy);
        const scaleX = scale * (1 + stretch * Math.abs(vx));
        const scaleY = scale * (1 + stretch * Math.abs(vy));
        const radians = vx * root.style.rotation * Math.PI / 180;
        const a = Math.cos(radians) * scaleX;
        const b = -Math.sin(radians) * scaleY;
        const c = Math.sin(radians) * scaleX;
        const d = Math.cos(radians) * scaleY;
        const x = root.held ? root.position.x - baseScale * root.grab.x - tile.x
            : inset + (root.landingFrom.x - tile.x - inset) * (1 - root.releaseProgress);
        const y = root.held ? root.position.y - baseScale * root.grab.y - tile.y
            : (root.landingFrom.y - tile.y) * (1 - root.releaseProgress);
        // Translate in the board's axes after deforming about the actual grip.
        return Qt.matrix4x4(a, b, 0, x + (baseScale - a) * root.grab.x - b * root.grab.y,
                           c, d, 0, y - c * root.grab.x + (baseScale - d) * root.grab.y,
                           0, 0, 1, 0, 0, 0, 0, 1);
    }

    readonly property NumberAnimation raise: NumberAnimation {
        target: root
        property: "liftProgress"
        from: 0
        to: 1
        duration: root.style.lift
        easing.type: Easing.BezierSpline
        easing.bezierCurve: root.style.smoothCurve
    }
    readonly property NumberAnimation straighten: NumberAnimation {
        target: root
        property: "decay"
        from: 1
        to: 0
        duration: root.style.settle
        easing.type: Easing.BezierSpline
        easing.bezierCurve: root.style.smoothCurve
    }
    readonly property NumberAnimation landing: NumberAnimation {
        target: root
        property: "releaseProgress"
        from: 0
        to: 1
        duration: root.style.landing
        easing.type: Easing.OutBack
        easing.overshoot: root.style.landingOvershoot
        onFinished: root.tile = null
    }
}
