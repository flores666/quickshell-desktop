pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/services"

/*! One presented card's arrival, expiry and exit. Layout never writes its
    visual slide, and an exit first stops anything else writing its opacity. */
NotificationCard {
    id: root

    required property var liveNotifications
    readonly property bool leaving: root.liveNotifications.indexOf(root.notification) === -1
    property bool ready: false
    property bool released: false
    signal exitRequested
    signal gone(var notification)

    readonly property int expiry: root.standalone ? Notifs.timeoutFor(root.notification) : 0
    opacity: 0
    enabled: !root.leaving
    transform: Translate {
        id: entrySlide
        x: root.standalone ? Appearance.m.notificationSlide : 0
    }

    Component.onCompleted: {
        root.ready = true;
        if (root.leaving) root.exitRequested();
        else arrive.start();
    }
    onLeavingChanged: if (root.ready && root.leaving) root.exitRequested()

    function retire(delay: int): bool {
        if (!root.leaving || root.released || exit.running) return false;
        // Read the same live snapshot that made this card leave. A separate
        // bound eviction flag can still hold its previous value when the
        // leaving binding fires (Clear all of a full, arriving stack).
        const unseen = root.standalone && root.liveNotifications.length === Notifs.maxPopups && arrive.running;
        arrive.stop();
        if (unseen || !root.visible) { root.release(); return false; }
        exit.delay = delay;
        exit.start();
        return true;
    }
    function release(): void {
        if (root.released) return;
        root.released = true;
        root.gone(root.notification);
    }

    ParallelAnimation {
        id: arrive
        NumberAnimation {
            target: entrySlide; property: "x"; to: 0
            duration: Appearance.t.base
            easing.type: Appearance.t.emphasizedEasing
        }
        NumberAnimation {
            target: root; property: "opacity"; to: 1
            duration: Appearance.t.base
            easing.type: Appearance.t.standardEasing
        }
    }
    NotificationExit {
        id: exit
        card: root
        slide: entrySlide
        onFinished: root.release()
    }
    Timer {
        running: root.expiry > 0 && !root.leaving
        interval: root.expiry
        onTriggered: Notifs.dismissPopup(root.notification)
    }
}
