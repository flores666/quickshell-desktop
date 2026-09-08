pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

/*!
    The notification server, its live toast queue and its history.

    Tracked notifications are owned by the server, so history survives an app
    exiting and there are no dangling references to manage here.  Every field an
    application supplies is treated as untrusted: text is clamped, markup is
    stripped for the toast, and a broken image URL falls back to the app icon.
*/
Singleton {
    id: root

    readonly property bool doNotDisturb: Settings.doNotDisturb

    /*! Newest first. */
    readonly property var history: server.trackedNotifications.values
        .filter(n => n).slice().reverse()
    readonly property int count: root.history.length

    /*! Notifications currently shown as toasts, newest last. */
    property var popups: []

    readonly property int maxHistory: 64
    readonly property int maxPopups: 3
    /*! How long a toast with no timeout of its own stays up. Clamped to the
        same range an application's own expireTimeout is held to below. */
    readonly property int defaultTimeout: Settings.notificationTimeout < 0
        ? 5000 : Math.max(1500, Math.min(30000, Settings.notificationTimeout))

    signal notified(var notification)

    /*! Arrival timestamps, keyed by notification id: the protocol carries none. */
    property var arrivals: ({})

    /*!
        A human-readable age. Takes the current time as an argument so callers
        get a binding that refreshes with the shell clock instead of going stale.
    */
    function relativeLabel(n: var, now: date): string {
        const at = root.arrivals[n?.id];
        if (!at)
            return "";
        const mins = Math.floor((now.getTime() - at) / 60000);
        if (mins < 1)
            return qsTr("now");
        if (mins < 60)
            return qsTr("%1 min ago").arg(mins);
        const hours = Math.floor(mins / 60);
        if (hours < 24)
            return qsTr("%1 hr ago").arg(hours);
        return Qt.formatDateTime(new Date(at), "ddd HH:mm");
    }

    function isCritical(n: var): bool {
        return n && n.urgency === NotificationUrgency.Critical;
    }

    /*! Milliseconds a toast should live, or 0 to require an explicit dismiss. */
    function timeoutFor(n: var): int {
        if (!n || root.isCritical(n))
            return 0;
        if (n.expireTimeout > 0)
            return Math.max(1500, Math.min(30000, n.expireTimeout));
        return root.defaultTimeout;
    }

    function dismissPopup(n: var): void {
        const next = root.popups.filter(p => p && p !== n);
        if (next.length !== root.popups.length)
            root.popups = next;
        // Transient notifications exist only as a toast; once it is gone, so are
        // they. Anything else stays in history.
        if (n && n.transient)
            n.tracked = false;
    }

    function remove(n: var): void {
        if (!n)
            return;
        root.dismissPopup(n);
        n.dismiss();
        n.tracked = false;
    }

    function clearAll(): void {
        root.popups = [];
        for (const n of root.history)
            if (n)
                n.tracked = false;
    }

    function invoke(n: var, action: var): void {
        if (!n || !action)
            return;
        action.invoke();
        root.remove(n);
    }

    /*! Body text with the small HTML subset the spec allows reduced to plain text. */
    function plainBody(n: var): string {
        const raw = String(n?.body ?? "");
        if (raw === "")
            return "";
        return raw
            .replace(/<br\s*\/?>/gi, "\n")
            .replace(/<\/?[^>]{0,120}>/g, "")
            .replace(/&lt;/g, "<").replace(/&gt;/g, ">")
            .replace(/&amp;/g, "&").replace(/&quot;/g, "\"").replace(/&apos;/g, "'")
            .trim()
            .slice(0, 1200);
    }

    function summaryOf(n: var): string {
        const s = String(n?.summary ?? "").trim().slice(0, 200);
        return s !== "" ? s : String(n?.appName ?? "").trim().slice(0, 200);
    }

    function actionsOf(n: var): var {
        const list = n?.actions ?? [];
        // The spec's "default" action is what activating the body does; it is
        // never rendered as a button.
        return list.filter(a => a && a.identifier !== "default" && String(a.text ?? "") !== "")
            .slice(0, 3);
    }

    function defaultActionOf(n: var): var {
        return (n?.actions ?? []).find(a => a && a.identifier === "default") ?? null;
    }

    function activate(n: var): void {
        const def = root.defaultActionOf(n);
        if (def)
            root.invoke(n, def);
        else
            root.remove(n);
    }

    NotificationServer {
        id: server

        keepOnReload: false
        actionsSupported: true
        actionIconsSupported: false
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: false
        bodyImagesSupported: false
        imageSupported: true
        persistenceSupported: true
        inlineReplySupported: false

        onNotification: notification => {
            if (!notification)
                return;

            notification.tracked = true;
            root.arrivals[notification.id] = Date.now();
            root.notified(notification);

            // Transient notifications (progress popups and the like) are shown
            // but deliberately never kept in history.
            const showToast = !root.doNotDisturb || root.isCritical(notification);
            if (showToast) {
                const list = root.popups.filter(p => p);
                list.push(notification);
                root.popups = list.slice(-root.maxPopups);
            }
            if (notification.transient && !showToast)
                notification.tracked = false;
        }
    }

    Connections {
        target: server.trackedNotifications

        function onValuesChanged(): void {
            // Drop toasts whose notification the server no longer owns, and trim
            // history to a bounded size so a chatty app cannot grow it forever.
            const live = server.trackedNotifications.values;
            const pruned = root.popups.filter(p => p && live.indexOf(p) !== -1);
            if (pruned.length !== root.popups.length)
                root.popups = pruned;

            if (live.length > root.maxHistory)
                for (const n of live.slice(0, live.length - root.maxHistory))
                    if (n)
                        n.tracked = false;

            // Keep the arrival map from growing past the notifications it describes.
            if (Object.keys(root.arrivals).length > root.maxHistory * 2) {
                const keep = ({});
                for (const n of live)
                    if (n && n.id in root.arrivals)
                        keep[n.id] = root.arrivals[n.id];
                root.arrivals = keep;
            }
        }
    }
}
