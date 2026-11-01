pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"
import "root:/modules/dock"

/*! The wave is sampled in the resting layout, while its animated growth
    allocates space in the live row. Neither can feed back into the other. */
Item {
    id: root

    Check { id: check }
    property var kept: []
    property real restingWidth: 0
    property real restingBottom: 0
    property var centeredTargets: []
    property int step: 0

    Surface { id: glass }
    DockRow {
        id: row
        screen: Quickshell.screens[0]
        panel: glass
        // This fixture owns its nine applications, independent of what is
        // installed or running in the compositor hosting the test.
        function reconcile(arriving: bool): void {}
    }

    function slots(): var {
        return row.children.filter(child => child instanceof DockSlot);
    }

    function pointAt(index: real): void {
        row.pointerX = (row.screen.width - row.original.width) / 2
            + Appearance.m.dockSlot / 2 + index * row.slotStride;
    }

    function start(): void {
        row.drawn = Array.from({ length: 9 }, (_, i) => ({
            key: "wave-test-" + i, leaving: false, arriving: false,
            item: { key: "wave-test-" + i, name: "Test", icon: "utilities-terminal", windows: [] }
        }));
        row.forceLayout();
        root.kept = root.slots();
        root.restingWidth = row.original.width;
        root.restingBottom = root.kept[4].children[0].y + root.kept[4].children[0].height;
        root.pointAt(4);
        row.magnifying = true;
        check.near("center target is exactly 120%", row.magnifications[4], 1.2);
        check.within("first neighbor is 117–118%", row.magnifications[3], 1.175, 0.005);
        check.within("second neighbor is 110–112%", row.magnifications[2], 1.11, 0.01);
        check.equal("scale eases instead of jumping", root.kept[4].magnification < 1.2, true);
        root.centeredTargets = row.magnifications;
        settle.start();
    }

    Component.onCompleted: wait.until(Settings.readyChanged, () => Settings.ready,
        () => Qt.callLater(root.start))
    Until { id: wait }

    Timer {
        id: settle
        interval: Appearance.t.fast + Appearance.t.grace
        onTriggered: root.advance()
    }

    function advance(): void {
        row.forceLayout();
        if (root.step === 0) {
            check.near("center settles at 120%", root.kept[4].magnification, 1.2);
            check.near("layout growth never changes the resting width", row.original.width, root.restingWidth);
            check.equal("resting pointer has no layout feedback",
                JSON.stringify(row.magnifications), JSON.stringify(root.centeredTargets));
            check.near("magnification keeps the icon row width fixed", row.width, root.restingWidth);
            for (let i = 0; i < root.kept.length; ++i) {
                const slot = root.kept[i];
                const icon = slot.children[0];
                check.near("bottom stays fixed " + i, icon.y + icon.height, root.restingBottom);
                if (i > 0)
                    check.equal("neighbor artwork stays separated " + i,
                        slot.x - root.kept[i - 1].x - root.kept[i - 1].children[0].width
                            + Appearance.m.dockInset * 2 >= Appearance.s.xxs - 0.001, true);
            }
            root.pointAt(4.001);
            check.equal("subpixel movement changes the wave continuously",
                Math.abs(row.magnifications[4] - 1.2) < 0.00001 && row.magnifications[5] > root.centeredTargets[5], true);
            let capped = true;
            for (let i = -2; i < 12; i += 0.125) {
                root.pointAt(i);
                capped = capped && row.magnifications.every(s => s >= 1 && s <= 1.2);
            }
            check.equal("strict cap across the full subpixel path", capped, true);
            root.pointAt(4.5);
            check.near("between icons: equal peaks", row.magnifications[4], row.magnifications[5]);
            row.magnifying = false;
            root.step++;
            settle.start();
        } else {
            check.near("leaving restores the row width", row.width, root.restingWidth);
            check.equal("leaving restores every icon", root.slots().every(s => s.magnification === 1), true);
            check.equal("pointer motion preserves every component",
                root.slots().every((s, i) => s === root.kept[i]), true);
            check.done();
        }
    }
}
