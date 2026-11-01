pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"
import "root:/modules/dock"

/*! The glass keeps its resting box while the icon row expands past it.
    Overflow must stay inside the hover/input region on both ends. */
Item {
    id: root
    Check { id: check }
    Until { id: wait }
    TestEvent { id: pointer }
    DockPanel { id: dock; modelData: Quickshell.screens[0] }

    property var pending: null
    property bool tracking: false
    property int resizes: 0
    property int moves: 0
    property var rest: null
    property bool transparent: false
    readonly property DockRow row: root.findRow(dock.contentItem)

    Connections {
        target: root.row?.panel ?? null
        function onWidthChanged(): void { if (root.tracking) root.resizes++; }
        function onXChanged(): void { if (root.tracking) root.moves++; }
    }
    Timer {
        id: delay
        onTriggered: { const then = root.pending; root.pending = null; then(); }
    }
    function after(then: var): void {
        root.pending = then;
        delay.interval = Dock.magnificationDuration + Appearance.t.grace;
        delay.start();
    }
    function findRow(item: var): var {
        if (item instanceof DockRow) return item;
        for (const child of item?.children ?? []) {
            const found = root.findRow(child);
            if (found) return found;
        }
        return null;
    }
    function slots(): var {
        return root.row.children.filter(item => item instanceof DockSlot);
    }
    function launcher(): var {
        return root.row.children.find(item => item instanceof DockButton);
    }
    function point(x: real): void {
        const y = root.row.mapToItem(dock.contentItem, 0, root.row.height / 2).y;
        pointer.mouseMove(dock.contentItem, x, y, -1, Qt.NoButton, Qt.NoModifier);
    }
    function pointAt(index: int): void {
        root.point((dock.width - root.row.original.width) / 2 + root.row.original.centers[index]);
    }
    function outside(): void {
        pointer.mouseMove(dock.contentItem, 0, 0, -1, Qt.NoButton, Qt.NoModifier);
    }

    Component.onCompleted: wait.until(Settings.readyChanged, () => Settings.ready, () => {
        wait.until(Apps.allChanged, () => Apps.all.length >= 9, ready => {
            check.equal("test has enough installed applications for a wide wave", ready, true);
            if (!ready) { check.done(); return; }
            root.prepare();
        });
    })

    function prepare(): void {
        Settings.setDockAutoHide(false);
        Settings.setDockOpacityFollowsBar(false);
        Settings.setDockMagnificationEnabled(true);
        Settings.setOverride("dockOpacity", 100);
        Settings.setOverride("dockIcon", 48);
        Settings.setOverride("dockZoom", 20);
        Settings.setOverride("dockWaveWidth", 200);
        Settings.setOverride("dockMagnificationDuration", 40);
        for (const app of Apps.all.slice(0, 9)) Settings.pin(app.id);
        root.outside();
        root.pending = root.begin;
        delay.interval = Appearance.t.base + Appearance.t.grace;
        delay.start();
    }

    function capture(): void {
        root.row.forceLayout();
        const panel = root.row.panel;
        const origin = panel.mapToItem(dock.contentItem, 0, 0);
        root.rest = { width: panel.width, x: origin.x, y: origin.y, height: panel.height };
        root.resizes = 0;
        root.moves = 0;
        root.tracking = true;
    }
    function unchanged(label: string): void {
        const panel = root.row.panel;
        const origin = panel.mapToItem(dock.contentItem, 0, 0);
        check.near(label + ": background width", panel.width, root.rest.width);
        check.near(label + ": background left edge", origin.x, root.rest.x);
        check.near(label + ": bottom edge", origin.y + panel.height, root.rest.y + root.rest.height);
    }

    function begin(): void {
        check.equal("dock has a usable mapped window", dock.width > 0 && root.row !== null, true);
        if (!root.row || dock.width === 0) { check.done(); return; }
        root.capture();
        check.near("resting background follows original width",
            root.rest.width, root.row.original.width + dock.frame * 2);
        root.pointAt(4);
        root.after(() => {
            root.unchanged("center hover");
            check.equal("live icons still move apart", root.row.width > root.row.original.width, true);
            root.leftEdge();
        });
    }

    function leftEdge(): void {
        root.pointAt(0);
        root.after(() => {
            root.unchanged("first icon hover");
            const first = root.slots()[0].children[0];
            const x = first.mapToItem(dock.contentItem, 0, 0).x;
            check.equal("first icon can extend past the background", x < root.rest.x, true);
            // Beyond the old fixed margin, but inside the expanded first slot.
            root.point(root.rest.x - Appearance.m.dockIcon * (Appearance.m.dockMagnification - 1) - 1);
            root.after(() => {
                root.unchanged("left overflow hover");
                check.equal("left overflow keeps dock hover", dock.pointerNear, true);
                check.equal("left overflow keeps the wave active", root.row.magnifying, true);
                root.rightEdge();
            });
        });
    }

    function rightEdge(): void {
        root.pointAt(root.row.original.centers.length - 1);
        root.after(() => {
            root.unchanged("launcher hover");
            const launcher = root.launcher();
            const far = launcher.mapToItem(dock.contentItem, launcher.width, 0).x;
            check.equal("launcher can extend past the background", far > root.rest.x + root.rest.width, true);
            const x = root.rest.x + root.rest.width
                + Appearance.m.dockIcon * (Appearance.m.dockMagnification - 1) + 1;
            root.point(x);
            root.after(() => {
                root.unchanged("right overflow hover");
                check.equal("right overflow keeps dock hover", dock.pointerNear, true);
                const y = root.row.mapToItem(dock.contentItem, 0, root.row.height / 2).y;
                pointer.mouseClick(dock.contentItem, x, y, Qt.LeftButton, Qt.NoModifier, -1);
                check.equal("overflowed launcher remains clickable", Overlay.isOpen(Overlay.launcher), true);
                Overlay.close();
                root.outside();
                root.after(root.exited);
            });
        });
    }

    function exited(): void {
        root.unchanged("pointer exit");
        check.equal("no intermediate background resize", root.resizes, 0);
        check.equal("no intermediate background move", root.moves, 0);
        check.near("row returns to original width", root.row.width, root.row.original.width);
        root.tracking = false;
        if (!root.transparent) {
            root.transparent = true;
            Settings.setOverride("dockOpacity", 0);
            root.pending = root.begin;
            delay.interval = Appearance.t.base + Appearance.t.grace;
            delay.start();
        } else {
            check.done();
        }
    }
}
