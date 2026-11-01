pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"
import "root:/modules/dock"

Item {
    id: root
    Check { id: check }
    Until { id: wait }
    Surface { id: panel }
    DockRow {
        id: row
        screen: Quickshell.screens[0]
        panel: panel
        function reconcile(arriving: bool): void {}
    }
    property int count: 9
    property int stage: 0
    property real restingWidth: 0
    property var edges: null
    property var kept: []
    Timer { id: settle; interval: Dock.magnificationDuration + Appearance.t.grace; onTriggered: root.advance() }

    function icons(): var {
        return row.children.filter(c => c instanceof DockSlot).map(c => c.children[0])
            .concat(row.children.filter(c => c instanceof DockButton));
    }
    function artwork(item: var): var {
        return item.children.find(c => c instanceof AppIcon || c instanceof Icon);
    }
    function bounds(): var {
        return root.icons().map(item => {
            const image = root.artwork(item);
            return { start: image.mapToItem(row, 0, 0).x,
                end: image.mapToItem(row, image.width, 0).x };
        });
    }
    function point(index: real): void {
        row.pointerX = (row.screen.width - row.original.width) / 2
            + Appearance.m.dockSlot / 2 + index * row.slotStride;
    }
    function start(): void {
        row.magnifying = false;
        row.drawn = Array.from({ length: root.count }, (_, i) => ({ key: "span-" + i,
            leaving: false, arriving: false,
            item: { key: "span-" + i, name: "Test", icon: "utilities-terminal", windows: [] } }));
        row.forceLayout();
        root.stage = -1;
        settle.start();
    }
    Component.onCompleted: wait.until(Settings.readyChanged, () => Settings.ready, () => {
        Settings.setOverride("dockIcon", 48);
        Settings.setOverride("dockZoom", 20);
        Settings.setOverride("dockWaveWidth", 200);
        Settings.setOverride("dockMagnificationDuration", 40);
        Qt.callLater(root.start);
    })
    function advance(): void {
        row.forceLayout();
        if (root.stage === -1) {
            root.restingWidth = row.width;
            const b = root.bounds(); root.edges = { start:b[0].start, end:b[b.length - 1].end };
            root.kept = root.icons();
            root.point(root.count / 2);
            row.magnifying = true;
            root.stage = 0;
            settle.start();
            return;
        }
        const b = root.bounds();
        const name = root.count + " apps, phase " + root.stage;
        check.near(name + ": fixed row width", row.width, root.restingWidth);
        check.near(name + ": first artwork edge fixed", b[0].start, root.edges.start);
        check.near(name + ": last artwork edge fixed", b[b.length - 1].end, root.edges.end);
        check.equal(name + ": clear artwork gaps", b.every((v,i) => i === 0
            || v.start - b[i-1].end >= Appearance.s.xxs - 0.001), true);
        check.equal(name + ": scales stay between 100% and 120%",
            root.icons().every(c => c.magnification >= 1 && c.magnification <= 1.2), true);
        check.equal(name + ": components retained", root.icons().every((c,i) => c === root.kept[i]), true);
        if (root.stage === 0) root.point(0);
        else if (root.stage === 1) root.point(root.count);
        else if (root.stage === 2) row.magnifying = false;
        else {
            if (root.count === 9) { root.count = 1; root.start(); }
            else if (root.count === 1) { root.count = 0; root.start(); }
            else check.done();
            return;
        }
        root.stage++;
        settle.start();
    }
}
