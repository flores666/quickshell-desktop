pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/services"

/*! The real server's close/action/transient semantics, including an object
    retained by presentation after the server has closed it. */
Item {
    id: root
    Check { id: check }
    NotificationDriver { id: driver }
    property var held: null
    property int closed: 0
    RetainableLock { object: root.held; locked: true }

    Component.onCompleted: {
        check.equal("service test has a private bus", driver.isolated, true);
        if (!driver.isolated) { check.done(); return; }
        check.equal("private server starts empty", Notifs.count, 0);
        driver.send("Default action", root.defaultAction, "{}", "['default', 'Open', 'reply', 'Reply']", 0);
    }
    function defaultAction(id: int): void {
        check.equal("delivery returns a real notification id", id > 0, true);
        root.held = Notifs.history[0];
        root.held.closed.connect(() => root.closed++);
        check.equal("default action is not rendered as a second button", Notifs.actionsOf(root.held).length, 1);
        const action = Notifs.defaultActionOf(root.held);
        Notifs.activate(root.held);
        check.equal("default action closes a nonresident notification", Notifs.count, 0);
        check.equal("default action clears its toast", Notifs.popups.length, 0);
        check.equal("closed content stays available to presentation", root.held?.summary, "Default action");
        check.equal("retained closed notification is no longer actionable", Notifs.isOpen(root.held), false);
        Notifs.remove(root.held);
        Notifs.invoke(root.held, action);
        check.equal("repeated operations do not close again", root.closed, 1);
        root.held = null;
        driver.send("Resident", root.resident, "{'resident': <true>}", "['default', 'Open']", 0);
    }
    function resident(id: int): void {
        const n = Notifs.history[0];
        Notifs.activate(n);
        check.equal("resident action preserves history", Notifs.count, 1);
        check.equal("resident notification stays actionable", Notifs.isOpen(n), true);
        check.equal("resident action dismisses the toast", Notifs.popups.length, 0);
        Notifs.remove(n);
        driver.send("Critical", root.critical, "{'urgency': <byte 2>}", "[]", 0);
    }
    function critical(id: int): void {
        const n = Notifs.history[0];
        check.equal("critical notifications do not auto-expire", Notifs.timeoutFor(n), 0);
        Notifs.dismissPopup(n);
        check.equal("toast dismissal preserves ordinary history", Notifs.count, 1);
        Notifs.clearAll();
        check.equal("Clear all includes critical notifications", Notifs.count, 0);
        driver.send("Transient", () => {
            Notifs.dismissPopup(Notifs.history[0]);
            check.equal("transient toast dismissal removes history", Notifs.count, 0);
            driver.send("Withdrawn", root.withdrawn, "{}", "[]", 0);
        }, "{'transient': <true>}", "[]", 0);
    }
    function withdrawn(id: int): void {
        root.held = Notifs.history[0];
        driver.withdraw(id, () => {
            check.equal("application withdrawal removes history", Notifs.count, 0);
            check.equal("application withdrawal removes toast", Notifs.popups.length, 0);
            check.equal("withdrawal retains original content until presentation releases it", root.held?.summary, "Withdrawn");
            root.held = null;
            driver.send("Original", root.replacement, "{}", "[]", 0);
        });
    }
    function replacement(id: int): void {
        root.held = Notifs.history[0];
        driver.send("Updated", () => {
            check.equal("replacement keeps the notification object", Notifs.history[0], root.held);
            check.equal("replacement updates content", root.held?.summary, "Updated");
            check.equal("replacement does not duplicate history", Notifs.count, 1);
            check.equal("replacement does not duplicate the toast", Notifs.popups.length, 1);
            Notifs.activate(root.held);
            check.equal("card activation without an action dismisses", Notifs.count, 0);
            root.held = null;
            Notifs.clearAll();
            check.equal("clearing an empty history is harmless", Notifs.count, 0);
            driver.many(Array.from({length: Notifs.maxHistory + 3}, (_, i) => "Bound " + i), () => {
                check.equal("history remains bounded during a burst", Notifs.count, Notifs.maxHistory);
                check.equal("bounded history keeps the newest notification", Notifs.history[0]?.summary, "Bound " + (Notifs.maxHistory + 2));
                check.equal("a burst keeps only the newest live toasts", Notifs.popups.length, Notifs.maxPopups);
                Notifs.clearAll();
                check.equal("Clear all removes a full history", Notifs.count, 0);
                check.done();
            });
        }, "{}", "[]", id);
    }
}
