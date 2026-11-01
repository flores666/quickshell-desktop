pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/services"

/*! One icon's response to the wave. An explicit animation also retimes a
    transition already in progress: a Behavior snapshots its duration when
    it starts and otherwise keeps that old duration until the next target. */
QtObject {
    id: root

    property real targetScale: 1
    property real value: 1
    readonly property int duration: Dock.magnificationDuration
    property bool ready: false

    onTargetScaleChanged: if (root.ready) root.retarget()
    onDurationChanged: if (root.ready && motion.running) root.retarget()
    Component.onCompleted: {
        root.ready = true;
        root.retarget();
    }

    function retarget(): void {
        motion.stop();
        if (root.value === root.targetScale)
            return;
        // Set these together before starting the job, so neither a target nor
        // a duration change can read a binding that has not caught up yet.
        motion.from = root.value;
        motion.to = root.targetScale;
        motion.duration = root.duration;
        motion.start();
    }

    readonly property NumberAnimation animation: NumberAnimation {
        id: motion
        target: root
        property: "value"
        easing.type: Appearance.t.emphasizedEasing
    }
}
