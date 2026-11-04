pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/services"
import "root:/modules/notifications"

/*! Pending entries on creation, and clearing visible toasts before their
    arrival finishes. Test the actual toast surface on a private bus. */
Item {
    id: root
    Check { id: check }
    NotificationDriver { id: driver }
    property var kept: []
    readonly property var toasts: fixture.item
    Loader { id: fixture; active: false; sourceComponent: Toasts {} }
    function cards(): var { return driver.cards(root.toasts.contentItem); }
    Component.onCompleted: {
        check.equal("toast test has a private bus", driver.isolated, true);
        if (!driver.isolated) { check.done(); return; }
        // Touch the service before sending: its server must own the name.
        check.equal("toast test starts with empty history", Notifs.count, 0);
        driver.many(["Pending A", "Pending B", "Pending C"], () => {
            fixture.active = true;
            driver.after(Appearance.t.base + Appearance.t.grace, root.pending);
        });
    }
    function pending(): void {
        check.equal("new toast surface displays pending entries", root.toasts.shown.length, 3);
        driver.send("Wake", () => {
            driver.after(Appearance.t.base + Appearance.t.grace, () => {
                check.equal("toast stack respects its live bound", Notifs.popups.length, Notifs.maxPopups);
                Notifs.clearAll();
                driver.after(Appearance.t.resize + (Notifs.maxPopups - 1) * Appearance.t.notificationStagger + Appearance.t.grace, root.arriving);
            });
        }, "{}", "[]", 0);
    }
    function arriving(): void {
        driver.send("Clear during toast arrival", () => {
            driver.after(Appearance.t.base / 2, () => {
                const card = root.cards()[0];
                check.equal("toast is visibly arriving before clear", card?.opacity > 0 && card?.opacity < 1, true);
                root.kept = root.cards();
                Notifs.clearAll();
                driver.after(Appearance.t.resize / 2, () => {
                    check.equal("clear during arrival keeps the toast until exit ends", root.cards().length, 1);
                    check.equal("clear during arrival fades the toast", root.cards()[0]?.opacity > 0 && root.cards()[0]?.opacity < 1, true);
                    check.equal("clear during arrival retains toast content", root.cards()[0]?.notification?.summary, "Clear during toast arrival");
                    driver.after(Appearance.t.resize / 2 + Appearance.t.grace, () => {
                        check.equal("cleared toast releases its slot", root.toasts.shown.length, 0);
                        check.equal("empty toast surface unmaps", root.toasts.visible, false);
                        root.burst();
                    });
                });
            });
        }, "{}", "[]", 0);
    }
    function burst(): void {
        driver.many(Array.from({length: 12}, (_, i) => "Burst " + i), () => {
            check.equal("unseen burst evictions do not hold old slots", root.toasts.shown.length, Notifs.maxPopups);
            driver.after(Appearance.t.base / 2, () => {
                Notifs.clearAll();
                driver.after(Appearance.t.resize / 2, () => {
                    check.equal("clearing a full arriving stack retains all visible cards", root.cards().length, Notifs.maxPopups);
                    for (const card of root.cards())
                        check.equal("full arriving stack clears with a fade", card.opacity > 0 && card.opacity < 1, true);
                    const ordered = root.cards().slice().sort((a, b) => a.y - b.y);
                    for (let i = 1; i < ordered.length; i++)
                        check.equal("older toast exits fade first", ordered[i - 1].opacity < ordered[i].opacity, true);
                    driver.after(Appearance.t.resize / 2 + (Notifs.maxPopups - 1) * Appearance.t.notificationStagger + Appearance.t.grace, () => {
                        check.equal("burst clear releases every slot", root.toasts.shown.length, 0);
                        check.done();
                    });
                });
            });
        });
    }
}
