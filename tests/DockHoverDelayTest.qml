pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"
import "root:/modules/dock"

/*! Real pointer events exercise the shared interaction state and the dock's
    tooltip timing. Each wait follows an input event; none polls for state. */
Item {
    id: root

    Check { id: check }
    Until { id: wait }
    TestEvent { id: pointer }
    DockPanel { id: dock; modelData: Quickshell.screens[0] }
    readonly property DockRow row: root.find(dock.contentItem, item => item instanceof DockRow)
    readonly property Tooltip tip: root.find(dock.contentItem, item => item instanceof Tooltip)
    readonly property DockPreview preview: root.find(dock.contentItem, item => item instanceof DockPreview)
    property var app: null
    property var other: null
    property var launcher: null
    property var pending: null
    property real restingWidth: 0
    property real restingCenter: 0
    property int clicks: 0

    Clickable {
        id: ordinary
        parent: dock.contentItem
        x: Appearance.s.md; y: Appearance.s.md
        width: Appearance.m.dockSlot; height: width
        onClicked: root.clicks++
    }
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
    function point(item: Item, along: real): void {
        const p = item.mapToItem(dock.contentItem, item.width * along, item.height / 2);
        pointer.mouseMove(dock.contentItem, p.x, p.y, -1, Qt.NoButton, Qt.NoModifier);
    }
    function away(): void {
        pointer.mouseMove(dock.contentItem, 0, 0, -1, Qt.NoButton, Qt.NoModifier);
    }
    function hoverState(label: string, item: var, active: bool): void {
        check.equal(label + " hover", item.hovered, active);
        check.equal(label + " cursor", item.cursorShape, active ? Qt.PointingHandCursor : Qt.ArrowCursor);
    }
    function wash(item: var): var {
        return item.children.filter(child => child instanceof Rectangle)[1];
    }

    Component.onCompleted: wait.until(Settings.readyChanged, () => Settings.ready, () => {
        Settings.setDockAutoHide(false);
        Settings.setDockMagnificationEnabled(true);
        Settings.setOverride("dockMagnificationDuration", 120);
        Settings.setOverride("dockZoom", 20);
        wait.until(Apps.allChanged, () => Apps.all.length >= 2, () => {
            for (const id of Settings.pinnedApps) Settings.unpin(id);
            for (const entry of Apps.all.slice(0, 2)) Settings.pin(entry.id);
            root.after(Appearance.t.base + Appearance.t.grace, root.start);
        });
    })
    function start(): void {
        root.row.forceLayout();
        const apps = root.row.children.filter(item => item instanceof DockSlot && !item.entry.leaving)
            .map(item => root.find(item, child => child instanceof DockItem));
        root.app = apps[0]; root.other = apps[1];
        root.launcher = root.row.children.find(item => item instanceof DockButton);
        check.equal("two real application icons available", apps.length >= 2, true);
        root.restingWidth = root.row.width;
        root.restingCenter = root.app.centerX();
        root.point(ordinary, 0.5);
        root.after(16, () => {
            check.equal("ordinary controls still hover immediately", ordinary.hovered, true);
            check.equal("ordinary tooltip delay stays 450 ms", ordinaryTip.delayMs, 450);
            root.point(root.app, 0.5);
            root.after(40, root.entered);
        });
    }
    Tooltip { id: ordinaryTip }
    function entered(): void {
        check.equal("raw pointer enters the application immediately", root.app.containsMouse, true);
        check.equal("preview gets raw entry immediately", root.preview.pointed, root.app.item.key);
        check.equal("magnification already progresses at 40 ms", root.row.children
            .find(item => item instanceof DockSlot && !item.entry.leaving).magnification > 1, true);
        root.hoverState("40 ms", root.app, false);
        check.equal("magnification hides the early hover wash", root.wash(root.app).visible, false);
        check.near("no early name tooltip", root.tip.opacity, 0);
        root.after(160, () => {
            root.hoverState("200 ms", root.app, false);
            check.near("tooltip waits through 200 ms", root.tip.opacity, 0);
            // Motion inside the same icon must not restart its dwell.
            root.point(root.app, 0.6);
            root.after(136, root.activated);
        });
    }
    function activated(): void {
        root.hoverState("336 ms despite movement inside icon", root.app, true);
        check.equal("magnification keeps the hover wash hidden", root.wash(root.app).visible, false);
        check.equal("name tooltip has begun without a second dwell", root.tip.opacity > 0, true);
        check.near("hover retains the dock width", root.row.width, root.restingWidth);
        check.near("hover retains the icon centre", root.app.centerX(), root.restingCenter);
        root.away();
        root.after(16, () => {
            root.hoverState("departure", root.app, false);
            root.after(Appearance.t.fast + Appearance.t.grace, root.crossing);
        });
    }
    function crossing(): void {
        root.point(root.app, 0.5);
        root.after(200, () => {
            root.away();
            root.after(160, () => {
                root.hoverState("cancelled crossing never activates", root.app, false);
                check.near("cancelled crossing never shows the name", root.tip.opacity, 0);
                root.point(root.app, 0.5);
                root.after(180, () => {
                    root.point(root.other, 0.5);
                    root.after(160, () => {
                        root.hoverState("new icon gets a fresh dwell", root.other, false);
                        check.near("new icon name gets a fresh dwell", root.tip.opacity, 0);
                        root.after(176, root.switched);
                    });
                });
            });
        });
    }
    function switched(): void {
        root.hoverState("second icon after its own 336 ms", root.other, true);
        check.equal("second icon name appears", root.tip.opacity > 0, true);
        root.point(root.app, 0.5);
        root.after(40, () => {
            check.equal("fading old tooltip keeps its old name",
                root.find(root.tip, item => item instanceof Label).text, root.other.item.name);
            root.after(120, root.returned);
        });
    }
    function returned(): void {
        root.hoverState("returning to first icon starts over", root.app, false);
        root.app.enabled = false;
        root.after(200, () => {
            root.hoverState("disabled icon cancels pending hover", root.app, false);
            check.near("disabled icon has no delayed name", root.tip.opacity, 0);
            root.app.enabled = true;
            root.point(root.app, 0.5);
            root.after(160, () => {
                root.hoverState("re-enabled icon starts a new dwell", root.app, false);
                root.after(176, root.reenabled);
            });
        });
    }
    function reenabled(): void {
        root.hoverState("re-enabled icon after its full dwell", root.app, true);
        root.app.hoverEnabled = false;
        root.after(16, () => {
            root.hoverState("hover-disabled icon clears activation", root.app, false);
            root.app.hoverEnabled = true;
            root.away();
            root.after(Appearance.t.fast + Appearance.t.grace, root.launcherEntry);
        });
    }
    function launcherEntry(): void {
        root.point(root.launcher, 0.5);
        root.after(200, () => {
            root.hoverState("Applications before 300 ms", root.launcher, false);
            check.near("Applications label waits", root.tip.opacity, 0);
            root.after(136, () => {
                root.hoverState("Applications after 300 ms", root.launcher, true);
                check.equal("Applications label begins with hover", root.tip.opacity > 0, true);
                root.away();
                root.after(Appearance.t.fast + Appearance.t.grace, root.immediateClicks);
            });
        });
    }
    function immediateClicks(): void {
        root.point(root.launcher, 0.5);
        root.after(16, () => {
            const p = root.launcher.mapToItem(dock.contentItem, root.launcher.width / 2, root.launcher.height / 2);
            pointer.mousePress(dock.contentItem, p.x, p.y, Qt.LeftButton, Qt.NoModifier, -1);
            check.equal("press state is immediate during dwell", root.launcher.down, true);
            pointer.mouseRelease(dock.contentItem, p.x, p.y, Qt.LeftButton, Qt.NoModifier, -1);
            check.equal("Applications click acts before hover activates", Overlay.isOpen(Overlay.launcher), true);
            check.equal("selection does not wait for hover", root.launcher.selected, true);
            Overlay.close();
            root.point(ordinary, 0.5);
            const q = ordinary.mapToItem(dock.contentItem, ordinary.width / 2, ordinary.height / 2);
            pointer.mousePress(dock.contentItem, q.x, q.y, Qt.LeftButton, Qt.NoModifier, -1);
            pointer.mouseRelease(dock.contentItem, q.x, q.y, Qt.LeftButton, Qt.NoModifier, -1);
            check.equal("ordinary control still clicks immediately", root.clicks, 1);
            root.away();
            ordinaryTip.text = "First";
            ordinaryTip.show = true;
            root.after(400, () => {
                check.near("ordinary tooltip still waits its full dwell", ordinaryTip.opacity, 0);
                root.after(86, () => {
                    check.equal("ordinary tooltip appears after its own dwell", ordinaryTip.opacity > 0, true);
                    ordinaryTip.text = "Second";
                    check.equal("visible ordinary tooltip text still updates immediately",
                        root.find(ordinaryTip, item => item instanceof Label).text, "Second");
                    ordinaryTip.show = false;
                    check.done();
                });
            });
        });
    }
}
