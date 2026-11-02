pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/services"

/*! Live notifications plus the cards still exiting, in their held slots.
    Both history and toasts share this lifecycle; their surface and scrolling
    remain with the caller. History is bounded to Notifs.maxHistory. */
Column {
    id: root

    required property var notifications
    property bool standalone: false
    property var shown: []
    property bool ready: false

    spacing: Appearance.s.md
    // Keep the bottom row in the scrollable extent throughout its move.
    // Otherwise a shrinking contentHeight clamps a bottom-scrolled viewport
    // to the final height before the rows have reached it.
    height: Math.max(implicitHeight, childrenRect.y + childrenRect.height)

    function reconcile(): void {
        const out = root.notifications.filter(n => n);
        let behind = -1;
        for (const n of root.shown) {
            if (!n) continue;
            const at = out.indexOf(n);
            if (at !== -1) behind = at;
            else out.splice(++behind, 0, n);
        }
        root.shown = out;
    }
    function forget(n: var): void {
        if (root.notifications.indexOf(n) !== -1) return;
        root.shown = root.shown.filter(item => item && item !== n);
    }
    Component.onCompleted: { root.ready = true; root.reconcile(); }
    onNotificationsChanged: if (root.ready) root.reconcile()

    move: Transition {
        NumberAnimation {
            property: "y"
            duration: Appearance.t.resize
            easing.type: Appearance.t.standardEasing
        }
    }
    Repeater {
        model: ScriptModel {
            values: root.shown
            comparisonMode: ObjectComparison.Identity
        }
        NotificationEntry {
            id: entry
            required property var modelData
            width: root.width
            notification: entry.modelData
            standalone: root.standalone
            liveNotifications: root.notifications
            onDismissed: {
                if (root.standalone) Notifs.dismissPopup(entry.modelData);
                else Notifs.remove(entry.modelData);
            }
            // Leave the signal handler before destroying its card and lock.
            // A distinct closure preserves every simultaneous completion.
            onGone: n => Qt.callLater(() => root.forget(n))
        }
    }
}
