pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"
import "root:/modules/dock"

/*! Observe the wave during entry and a finite stream of pointer movements,
    rather than only checking its destination after all animation is over. */
Item {
    id: root

    Check { id: check }
    TestEvent { id: pointer }
    Until { id: wait }
    property var pending: null
    property real expectedX: 0
    property var inputIcon: null
    readonly property DockRow liveRow: root.findRow(dock.contentItem)

    Surface { id: glass }
    DockRow {
        id: row
        screen: Quickshell.screens[0]
        panel: glass
        function reconcile(arriving: bool): void {}
    }
    DockPanel { id: dock; modelData: Quickshell.screens[0] }

    Timer {
        id: delay
        onTriggered: {
            const then = root.pending;
            root.pending = null;
            then();
        }
    }

    function after(milliseconds: int, then: var): void {
        root.pending = then;
        delay.interval = milliseconds;
        delay.start();
    }

    function findRow(item: var): var {
        if (!item) return null;
        if (item instanceof DockRow) return item;
        for (const child of item.children ?? []) {
            const found = root.findRow(child);
            if (found) return found;
        }
        return null;
    }

    function slots(): var {
        return row.children.filter(child => child instanceof DockSlot);
    }

    function pointAt(index: real): void {
        row.pointerX = (row.screen.width - row.original.width) / 2
            + Appearance.m.dockSlot / 2 + index * row.slotStride;
    }

    Component.onCompleted: wait.until(Settings.readyChanged, () => Settings.ready, () => {
        Settings.setDockAutoHide(false);
        Qt.callLater(root.start);
    })

    function start(): void {
        row.drawn = Array.from({ length: 9 }, (_, i) => ({
            key: "response-" + i, leaving: false, arriving: false,
            item: { key: "response-" + i, name: "Test", icon: "utilities-terminal", windows: [] }
        }));
        row.forceLayout();
        root.pointAt(4);
        row.magnifying = true;
        root.after(40, () => {
            check.equal("entry makes visible progress within 40 ms", root.slots()[4].magnification >= 1.05, true);
            root.after(96, root.entered);
        });
    }

    function entered(): void {
        check.near("entry settles within 120 ms plus one frame", root.slots()[4].magnification, 1.2);
        root.path(0, false, () => {
            check.equal("continuous rightward motion does not stall in ease-in", root.slots()[8].magnification >= 1.12, true);
            root.path(0, true, () => {
                check.equal("reversing left responds promptly", root.slots()[4].magnification >= 1.12, true);
                row.magnifying = false;
                root.after(136, root.exited);
            });
        });
    }

    /*! Eight moves at display cadence: input events, not polling a state. */
    function path(step: int, reverse: bool, done: var): void {
        if (step === 8) {
            done();
            return;
        }
        root.pointAt(reverse ? 7.5 - step / 2 : 4.5 + step / 2);
        root.after(16, () => root.path(step + 1, reverse, done));
    }

    function exited(): void {
        check.equal("exit settles within 120 ms plus one frame", root.slots().every(s => s.magnification === 1), true);
        root.pointAt(9);
        row.magnifying = true;
        root.after(136, () => {
            const launcher = row.children.find(child => child instanceof DockButton);
            check.near("launcher uses the same prompt response", launcher.magnification, 1.2);
            row.magnifying = false;
            root.pointerChecks();
        });
    }

    function pointerChecks(): void {
        const live = root.liveRow;
        check.equal("real dock row is available", live !== null, true);
        if (!live) { check.done(); return; }
        const slot = live.children.find(child => child instanceof DockSlot);
        root.inputIcon = slot ? slot.children[0] : live.children.find(child => child instanceof DockButton);
        // Begin outside the chrome before entering its clickable artwork.
        pointer.mouseMove(dock.contentItem, 0, 0, -1, Qt.NoButton, Qt.NoModifier);
        root.moveOnIcon(false);
        root.after(16, () => {
            check.near("pointer delivered over clickable artwork", live.pointerX, root.expectedX);
            root.moveOnIcon(true);
            root.after(16, () => {
                check.near("horizontal movement over artwork is delivered", live.pointerX, root.expectedX);
                const gap = root.inputIcon.mapToItem(dock.contentItem,
                    root.inputIcon.width + Appearance.m.dockGap / 2, root.inputIcon.height / 2);
                root.expectedX = Math.round(gap.x);
                pointer.mouseMove(dock.contentItem, gap.x, gap.y, -1, Qt.NoButton, Qt.NoModifier);
                root.after(16, () => {
                    check.near("gap movement uses the same pointer delivery", live.pointerX, root.expectedX);
                    check.done();
                });
            });
        });
    }

    function moveOnIcon(along: bool): void {
        const icon = root.inputIcon;
        const position = icon.mapToItem(dock.contentItem,
            icon.width * (along ? 0.65 : 0.35), icon.height / 2);
        root.expectedX = Math.round(position.x);
        pointer.mouseMove(dock.contentItem, position.x, position.y, -1, Qt.NoButton, Qt.NoModifier);
    }
}
