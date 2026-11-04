pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"
import "root:/modules/notifications"

/*! Clear all through the actual heading button, then first-row reflow.
    The loader prevents even constructing a server on the desktop's bus. */
Item {
    id: root
    Check { id: check }
    NotificationDriver { id: driver }
    property var kept: []
    property var second: null
    property real secondY: 0
    property real firstY: 0
    readonly property Item history: fixture.item?.history ?? null
    Loader {
        id: fixture
        active: driver.isolated
        sourceComponent: FloatingWindow {
            property alias history: history
            visible: true
            screen: Quickshell.screens[0]
            implicitWidth: 352
            implicitHeight: 420
            minimumSize: Qt.size(352, 420)
            maximumSize: Qt.size(352, 420)
            NotificationList { id: history; anchors.fill: parent }
        }
    }
    function cards(): var { return driver.cards(root.history); }
    function empty(): var { return driver.find(root.history, item => item instanceof Label && item.text === "No Notifications")[0]; }
    function settled(then: var): void { driver.after(Math.max(Appearance.t.base, Appearance.t.resize) + Appearance.t.grace, then); }
    Component.onCompleted: {
        check.equal("notification tests have a private bus", driver.isolated, true);
        if (!driver.isolated) { check.done(); return; }
        driver.many(["A", "B", "C"], () => root.settled(root.clear));
    }
    function clear(): void {
        check.equal("three real notifications received", Notifs.count, 3);
        root.kept = root.cards();
        check.equal("three actual cards displayed", root.kept.length, 3);
        const button = driver.find(root.history, item => item instanceof TextButton && item.text === "Clear all")[0];
        check.equal("Clear all is enabled", button?.enabled, true);
        button.clicked(null);
        check.equal("Clear all dismisses the service history", Notifs.count, 0);
        check.equal("Clear all clears active toasts", Notifs.popups.length, 0);
        driver.after(Appearance.t.resize / 2, () => {
            check.equal("empty state waits for exits", root.empty()?.visible, false);
            check.equal("Clear all keeps all exiting cards", root.cards().length, 3);
            for (const card of root.cards()) {
                check.equal("clear retains " + card.notification?.summary, Boolean(card.notification?.summary), true);
                check.equal("clear fades each card", card.opacity > 0 && card.opacity < 1, true);
                check.equal("clear slides each card right", card.mapToItem(root.history, 0, 0).x > 0, true);
            }
            const ordered = root.cards().slice().sort((a, b) => b.y - a.y);
            for (let i = 1; i < ordered.length; i++) {
                check.equal("older history exits fade first", ordered[i - 1].opacity < ordered[i].opacity, true);
                check.equal("older history exits slide first",
                    ordered[i - 1].mapToItem(root.history, 0, 0).x > ordered[i].mapToItem(root.history, 0, 0).x, true);
            }
            driver.after(Appearance.t.resize / 2 + (root.kept.length - 1) * Appearance.t.notificationStagger + Appearance.t.grace, () => {
                check.equal("Clear all releases every card", root.cards().length, 0);
                check.equal("empty state appears after exits", root.empty()?.visible, true);
                Notifs.clearAll();
                driver.many(["D", "E", "F"], () => root.settled(root.first));
            });
        });
    }
    function first(): void {
        const cards = root.cards().slice().sort((a, b) => a.y - b.y);
        root.second = cards[1];
        root.secondY = root.second.mapToItem(root.history, 0, 0).y;
        root.firstY = cards[0].mapToItem(root.history, 0, 0).y;
        cards[0].dismissed();
        driver.after(Appearance.t.resize / 2, () => {
            check.near("first-row exit holds its slot", root.second.mapToItem(root.history, 0, 0).y, root.secondY);
            driver.after(Appearance.t.resize + Appearance.t.grace / 2, () => {
                const y = root.second.mapToItem(root.history, 0, 0).y;
                check.equal("first-row gap closes progressively", y < root.secondY && y > root.firstY, true);
                driver.after(Appearance.t.resize, () => {
                    check.near("first-row gap closes completely", root.second.mapToItem(root.history, 0, 0).y, root.firstY);
                    root.interrupted();
                });
            });
        });
    }
    function interrupted(): void {
        Notifs.clearAll();
        driver.after(Appearance.t.resize + Appearance.t.notificationStagger + Appearance.t.grace, () => {
            driver.send("Arriving", () => {
                driver.after(Appearance.t.base / 3, () => {
                    const card = root.cards()[0];
                    check.equal("history arrival is a fade", card?.opacity > 0 && card?.opacity < 1, true);
                    check.near("history arrival has no slide", card?.mapToItem(root.history, 0, 0).x ?? -1, 0);
                    Notifs.clearAll();
                    Notifs.clearAll();
                    driver.after(Appearance.t.resize / 2, () => {
                        const exiting = root.cards()[0];
                        check.equal("clear during arrival keeps a fading card", exiting?.opacity > 0 && exiting?.opacity < 1, true);
                        check.equal("clear during arrival slides right", (exiting?.mapToItem(root.history, 0, 0).x ?? 0) > 0, true);
                        driver.send("After clear", () => {
                            root.settled(() => {
                                check.equal("new arrival after clear survives", Notifs.history[0]?.summary, "After clear");
                                check.equal("interrupted exits release exactly once", root.cards().length, 1);
                                check.near("survivor is fully opaque", root.cards()[0]?.opacity ?? -1, 1);
                                check.equal("new arrival hides the empty state", root.empty()?.visible, false);
                                Notifs.clearAll();
                                driver.after(Appearance.t.resize + Appearance.t.grace, () => check.done());
                            });
                        }, "{}", "[]", 0);
                    });
                });
            }, "{}", "[]", 0);
        });
    }
}
