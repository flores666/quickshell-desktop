pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/config"
import "root:/components"
import "root:/services"
import "root:/modules/dock"

/*! Real windows exercise grouping, saved order, pinning and reopening. Run
    only in the isolated compositor, like the Window* tests. */
Item {
    id: root

    Check { id: check }
    Until { id: wait }
    Surface { id: glass }
    DockRow { id: row; screen: Quickshell.screens[0]; panel: glass }
    readonly property string terminalKey: Apps.byId("kitty")?.id ?? "kitty"
    property var baselineKeys: []
    property var terminalSlot: null
    property var pending: null
    Process {
        id: first
        command: ["env", "KITTY_CACHE_DIRECTORY=" + Quickshell.env("XDG_CACHE_HOME") + "/dock-kitty",
            "kitty", "--config", "NONE", "--class", "kitty", "--title", "Dock lifecycle one", "sleep", "infinity"]
    }
    Process {
        id: second
        command: ["env", "KITTY_CACHE_DIRECTORY=" + Quickshell.env("XDG_CACHE_HOME") + "/dock-kitty",
            "kitty", "--config", "NONE", "--class", "kitty", "--title", "Dock lifecycle two", "sleep", "infinity"]
    }
    Timer {
        id: delay
        onTriggered: { const then = root.pending; root.pending = null; then(); }
    }
    function after(ms: int, then: var): void {
        root.pending = then;
        delay.interval = ms;
        delay.start();
    }
    function terminal(): var { return Dock.items.find(item => item.key === root.terminalKey); }
    function slot(): var { return row.children.find(c => c instanceof DockSlot && c.entry.key === root.terminalKey); }
    function windows(count: int, then: var): void {
        wait.until(Dock.itemsChanged, () => (root.terminal()?.windows.length ?? 0) === count, ok => {
            check.equal("terminal reaches " + count + " windows", ok, true);
            Qt.callLater(then);
        });
    }
    function last(label: string): void {
        check.equal(label + " appends before Applications", Dock.appKeys[Dock.appKeys.length - 1], root.terminalKey);
        check.equal(label + " preserves the existing order", JSON.stringify(Dock.appKeys.slice(0, -1)), JSON.stringify(root.baselineKeys));
    }

    Component.onCompleted: wait.until(Settings.readyChanged, () => Settings.ready, () => {
        wait.until(Apps.allChanged, () => Apps.all.length >= 5, () => {
            check.equal("terminal desktop entry is installed", Boolean(Apps.byId("kitty")), true);
            for (const id of Settings.pinnedApps.slice()) Settings.unpin(id);
            const pins = Apps.all.filter(e => e.id !== root.terminalKey).slice(0, 5).map(e => e.id);
            Settings.setDockOrder([pins[0], pins[1], root.terminalKey, ...pins.slice(2)]);
            for (const id of pins) Settings.pin(id);
            root.after(Appearance.t.base + Appearance.t.grace, () => {
                root.baselineKeys = Dock.appKeys.slice();
                check.equal("closed unpinned app has no saved place", Settings.dockOrder.includes(root.terminalKey), false);
                first.running = true;
                root.windows(1, root.opened);
            });
        });
    })
    function opened(): void {
        root.last("first launch");
        root.after(Appearance.t.base + Appearance.t.grace, () => {
            root.terminalSlot = root.slot();
            Dock.moveItem(Dock.appKeys.indexOf(root.terminalKey), 1);
            check.equal("running unpinned app can be arranged", Dock.appKeys[1], root.terminalKey);
            second.running = true;
            root.windows(2, () => {
                check.equal("second window keeps the arranged place", Dock.appKeys[1], root.terminalKey);
                check.equal("second window keeps the icon component", root.slot(), root.terminalSlot);
                check.near("second window does not replay arrival", root.slot().presence, 1);
                check.equal("several windows have one icon", Dock.items.filter(i => i.key === root.terminalKey).length, 1);
                first.running = false;
                root.windows(1, root.pinRunning);
            });
        });
    }
    function pinRunning(): void {
        check.equal("closing one window keeps the icon component", root.slot(), root.terminalSlot);
        check.equal("closing one window keeps the arranged place", Dock.appKeys[1], root.terminalKey);
        Dock.togglePinned(Apps.byId("kitty"));
        check.equal("pinning a running app keeps its place", Dock.appKeys[1], root.terminalKey);
        second.running = false;
        root.windows(0, () => {
            check.equal("closed pinned app stays in its place", Dock.appKeys[1], root.terminalKey);
            check.equal("closed pinned app keeps the icon component", root.slot(), root.terminalSlot);
            check.near("closed pinned app stays fully present", root.slot().presence, 1);
            Dock.togglePinned(Apps.byId("kitty"));
            root.after(Appearance.t.base + Appearance.t.grace, () => {
                check.equal("closed app unpinned from dock disappears", root.slot(), undefined);
                first.running = true;
                root.windows(1, root.reopened);
            });
        });
    }
    function reopened(): void {
        root.last("relaunch after unpinning");
        Dock.togglePinned(Apps.byId("kitty"));
        Dock.moveItem(Dock.appKeys.indexOf(root.terminalKey), 2);
        Dock.togglePinned(Apps.byId("kitty"));
        check.equal("unpinning a running app keeps its arranged place", Dock.appKeys[2], root.terminalKey);
        first.running = false;
        root.windows(0, () => {
            root.after(Appearance.t.base + Appearance.t.grace, () => {
                check.equal("last window removes an unpinned icon", root.slot(), undefined);
                check.equal("closing the last window releases its saved place", Settings.dockOrder.includes(root.terminalKey), false);
                first.running = true;
                root.windows(1, () => {
                    root.last("relaunch after closing");
                    first.running = false;
                    root.windows(0, () => check.done());
                });
            });
        });
    }
    Component.onDestruction: { first.running = false; second.running = false; }
}
