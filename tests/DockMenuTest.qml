pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/services"
import "root:/modules/common"
import "root:/modules/dock"

Item {
    id: root
    Check { id: check }
    Until { id: changed }
    WindowDriver { id: window }
    OverlaySurface { DockMenu { id: menu } }

    function group(): var {
        return Dock.items.find(i => i.appId === window.appClass) ?? null;
    }

    function count(n: int, then: var): void {
        changed.until(Dock.itemsChanged, () => (root.group()?.windows.length ?? 0) === n, ok => {
            check.equal("live dock group has " + n + " windows", ok, true);
            then();
        });
    }

    Component.onCompleted: window.open(() => root.count(1, () => {
        const subject = root.group();
        Overlay.openWith(Overlay.dockMenu, Quickshell.screens[0], 200, subject);
        check.equal("menu opens on the first window", menu.windowCount, 1);
        Compositor.exec(["env", "KITTY_CACHE_DIRECTORY=" + Quickshell.env("XDG_CACHE_HOME") + "/second",
            "kitty", "--config", "NONE", "--override", "confirm_os_window_close=0", "--class", window.appClass], "");
        root.count(2, () => {
            check.equal("open menu follows a second window", menu.windowCount, 2);
            check.equal("opening subject remains a snapshot", subject.windows.length, 1);
            menu.pickingWorkspace = true;
            Compositor.closeWindow(root.group().windows.find(w => "0x" + w.address !== window.address));
            root.count(1, () => {
                check.equal("open menu drops a closed window", menu.windowCount, 1);
                Compositor.exec(["env", "KITTY_CACHE_DIRECTORY=" + Quickshell.env("XDG_CACHE_HOME") + "/third",
                    "kitty", "--config", "NONE", "--override", "confirm_os_window_close=0", "--class", window.appClass], "");
                root.count(2, () => {
                    Dock.close(menu.item);
                    root.count(0, () => {
                        check.equal("last window leaves no running action", menu.item.running, false);
                        check.equal("last window leaves no stale window", menu.windowCount, 0);
                        check.equal("workspace submenu closes with its window", menu.pickingWorkspace, false);
                        Overlay.close();
                        check.equal("fade retains the application name", menu.item.name, subject.name);
                        check.done();
                    });
                });
            });
        });
    }))
}
