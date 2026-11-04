pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"
import "root:/modules/notifications"

/*! Each removal trigger at the beginning, middle, end and only slot;
    unrelated rows keep their identities and fully drawn contents. */
Item {
    id: root
    Check { id: check }
    NotificationDriver { id: driver }
    property int step: 0
    property var removed: null
    property var kept: []
    readonly property var cases: [
        {name: "first close", count: 3, index: 0},
        {name: "middle close", count: 3, index: 1},
        {name: "last close", count: 3, index: 2},
        {name: "only close", count: 1, index: 0},
        {name: "withdrawal", count: 3, index: 1},
        {name: "body click", count: 3, index: 0},
        {name: "popup closes during exit", count: 3, index: 1}
    ]
    readonly property Item history: fixture.item?.history ?? null
    Loader {
        id: fixture
        active: driver.isolated
        sourceComponent: FloatingWindow {
            property alias history: history
            visible: true; screen: Quickshell.screens[0]
            implicitWidth: 352; implicitHeight: 420
            minimumSize: Qt.size(352, 420); maximumSize: minimumSize
            NotificationList { id: history; anchors.fill: parent }
        }
    }
    Component.onCompleted: {
        check.equal("removal test has a private bus", driver.isolated, true);
        if (!driver.isolated) { check.done(); return; }
        root.populate();
    }
    function populate(): void {
        const scenario = root.cases[root.step];
        driver.many(Array.from({length: scenario.count}, (_, i) => scenario.name + " " + i), () => {
            driver.after(Math.max(Appearance.t.base, Appearance.t.resize) + Appearance.t.grace, root.remove);
        });
    }
    function remove(): void {
        const scenario = root.cases[root.step];
        root.kept = driver.cards(root.history).slice().sort((a, b) => a.y - b.y);
        root.removed = root.kept.splice(scenario.index, 1)[0];
        if (scenario.name === "withdrawal") {
            driver.withdraw(root.removed.notification.id, root.exiting);
        } else {
            const button = driver.find(root.removed, c => scenario.name === "body click"
                ? c instanceof Clickable && c.cursorShape === Qt.ArrowCursor
                : c instanceof IconButton && c.icon === "close")[0];
            button.clicked(null);
            root.exiting();
        }
    }
    function exiting(): void {
        const scenario = root.cases[root.step];
        check.equal(scenario.name + " removes the intended notification", Notifs.count, scenario.count - 1);
        driver.after(Appearance.t.resize / 2, () => {
            check.equal(scenario.name + " keeps the exiting content", Boolean(root.removed?.notification?.summary), true);
            check.equal(scenario.name + " uses a visible fade", root.removed?.opacity > 0 && root.removed?.opacity < 1, true);
            if (scenario.name === "popup closes during exit") root.history.visible = false;
            driver.after(Appearance.t.resize / 2 + Appearance.t.grace, () => {
                root.history.visible = true;
                const cards = driver.cards(root.history);
                check.equal(scenario.name + " releases its card", cards.length, scenario.count - 1);
                for (const card of root.kept) {
                    check.equal(scenario.name + " preserves an unrelated card", cards.includes(card), true);
                    check.near(scenario.name + " leaves unrelated opacity alone", card?.opacity ?? -1, 1);
                }
                Notifs.clearAll();
                driver.after(Appearance.t.resize + Math.max(0, scenario.count - 2) * Appearance.t.notificationStagger + Appearance.t.grace, () => {
                    if (++root.step < root.cases.length) root.populate();
                    else check.done();
                });
            });
        });
    }
}
