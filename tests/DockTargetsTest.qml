pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"
import "root:/modules/dock"

// The native effect must follow application identity and resting artwork,
// independently of hover, window count, exits and dock reordering.
Item {
    id: root
    Check { id: check }
    Until { id: ready }
    Surface { id: glass }
    DockRow {
        id: row
        screen: Quickshell.screens[0]
        panel: glass
        function reconcile(arriving: bool): void {}
    }

    function entry(key: string, addresses: var, leaving: bool, pinned: bool): var {
        return { key, leaving, arriving: false, item: {
            key, pinned, appId: key, name: key, icon: "utilities-terminal",
            entry: { id: key + ".desktop", startupClass: key + "-startup" },
            windows: addresses.map(address => ({ address, activated: false }))
        } };
    }

    function targets(): var {
        const value = row["windowTargets"];
        check.equal("dock exposes its window targets", Array.isArray(value), true);
        return value ?? [];
    }

    function start(): void {
        const a = root.entry("alpha", ["aaa", "aab"], false, true);
        const b = root.entry("beta", ["bbb"], false, false);
        row.drawn = [a, b];
        row.forceLayout();
        const first = root.targets();
        check.equal("all application windows have a target", first.length, 3);
        if (first.length === 3) {
            check.equal("targets retain window addresses", first.map(t => t.address).join(","), "aaa,aab,bbb");
            check.equal("window targets retain pinned membership", first.map(t => t.pinned).join(","), "true,true,false");
            check.near("two windows share their application's icon", first[0].x, first[1].x);
            check.near("target matches the resting icon center", first[0].x + first[0].width / 2,
                (row.screen.width - row.original.width) / 2 + row.original.centers[0]);
            check.near("target uses artwork width", first[0].width, Appearance.m.dockIcon);
            const before = JSON.stringify(first);
            row.magnifying = true;
            row.pointerX = first[0].x;
            check.equal("hover does not move the native target", JSON.stringify(root.targets()), before);
            row.drawn = [b, a];
            row.forceLayout();
            const reordered = root.targets();
            check.equal("reordering keeps addresses attached to applications", reordered[0].address, "bbb");
            check.equal("reordering moves alpha's target", reordered.find(t => t.address === "aaa").x > first[0].x, true);
        }
        row.drawn = [root.entry("alpha", ["aaa", "aab"], true, true), b];
        row.forceLayout();
        check.equal("departing applications publish no stale addresses", root.targets().map(t => t.address).join(","), "bbb");
        row.drawn = [];
        check.equal("empty dock releases every target", root.targets().length, 0);
        row.drawn = [root.entry("pinned", [], false, true), b];
        row.forceLayout();
        const apps = row["appTargets"] ?? [];
        check.equal("pins without windows publish a launch target", apps.some(t => t.appId === "pinned"), true);
        check.equal("application targets retain pinned membership", apps.find(t => t.appId === "pinned")?.pinned, true);
        check.equal("running applications keep their minimize targets", apps.find(t => t.appId === "beta")?.pinned, false);
        check.equal("launch targets include desktop and startup identities",
            apps.some(t => t.appId === "pinned.desktop") && apps.some(t => t.appId === "pinned-startup"), true);
        const pin = apps.find(t => t.appId === "pinned");
        if (pin) check.near("launch target uses the same resting artwork", pin.x + pin.width / 2,
            (row.screen.width - row.original.width) / 2 + row.original.centers[0]);
        row.drawn = [root.entry("pinned", [], true, true)];
        check.equal("departing pins release their launch identities", (row["appTargets"] ?? []).length, 0);
        check.done();
    }

    Component.onCompleted: ready.until(Settings.readyChanged, () => Settings.ready,
        () => Qt.callLater(root.start))
}
