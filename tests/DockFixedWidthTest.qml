pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"
import "root:/modules/dock"

/*! Exercise the real dock's footprint, anchors and input during the wave.
    The finite sequence of waits observes animation, never polls for state. */
Item {
    id: root

    Check { id: check }
    Until { id: wait }
    TestEvent { id: pointer }
    DockPanel { id: dock; modelData: Quickshell.screens[0] }
    readonly property DockRow row: root.find(dock.contentItem, item => item instanceof DockRow)
    property var pending: null
    property var resting: null
    property bool watching: false
    property bool widthStayedFixed: true
    property int configuration: 0
    property int position: 0
    readonly property var configurations: [
        { size: 28, opacity: 100 }, { size: 48, opacity: 100 },
        { size: 28, opacity: 0 }, { size: 48, opacity: 0 }
    ]
    readonly property var positions: [0, Math.floor((root.row.original.centers.length - 2) / 2),
        root.row.original.centers.length - 2, root.row.original.centers.length - 1]
    property var removed: null

    Timer {
        id: delay
        onTriggered: { const then = root.pending; root.pending = null; then(); }
    }
    function after(ms: int, then: var): void {
        root.pending = then;
        delay.interval = ms;
        delay.start();
    }
    function find(item: var, predicate: var): var {
        if (predicate(item)) return item;
        for (const child of item.children ?? []) {
            const found = root.find(child, predicate);
            if (found) return found;
        }
        return null;
    }
    function icons(): var {
        return root.row.children.filter(item => item instanceof DockSlot || item instanceof DockButton)
            .map(item => item instanceof DockSlot ? root.find(item, child => child instanceof DockItem) : item);
    }
    function geometry(): var {
        root.row.forceLayout();
        return { width: root.row.width, glass: root.row.panel.width, trigger: dock.mask.item.width,
            centers: root.icons().map(icon => icon.mapToItem(dock.contentItem, icon.width / 2, 0).x),
            bottoms: root.icons().map(icon => icon.mapToItem(dock.contentItem, 0, icon.height).y) };
    }
    function observeWidth(): void {
        if (root.watching && root.resting)
            root.widthStayedFixed = root.widthStayedFixed
                && Math.abs(root.row.width - root.resting.width) < 0.001
                && Math.abs(root.row.panel.width - root.resting.glass) < 0.001
                && Math.abs(dock.mask.item.width - root.resting.trigger) < 0.001;
    }
    Connections {
        target: root.row
        function onWidthChanged(): void { root.observeWidth(); }
    }
    Connections {
        target: root.row.panel
        function onWidthChanged(): void { root.observeWidth(); }
    }
    Connections {
        target: dock.mask.item
        function onWidthChanged(): void { root.observeWidth(); }
    }

    Component.onCompleted: wait.until(Settings.readyChanged, () => Settings.ready, () => {
        Settings.setDockAutoHide(false);
        Settings.setDockMagnificationEnabled(true);
        Settings.setOverride("dockZoom", 20);
        Settings.setOverride("dockWaveWidth", 200);
        Settings.setOverride("dockMagnificationDuration", 120);
        root.row.magnifying = false;
        wait.until(Apps.allChanged, () => Apps.all.length > 0, () => {
            // Pin installed entries through the model's real owner, so late
            // compositor events reconcile the same applications.
            for (const id of Settings.pinnedApps) Settings.unpin(id);
            for (const entry of Apps.all.slice(0, 9)) Settings.pin(entry.id);
            Qt.callLater(root.configure);
        });
    })

    function configure(): void {
        root.watching = false;
        root.row.magnifying = false;
        Settings.setOverride("dockIcon", root.configurations[root.configuration].size);
        Settings.setDockOpacityFollowsBar(false);
        Settings.setOverride("dockOpacity", root.configurations[root.configuration].opacity);
        root.after(Appearance.t.base + Appearance.t.grace, () => {
            Qt.callLater(() => {
                root.resting = root.geometry();
                root.widthStayedFixed = true;
                root.watching = true;
                root.position = 0;
                root.hover();
            });
        });
    }
    function hover(): void {
        const index = root.positions[root.position];
        root.row.pointerX = root.resting.centers[index];
        root.row.magnifying = true;
        root.after(40, () => {
            root.assertGeometry("during entry");
            root.after(120, root.hovered);
        });
    }
    function assertGeometry(label: string): void {
        const now = root.geometry();
        const prefix = root.configuration + "/" + root.position + " " + label;
        check.near(prefix + " row width", now.width, root.resting.width);
        check.near(prefix + " glass width", now.glass, root.resting.glass);
        check.near(prefix + " reveal width", now.trigger, root.resting.trigger);
        check.equal(prefix + " horizontal centres stay fixed",
            now.centers.every((x, i) => Math.abs(x - root.resting.centers[i]) < 0.001), true);
        check.equal(prefix + " bottom resting stays fixed",
            now.bottoms.every((y, i) => Math.abs(y - root.resting.bottoms[i]) < 0.001), true);
    }
    function hovered(): void {
        root.assertGeometry("hovered");
        const icons = root.icons();
        const index = root.positions[root.position];
        check.near("hover still reaches configured 120% peak", root.row.magnifications[index], 1.2);
        check.equal("magnified artwork does not overlap", icons.every((icon, i) => i === 0
            || root.resting.centers[i] - root.resting.centers[i - 1]
                > Appearance.m.dockIcon * (icon.magnification + icons[i - 1].magnification) / 2), true);
        dock.onChildHover("width-test", "Width test", root.resting.centers[index], true);
        root.assertGeometry("tooltip requested");
        dock.onChildHover("width-test", "Width test", root.resting.centers[index], false);
        if (++root.position < root.positions.length) root.hover();
        else {
            root.row.magnifying = false;
            root.after(160, () => {
                root.assertGeometry("exited");
                check.equal("width stayed fixed across every width signal", root.widthStayedFixed, true);
                if (++root.configuration < root.configurations.length) root.configure();
                else root.inputs();
            });
        }
    }
    function inputs(): void {
        root.row.pointerX = root.resting.centers[Math.floor((root.resting.centers.length - 2) / 2)];
        root.row.magnifying = true;
        root.after(160, () => {
            const icon = root.icons()[Math.floor((root.resting.centers.length - 2) / 2)];
            const top = icon.mapToItem(dock.contentItem, icon.width / 2, Appearance.m.dockInset);
            pointer.mouseMove(dock.contentItem, top.x, top.y, -1, Qt.NoButton, Qt.NoModifier);
            root.after(16, () => {
                check.equal("magnified application upper edge receives hover", dock.hoveredKey, root.row.drawn[Math.floor((root.resting.centers.length - 2) / 2)].key);
                check.near("application tooltip anchor stays at resting centre", icon.centerX(), root.resting.centers[Math.floor((root.resting.centers.length - 2) / 2)]);
                root.launcherInput();
            });
        });
    }
    function launcherInput(): void {
        root.row.pointerX = root.resting.centers[root.resting.centers.length - 1];
        root.after(160, () => {
            const launcher = root.icons()[root.resting.centers.length - 1];
            const top = launcher.mapToItem(dock.contentItem, launcher.width / 2, Appearance.m.dockInset);
            pointer.mouseMove(dock.contentItem, top.x, top.y, -1, Qt.NoButton, Qt.NoModifier);
            pointer.mousePress(dock.contentItem, top.x, top.y, Qt.LeftButton, Qt.NoModifier, -1);
            pointer.mouseRelease(dock.contentItem, top.x, top.y, Qt.LeftButton, Qt.NoModifier, -1);
            root.after(16, () => {
                check.equal("magnified launcher upper edge activates", Overlay.isOpen(Overlay.launcher), true);
                check.near("launcher anchor stays at resting centre", launcher.centerX(), root.resting.centers[root.resting.centers.length - 1]);
                Overlay.close();
                root.modelChanges();
            });
        });
    }
    function modelChanges(): void {
        root.watching = false;
        root.row.magnifying = false;
        root.removed = Dock.items.find(item => item.pinned && !item.running);
        Settings.unpin(root.removed.key);
        root.after(Appearance.t.base + Appearance.t.grace, () => {
            check.near("application leaving still shrinks the dock", root.row.original.width,
                root.resting.width - root.row.slotStride);
            Settings.pin(root.removed.key);
            root.after(Appearance.t.base + Appearance.t.grace, () => {
                check.near("application arriving restores its footprint", root.row.width, root.resting.width);
                Settings.setDockMagnificationEnabled(false);
                root.row.magnifying = true;
                check.equal("disabled magnification targets rest", root.row.magnifications.every(value => value === 1), true);
                Settings.setDockMagnificationEnabled(true);
                Settings.setOverride("dockZoom", 0);
                check.equal("zero zoom targets rest", root.row.magnifications.every(value => value === 1), true);
                check.done();
            });
        });
    }
}
