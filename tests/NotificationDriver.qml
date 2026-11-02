pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/modules/notifications"

/*! Real protocol delivery on the test runner's private bus. No fake
    notifications: the cards must exercise Quickshell's retention. */
Item {
    id: root

    readonly property bool isolated: Quickshell.env("TEST_NOTIFICATION_BUS") === "private"
    readonly property var address: ["gdbus", "call", "--session", "--dest",
        "org.freedesktop.Notifications", "--object-path", "/org/freedesktop/Notifications", "--method"]
    property var pending: null
    property var delayed: null

    Process {
        id: client
        stderr: StdioCollector {
            onStreamFinished: if (this.text.trim() !== "") console.warn("Notification client:", this.text)
        }
        stdout: StdioCollector {
            onStreamFinished: {
                const then = root.pending;
                root.pending = null;
                if (then !== null) then(this.text);
            }
        }
    }
    Timer {
        id: delay
        onTriggered: { const then = root.delayed; root.delayed = null; then(); }
    }
    function after(ms: int, then: var): void {
        root.delayed = then;
        delay.interval = ms;
        delay.start();
    }
    function send(summary: string, then: var, hints: string, actions: string, replace: int): void {
        if (!root.isolated) throw new Error("NotificationDriver requires a private test bus");
        root.pending = text => then(Number(/uint32 (\d+)/.exec(text)?.[1] ?? 0));
        client.command = root.address.concat(["org.freedesktop.Notifications.Notify",
            "Notification test", String(replace), "dialog-information", JSON.stringify(summary),
            JSON.stringify("A wrapped notification body with enough text to check stable card geometry."),
            actions || "[]", hints || "{}", "5000"]);
        client.running = true;
    }
    function many(names: var, then: var): void {
        if (names.length === 0) { then(); return; }
        root.send(names[0], () => root.many(names.slice(1), then), "{}", "[]", 0);
    }
    function withdraw(id: int, then: var): void {
        root.pending = then;
        client.command = root.address.concat(["org.freedesktop.Notifications.CloseNotification", String(id)]);
        client.running = true;
    }
    function find(item: Item, predicate: var): var {
        const found = [];
        function visit(child) {
            if (predicate(child)) found.push(child);
            for (const descendant of child.children) visit(descendant);
        }
        visit(item);
        return found;
    }
    function cards(item: Item): var {
        return root.find(item, child => child instanceof NotificationCard);
    }
}
