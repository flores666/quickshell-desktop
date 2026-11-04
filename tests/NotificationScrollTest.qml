pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/services"
import "root:/modules/notifications"

/*! Real overflowing history: removal must not reset the viewport while
    the retained cards are still playing their exits. */
Item {
    id: root
    Check { id: check }
    NotificationDriver { id: driver }
    readonly property Item history: fixture.item?.history ?? null
    property var kept: []
    property real lastScroll: 0
    property real largestStep: 0
    property real bottomY: 0
    Loader {
        id: fixture
        active: driver.isolated
        sourceComponent: FloatingWindow {
            property alias history: history
            visible: true
            screen: Quickshell.screens[0]
            implicitWidth: 352; implicitHeight: 320
            minimumSize: Qt.size(352, 320); maximumSize: minimumSize
            NotificationList { id: history; anchors.fill: parent }
        }
    }
    function scroll(): var { return driver.find(root.history, item => item instanceof Flickable)[0]; }
    function at(card: Item): real { return card.mapToItem(root.history, 0, 0).y; }
    Component.onCompleted: {
        check.equal("scroll test has a private bus", driver.isolated, true);
        if (!driver.isolated) { check.done(); return; }
        driver.many(Array.from({length: 12}, (_, i) => "History " + i), () => {
            driver.after(Math.max(Appearance.t.base, Appearance.t.resize) + Appearance.t.grace, root.scrolled);
        });
    }
    function scrolled(): void {
        const view = root.scroll();
        check.equal("history overflows the viewport", view.contentHeight > view.height, true);
        view.contentY = (view.contentHeight - view.height) / 2;
        driver.after(Appearance.t.grace, () => {
            root.kept = driver.cards(root.history).filter(c => {
                const y = root.at(c) - view.y;
                return y + c.height > 0 && y < view.height;
            }).map(c => ({card: c, y: root.at(c), summary: c.notification.summary}));
            check.equal("scrolled history has visible cards", root.kept.length > 0, true);
            Notifs.clearAll();
            driver.after(Appearance.t.resize / 2, () => {
                for (const entry of root.kept) {
                    check.equal("scrolled clear retains " + entry.summary, entry.card?.notification?.summary, entry.summary);
                    check.equal("scrolled clear keeps " + entry.summary + " drawn until its turn", entry.card?.opacity > 0 && entry.card?.opacity <= 1, true);
                    check.within("scrolled exit stays in place", entry.card ? root.at(entry.card) : -999, entry.y, 1);
                }
                check.equal("scrolled clear starts with the oldest visible card",
                    root.kept[root.kept.length - 1].card.opacity < root.kept[0].card.opacity, true);
                driver.after(Appearance.t.resize / 2 + root.kept.length * Appearance.t.notificationStagger + Appearance.t.grace, () => {
                    check.equal("scrolled clear removes every card", driver.cards(root.history).length, 0);
                    check.equal("scrolled clear empties real history", Notifs.count, 0);
                    check.near("empty history restores a valid scroll position", root.scroll().contentY, 0);
                    driver.many(["Returned", "Wrapped", "Again", "Last"], () => {
                        driver.after(Appearance.t.base + Appearance.t.grace, root.reopened);
                    });
                });
            });
        });
    }
    function reopened(): void {
        root.history.visible = false;
        driver.send("While closed", () => {
            root.history.visible = true;
            driver.after(Appearance.t.base + Appearance.t.grace, () => {
                const cards = driver.cards(root.history).slice().sort((a, b) => a.y - b.y);
                for (let i = 1; i < cards.length; i++)
                    check.equal("reopened wrapped cards do not overlap", cards[i].y >= cards[i-1].y + cards[i-1].height, true);
                check.equal("arrivals while closed remain live", Notifs.history[0]?.summary, "While closed");
                root.bottomRemoval();
            });
        }, "{}", "[]", 0);
    }
    function observeScroll(): void {
        const y = root.scroll().contentY;
        root.largestStep = Math.max(root.largestStep, Math.abs(y - root.lastScroll));
        root.lastScroll = y;
    }
    function bottomRemoval(): void {
        const view = root.scroll();
        view.contentY = Math.max(0, view.contentHeight - view.height);
        root.bottomY = view.contentY;
        root.lastScroll = view.contentY;
        view.contentYChanged.connect(root.observeScroll);
        Notifs.remove(Notifs.history[0]);
        driver.after(Appearance.t.resize / 2, () => {
            check.near("bottom-scrolled removal holds the viewport during exit", view.contentY, root.bottomY);
            driver.after(Appearance.t.resize, () => {
                const target = Math.max(0, view.contentHeight - view.height);
                check.equal("scroll clamping progresses with the moving rows", view.contentY < root.bottomY && view.contentY >= target, true);
                check.equal("scroll clamping has no full-row jump", root.largestStep < root.bottomY / 2, true);
                driver.after(Appearance.t.resize + Appearance.t.grace, () => {
                    view.contentYChanged.disconnect(root.observeScroll);
                    check.equal("scrolled removal leaves no blank tail", view.contentY <= Math.max(0, view.contentHeight - view.height), true);
                    Notifs.clearAll();
                    driver.after(Appearance.t.resize + driver.cards(root.history).length * Appearance.t.notificationStagger + Appearance.t.grace, () => check.done());
                });
            });
        });
    }
}
