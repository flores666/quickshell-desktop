pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"
import "root:/modules/dock"

/*! Check identities and intermediate geometry, not just the final width. */
Item {
    id: root

    Check { id: check }
    Until { id: wait }
    Surface { id: glass }
    DockRow { id: row; screen: Quickshell.screens[0]; panel: glass }
    property var apps: []
    property var kept: ({})
    property var pending: null
    property int insertion: 0
    property var returning: null

    Timer {
        id: delay
        onTriggered: { const then = root.pending; root.pending = null; then(); }
    }
    function after(ms: int, then: var): void {
        root.pending = then;
        delay.interval = ms;
        delay.start();
    }
    function settled(then: var): void { root.after(Appearance.t.base + Appearance.t.grace, then); }
    function slots(): var { return row.children.filter(c => c instanceof DockSlot); }
    function slot(key: string): var { return root.slots().find(s => s.entry.key === key); }
    function remember(): void {
        const kept = ({});
        for (const slot of root.slots()) kept[slot.entry.key] = slot;
        root.kept = kept;
    }
    function unchanged(label: string, except: string): void {
        for (const key of Object.keys(root.kept)) {
            if (key === except) continue;
            const slot = root.slot(key);
            check.equal(label + " keeps " + key + " delegate", slot, root.kept[key]);
            check.near(label + " keeps " + key + " fully present", slot.presence, 1);
        }
    }
    function geometry(label: string): void {
        row.forceLayout();
        let x = 0;
        for (const slot of root.slots()) {
            // Row deliberately ignores a zero-width item until it grows.
            if (slot.width > 0) check.near(label + " slot " + slot.entry.key, slot.x, x);
            x += row.slotStride * slot.presence;
        }
        check.near(label + " launcher", row.launcherX, x);
        check.near(label + " total width", row.width, x + Appearance.m.dockSlot);
        check.near(label + " wave geometry", row.original.width, row.width);
    }

    Component.onCompleted: wait.until(Settings.readyChanged, () => Settings.ready, () => {
        wait.until(Apps.allChanged, () => Apps.all.length >= 8, () => {
            root.apps = Apps.all.slice(0, 8).map(e => e.id);
            for (const id of Settings.pinnedApps.slice()) Settings.unpin(id);
            Settings.setDockOrder([]);
            for (const id of root.apps.slice(0, 5)) Settings.pin(id);
            root.settled(root.insert);
        });
    })

    function insert(): void {
        root.remember();
        const keys = Dock.appKeys.slice();
        keys.splice([0, 2, keys.length][root.insertion], 0, root.apps[5]);
        // A valid explicit arrangement may insert an entry anywhere.
        Settings.setDockOrder(keys);
        Settings.pin(root.apps[5]);
        check.near("new entry begins absent at insertion " + root.insertion, root.slot(root.apps[5]).presence, 0);
        root.unchanged("insertion " + root.insertion, root.apps[5]);
        root.after(Appearance.t.grace, () => {
            const slot = root.slot(root.apps[5]);
            check.equal("new entry grows at its own position", slot.presence > 0 && slot.presence < 1, true);
            root.unchanged("during arrival", root.apps[5]);
            root.geometry("during arrival");
            root.settled(() => {
                root.geometry("arrived");
                root.remember();
                Settings.unpin(root.apps[5]);
                root.after(Appearance.t.grace, () => {
                    check.equal("leaving entry keeps its component", root.slot(root.apps[5]), root.kept[root.apps[5]]);
                    check.equal("leaving entry shrinks", root.slot(root.apps[5]).presence < 1, true);
                    root.unchanged("during departure", root.apps[5]);
                    root.geometry("during departure");
                    root.settled(() => {
                        check.equal("departed entry is removed", root.slot(root.apps[5]), undefined);
                        root.unchanged("after departure", root.apps[5]);
                        if (++root.insertion < 3) root.insert();
                        else root.dragChanges();
                    });
                });
            });
        });
    }
    function dragChanges(): void {
        const keys = Dock.appKeys.slice();
        const source = root.slot(keys[1]);
        source.dragMoved(row.slotStride * 2);
        Settings.setDockOrder([root.apps[5], ...keys]);
        Settings.pin(root.apps[5]);
        source.dragEnded();
        check.equal("arrival during a drag still moves its source after its target",
            Dock.appKeys.indexOf(keys[1]), Dock.appKeys.indexOf(keys[3]) + 1);
        const departing = root.slot(root.apps[5]);
        departing.dragMoved(row.slotStride);
        Settings.unpin(root.apps[5]);
        const afterRemoval = Dock.appKeys.slice();
        departing.dragEnded();
        check.equal("departing drag source never reorders another application",
            JSON.stringify(Dock.appKeys), JSON.stringify(afterRemoval));
        check.equal("interrupted drag releases the dock", row.drag, null);
        root.settled(root.reorder);
    }
    function reorder(): void {
        root.remember();
        const moved = Dock.appKeys[0];
        Dock.moveItem(0, Dock.items.length - 1);
        check.equal("reorder moves the requested application", Dock.appKeys[Dock.items.length - 1], moved);
        root.unchanged("reorder", "");
        root.geometry("reordered");
        root.returning = root.slot(Dock.appKeys[2]);
        Settings.unpin(root.returning.entry.key);
        root.after(Appearance.t.grace, root.revive);
    }
    function revive(): void {
        const key = root.returning.entry.key;
        const presence = root.returning.presence;
        Settings.pin(key);
        check.equal("reappearing application keeps its component", root.slot(key), root.returning);
        check.near("reappearing application keeps its current scale", root.slot(key).presence, presence);
        root.settled(() => {
            check.near("reappearing application reaches full size", root.slot(key).presence, 1);
            // An already queued removal must not remove a revived entry.
            root.slot(key).gone(key);
            root.after(0, () => {
                check.equal("queued departure cannot remove a live application", root.slot(key), root.returning);
                root.burst();
            });
        });
    }
    function burst(): void {
        root.remember();
        Settings.pin(root.apps[6]);
        Settings.pin(root.apps[7]);
        root.unchanged("burst", "");
        check.near("first burst arrival starts absent", root.slot(root.apps[6]).presence, 0);
        check.near("second burst arrival starts absent", root.slot(root.apps[7]).presence, 0);
        root.settled(() => {
            root.geometry("burst arrived");
            for (const id of Settings.pinnedApps.slice()) Settings.unpin(id);
            root.settled(() => {
                check.equal("empty dock has no application delegates", root.slots().length, 0);
                root.geometry("empty");
                Settings.pin(root.apps[0]);
                check.near("first application in an empty dock grows in", root.slot(root.apps[0]).presence, 0);
                root.settled(() => {
                    root.geometry("first application");
                    // Screens can disappear before their dock is destroyed.
                    Settings.setDockMagnificationEnabled(true);
                    row.screen = null;
                    row.pointerX = (Appearance.m.dockSlot - row.original.width) / 2;
                    row.magnifying = true;
                    check.near("detached dock keeps a finite wave", row.magnifications[0], Appearance.m.dockMagnification);
                    check.done();
                });
            });
        });
    }
}
