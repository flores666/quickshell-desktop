pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "root:/config"
import "root:/components"
import "root:/services"
import "root:/modules/dock"

Item {
    id: root

    Check { id: check }
    Until { id: ready }
    FileWait { id: saved }
    TestEvent { id: input }
    DockPanel { id: dock; modelData: Quickshell.screens[0] }
    FileView { id: external; path: root.statePath; blockWrites: true; printErrors: false }

    readonly property string statePath: Quickshell.statePath("settings.json")
    readonly property DockRow row: root.find(dock.contentItem, item => item instanceof DockRow) as DockRow
    readonly property int launcher: Dock.launcherSlot.key
    readonly property var notes: Dock.notesSlot.key
    readonly property string missing: "quickshell-launcher-test-missing"
    property var apps: []
    property real widthBeforeDrag: 0

    Timer {
        id: settle
        interval: Appearance.t.base + Appearance.t.grace
        onTriggered: root.exerciseDrag()
    }

    function find(item: Item, matches: var): Item {
        if (matches(item)) return item;
        for (const child of item.children) {
            const found = root.find(child, matches);
            if (found) return found;
        }
        return null;
    }

    function slot(key: var): DockSlot {
        return root.row.children.find(item => item instanceof DockSlot && item.entry.key === key) as DockSlot;
    }

    function expectOrder(label: string, keys: var): void {
        check.equal(label, JSON.stringify(Dock.slotKeys), JSON.stringify(keys));
        root.row.forceLayout();
        check.near(label + " keeps the dock width", root.row.width, root.widthBeforeDrag);
        check.equal(label + " resting centers match the slots", keys.every((key, i) => {
            const control = root.slot(key)?.control;
            return control && Math.abs(control.mapToItem(root.row, control.width / 2, 0).x
                - root.row.original.centers[i]) < 0.001;
        }), true);
    }

    function expectDividers(label: string, notesEdge: int, launcherEdge: int): void {
        for (const [key, edge] of [[root.notes, notesEdge], [root.launcher, launcherEdge]]) {
            const slot = root.slot(key);
            const divider = root.find(slot, item => item instanceof DockSeparator);
            check.equal(label + " separator visibility " + key, divider?.visible ?? false, edge !== 0);
            if (divider && edge !== 0) {
                const x = divider.mapToItem(slot.control, 0, 0).x;
                const start = edge === Qt.LeftEdge ? -Appearance.m.dockGap : slot.contentWidth;
                check.equal(label + " separator is in the gap " + key,
                    x >= start && x + divider.width <= start + Appearance.m.dockGap, true);
            }
        }
    }

    function drag(key: var, to: var, dx: real, cancel: bool, preview: var): void {
        const control = root.slot(key).control;
        const scene = dock.contentItem;
        const center = control.mapToItem(scene, control.width / 2, control.height / 2);
        const grab = center.x + Math.sign(dx) * (Application.styleHints.startDragDistance + 2);
        input.mousePress(scene, center.x, center.y, Qt.LeftButton, Qt.NoModifier, -1);
        input.mouseMove(scene, grab, center.y, -1, Qt.LeftButton, Qt.NoModifier);
        input.mouseMove(scene, grab + dx, center.y, -1, Qt.LeftButton, Qt.NoModifier);
        check.equal("pointer drag targets the intended slot", root.row.drag?.to, to);
        check.equal("drag holds the dock open", dock.held, true);
        if (preview) preview();
        if (cancel) control.pointerCanceled();
        input.mouseRelease(scene, grab + dx, center.y, Qt.LeftButton, Qt.NoModifier, -1);
        check.equal("end of drag releases the dock", dock.held, false);
        check.equal("drag does not open Applications", Overlay.active, Overlay.none);
    }

    function settings(text: string): var {
        try { return JSON.parse(text); } catch (error) { return {}; }
    }

    function exerciseDrag(): void {
        const [first, second, third] = root.apps;
        const launcher = root.slot(root.launcher);
        check.equal("launcher is a movable control", launcher?.control instanceof DockButton, true);
        if (!launcher?.control) { check.done(); return; }
        const control = launcher.control;
        const glyph = root.find(control, item => item instanceof Icon && item.name === "apps") as Icon;
        const app = root.slot(first).control;
        const artwork = root.find(app, item => item instanceof AppIcon);
        check.near("launcher uses the standard hit width", control.width, app.width);
        check.equal("launcher glyph is smaller than the app icon box", glyph.size < Appearance.m.dockIcon, true);
        check.near("launcher and app artwork share a centerline",
            glyph.mapToItem(root.row, 0, glyph.height / 2).y, artwork.mapToItem(root.row, 0, artwork.height / 2).y);
        check.equal("controls publish no app icon targets", root.row.iconTargets.length, root.apps.length);
        root.widthBeforeDrag = Appearance.m.dockNotesWidth + 4 * root.row.slotStride;
        root.expectOrder("legacy order keeps Applications on the right", [root.notes, ...root.apps, root.launcher]);
        root.expectDividers("both edges", Qt.RightEdge, Qt.LeftEdge);

        root.drag(root.launcher, second, -2 * root.row.slotStride, false, () => root.expectDividers("drag inward", Qt.RightEdge, 0));
        root.expectOrder("Applications moves between icons", [root.notes, first, root.launcher, second, third]);
        root.expectDividers("Applications inside the icons", Qt.RightEdge, 0);
        check.equal("moving Applications keeps the same button", root.slot(root.launcher).control, control);
        input.mouseClick(control, control.width / 2, control.height / 2, Qt.LeftButton, Qt.NoModifier, -1);
        check.equal("click opens Applications from its new position", Overlay.active, Overlay.launcher);
        check.near("launcher popup uses the relocated anchor", Overlay.anchorXOf[Overlay.launcher], control.centerX());
        Overlay.close();

        const mark = { widget: Dock.launcherSlot.widget };
        const expected = JSON.stringify([root.missing, first, mark, second, third]);
        saved.until(root.statePath, text => JSON.stringify(root.settings(text).dockOrder) === expected, text => {
            check.equal("saved order retains the launcher and unavailable pin", JSON.stringify(root.settings(text).dockOrder), expected);
            root.exerciseEdges();
        });
    }

    function exerciseEdges(): void {
        const [first, second, third] = root.apps;
        const notesStride = root.slot(root.notes).width;
        const toLeft = -notesStride - root.row.slotStride;
        root.drag(root.launcher, root.notes, toLeft, true, null);
        root.expectOrder("cancel returns Applications to its previous place", [root.notes, first, root.launcher, second, third]);
        root.drag(root.launcher, root.notes, toLeft, false, null);
        root.expectOrder("Applications moves ahead of the widget", [root.launcher, root.notes, ...root.apps]);
        root.expectDividers("two controls at the left edge", Qt.RightEdge, 0);
        root.drag(root.launcher, third, notesStride + 3 * root.row.slotStride, false, null);
        root.expectOrder("Applications returns to the end", [root.notes, ...root.apps, root.launcher]);
        check.equal("default trailing placement needs no saved marker", JSON.stringify(Settings.dockOrder),
            JSON.stringify([root.missing, ...root.apps]));

        root.drag(first, root.launcher, 3 * root.row.slotStride, false, null);
        root.expectOrder("an icon can move past Applications", [root.notes, second, third, root.launcher, first]);
        root.expectDividers("Applications with an icon beyond it", Qt.RightEdge, 0);
        const mark = { widget: Dock.launcherSlot.widget };
        const savedOrder = JSON.stringify([root.missing, second, third, mark, first]);
        saved.until(root.statePath, text => JSON.stringify(root.settings(text).dockOrder) === savedOrder, text => {
            const data = root.settings(text);
            check.equal("crossing the launcher saves its relative position", JSON.stringify(data.dockOrder), savedOrder);
            data.dockOrder = [root.missing, ...root.apps, mark, { widget: Dock.notesSlot.widget }];
            external.setText(JSON.stringify(data));
            const order = [...root.apps, root.launcher, root.notes];
            ready.until(Dock.slotKeysChanged, () => JSON.stringify(Dock.slotKeys) === JSON.stringify(order), ok => {
                check.equal("live settings reload recognizes the launcher marker", ok, true);
                Qt.callLater(() => {
                    root.expectOrder("right-side controls reload in the saved order", order);
                    root.expectDividers("two controls at the right edge", 0, Qt.LeftEdge);
                    check.done();
                });
            });
        });
    }

    Component.onCompleted: {
        if (Quickshell.env("TEST_BIN") === "") {
            check.report("private state required", false, "run with tools/test.sh");
            check.done();
            return;
        }
        ready.until(Settings.readyChanged, () => Settings.ready, loaded => {
            check.equal("settings loaded", loaded, true);
            if (!loaded) { check.done(); return; }
            ready.until(Apps.allChanged, () => Apps.all.length >= 3, available => {
                check.equal("three app icons are available", available, true);
                if (!available) { check.done(); return; }
                Settings.setDockAutoHide(false);
                Settings.setDockMagnificationEnabled(false);
                Settings.setDailyNotesEnabled(true);
                for (const key of Settings.pinnedApps.slice()) Settings.unpin(key);
                root.apps = Apps.all.slice(0, 3).map(app => app.id);
                Settings.pin(root.missing);
                Settings.setDockOrder([root.missing, ...root.apps]);
                for (const key of root.apps) Settings.pin(key);
                settle.start();
            });
        });
    }
}
