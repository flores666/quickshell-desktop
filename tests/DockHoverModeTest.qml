pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"
import "root:/modules/dock"

/*! Exercise both modes and settings changes under a stationary pointer.
    Every bounded wait follows an input or setting change. */
Item {
    id: root

    Check { id: check }
    Until { id: wait }
    TestEvent { id: pointer }
    DockPanel { id: dock; modelData: Quickshell.screens[0] }
    readonly property DockRow row: root.find(dock.contentItem, item => item instanceof DockRow)
    readonly property Tooltip tip: root.find(dock.contentItem, item => item instanceof Tooltip)
    property var app: null
    property var launcher: null
    property var pending: null
    property int subject: 0
    property real restingWidth: 0
    readonly property var current: root.subject === 0 ? root.app : root.launcher

    Timer {
        id: delay
        onTriggered: { const then = root.pending; root.pending = null; then(); }
    }
    function after(ms: int, then: var): void {
        root.pending = then; delay.interval = ms; delay.start();
    }
    function find(item: var, predicate: var): var {
        if (predicate(item)) return item;
        for (const child of item.children ?? []) {
            const found = root.find(child, predicate);
            if (found) return found;
        }
        return null;
    }
    function wash(item: var): var {
        return item.children.filter(child => child instanceof Rectangle)[1];
    }
    function move(item: Item): void {
        const p = item.mapToItem(dock.contentItem, item.width / 2, item.height / 2);
        pointer.mouseMove(dock.contentItem, p.x, p.y, -1, Qt.NoButton, Qt.NoModifier);
    }
    function away(): void {
        pointer.mouseMove(dock.contentItem, 0, 0, -1, Qt.NoButton, Qt.NoModifier);
    }
    function click(item: Item, pressed: bool): void {
        const p = item.mapToItem(dock.contentItem, item.width / 2, item.height / 2);
        if (pressed) pointer.mousePress(dock.contentItem, p.x, p.y, Qt.LeftButton, Qt.NoModifier, -1);
        else pointer.mouseRelease(dock.contentItem, p.x, p.y, Qt.LeftButton, Qt.NoModifier, -1);
    }
    function hover(label: string, active: bool): void {
        const prefix = root.subject + " " + label;
        check.equal(prefix + " hovered", root.current.hovered, active);
        check.equal(prefix + " cursor", root.current.cursorShape, active ? Qt.PointingHandCursor : Qt.ArrowCursor);
        check.near(prefix + " row width", root.row.width, root.restingWidth);
    }
    function fills(label: string, visible: bool): void {
        for (const item of [root.app, root.launcher])
            check.equal(root.subject + " " + label + " " + (item === root.app ? "app" : "Applications"),
                root.wash(item).visible, visible);
    }

    Component.onCompleted: wait.until(Settings.readyChanged, () => Settings.ready, () => {
        Settings.setDockAutoHide(false);
        Settings.setDockMagnificationEnabled(true);
        Settings.setOverride("dockZoom", 20);
        wait.until(Apps.allChanged, () => Apps.all.length > 0, () => {
            for (const id of Settings.pinnedApps) Settings.unpin(id);
            Settings.pin(Apps.all[0].id);
            root.after(Appearance.t.base + Appearance.t.grace, root.start);
        });
    })
    function start(): void {
        root.row.forceLayout();
        const slot = root.row.children.find(item => item instanceof DockSlot && !item.entry.leaving);
        root.app = root.find(slot, item => item instanceof DockItem);
        root.launcher = root.row.children.find(item => item instanceof DockButton);
        root.restingWidth = root.row.width;
        root.onMode();
    }
    function onMode(): void {
        Settings.setDockMagnificationEnabled(true);
        root.move(root.current);
        root.after(160, () => {
            root.hover("enabled before 300 ms", false);
            root.fills("enabled hides all fills", false);
            check.near("enabled name waits", root.tip.opacity, 0);
            root.after(176, () => {
                root.hover("enabled after 300 ms", true);
                root.fills("enabled hover remains unfilled", false);
                check.equal("enabled name appears after dwell", root.tip.opacity > 0, true);
                // Selected/active application state must not paint a circle.
                root.current.selected = true;
                root.fills("enabled selection remains unfilled", false);
                root.current.selected = false;
                root.away();
                root.after(Appearance.t.fast + Appearance.t.grace, root.offMode);
            });
        });
    }
    function offMode(): void {
        Settings.setDockMagnificationEnabled(false);
        root.move(root.current);
        root.after(40, () => {
            root.hover("disabled responds on entry", true);
            root.fills("disabled restores all fills", true);
            check.equal("disabled name begins without dwell", root.tip.opacity > 0, true);
            check.equal("disabled hover wash begins immediately", root.wash(root.current).color.a > 0, true);
            root.after(160, () => {
                root.hover("disabled stays immediate", true);
                root.away();
                root.current.selected = true;
                root.after(Appearance.t.fast + Appearance.t.grace, () => {
                    check.equal("disabled selected fill remains visible", root.wash(root.current).visible, true);
                    check.equal("disabled selected fill is painted", root.wash(root.current).color.a > 0, true);
                    root.current.selected = false;
                    root.earlyToggle();
                });
            });
        });
    }
    function earlyToggle(): void {
        Settings.setDockMagnificationEnabled(true);
        root.move(root.current);
        root.after(160, () => {
            root.hover("pending enabled hover", false);
            Settings.setDockMagnificationEnabled(false);
            check.equal("switching off releases hover synchronously", root.current.hovered, true);
            root.fills("switching off restores backgrounds immediately", true);
            root.after(40, () => {
                check.equal("switching off releases the pending name", root.tip.opacity > 0, true);
                root.after(160, root.lateToggle);
            });
        });
    }
    function lateToggle(): void {
        // The name is now visible. Enabling must restart both dwell clocks.
        Settings.setDockMagnificationEnabled(true);
        check.equal("switching on resets existing hover immediately", root.current.hovered, false);
        root.fills("switching on hides selected and hover fills immediately", false);
        root.after(200, () => {
            root.hover("switching on starts a fresh dwell", false);
            check.near("switching on dismisses the old name during the new dwell", root.tip.opacity, 0);
            root.after(136, () => {
                root.hover("fresh enabled dwell completes", true);
                check.equal("name resumes only after the new dwell", root.tip.opacity > 0, true);
                Settings.setDockMagnificationEnabled(false);
                root.after(40, () => {
                    root.hover("switching off an active hover stays immediate", true);
                    root.fills("active hover gets its background back", true);
                    root.away();
                    root.after(Appearance.t.fast + Appearance.t.grace, root.nextSubject);
                });
            });
        });
    }
    function nextSubject(): void {
        if (++root.subject < 2) root.onMode();
        else root.zeroZoom();
    }
    function zeroZoom(): void {
        root.subject = 0;
        Settings.setOverride("dockZoom", 0);
        Settings.setDockMagnificationEnabled(true);
        root.move(root.current);
        root.after(160, () => {
            root.hover("enabled with zero zoom still delays", false);
            root.fills("enabled with zero zoom still hides all circles", false);
            root.after(176, () => {
                root.hover("enabled zero-zoom dwell completes", true);
                root.away();
                root.after(Appearance.t.fast + Appearance.t.grace, root.presses);
            });
        });
    }
    function presses(): void {
        root.move(root.launcher);
        root.click(root.launcher, true);
        check.equal("enabled press is immediate", root.launcher.down, true);
        root.fills("enabled press draws no circle", false);
        root.click(root.launcher, false);
        check.equal("enabled click still opens Applications", Overlay.isOpen(Overlay.launcher), true);
        root.away();
        Overlay.close();
        Settings.setDockMagnificationEnabled(false);
        root.move(root.launcher);
        root.click(root.launcher, true);
        check.equal("disabled press is immediate", root.launcher.down, true);
        root.fills("disabled press restores its circle", true);
        root.click(root.launcher, false);
        check.equal("disabled click still opens Applications", Overlay.isOpen(Overlay.launcher), true);
        Overlay.close();
        root.away();
        check.done();
    }
}
