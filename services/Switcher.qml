pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland

/*!
    The window switcher, as macOS's Command-Tab: hold Alt and press Tab to go
    round the windows of the workspace in front of you, the one used most
    recently first, and let go of Alt to bring the one chosen forward. One
    quick Alt+Tab is the window used before. Minimized windows come last, and
    come back to the workspace when chosen (Compositor.focusWindow).

    Hyprland holds the keys (hyprland.conf) and each reaches here as a global
    shortcut (ShellIpc). The switcher takes no keyboard focus, so the window
    in front keeps it until the one chosen takes it.
*/
Singleton {
    id: root

    /*! Window addresses, the most recently focused first. */
    property var recent: []

    Connections {
        target: Compositor

        function onActiveToplevelChanged(): void {
            const address = Compositor.activeToplevel?.address ?? "";
            if (address !== "")
                root.recent = [address].concat(root.recent.filter(a => a !== address)).slice(0, 64);
        }
    }

    /*! Whether Alt+Tab is under way. */
    property bool active: false
    /*! [{ window, icon, name, minimized }]: what it goes round, taken as it
        opens, so nothing reorders while it is open. */
    property var entries: []
    property int index: 0
    readonly property var current: root.entries[root.index] ?? null

    /*! The windows the dock stands for — the same test of what is a window —
        on the workspace in front, or a special one shown over it, then the
        minimized ones; each part by how recently it had focus. */
    function snapshot(): var {
        const shown = [Compositor.focusedWorkspace, Compositor.activeToplevel?.workspace ?? null];
        const rank = w => {
            const at = root.recent.indexOf(w.address);
            return at === -1 ? root.recent.length : at;
        };
        const here = [];
        const minimized = [];
        for (const item of Dock.items) {
            for (const w of item.windows) {
                const entry = {
                    window: w,
                    icon: item.icon,
                    name: item.name,
                    minimized: w.workspace?.name === Compositor.minimizedWorkspace
                };
                if (entry.minimized)
                    minimized.push(entry);
                else if (w.workspace && shown.indexOf(w.workspace) !== -1)
                    here.push(entry);
            }
        }
        const byRank = (a, b) => rank(a.window) - rank(b.window);
        return here.sort(byRank).concat(minimized.sort(byRank));
    }

    /*! Alt+Tab (1) or Alt+` (-1): the next window round, opening the switcher
        on the window in front, so that one step is the window before it. */
    function step(delta: int): void {
        if (!root.active) {
            const entries = root.snapshot();
            if (entries.length === 0)
                return;
            const front = entries.findIndex(e => e.window === Compositor.activeToplevel);
            root.entries = entries;
            root.index = front !== -1 ? front : delta > 0 ? -1 : 0;
            root.active = true;
            Overlay.close();
        }
        const n = root.entries.length;
        root.index = ((root.index + delta) % n + n) % n;
    }

    /*! The pointer is on an entry: it is the one chosen. */
    function point(at: int): void {
        if (root.active && at >= 0 && at < root.entries.length)
            root.index = at;
    }

    /*! Alt let go of: the window chosen comes forward. */
    function commit(): void {
        if (!root.active)
            return;
        const window = root.current?.window ?? null;
        root.finish();
        if (window)
            Compositor.focusWindow(window);
    }

    /*! A click on an entry, Alt still held: that one, and the submap Alt+Tab
        entered is left now rather than when Alt is let go of. */
    function choose(at: int): void {
        root.point(at);
        root.commit();
        Hyprland.dispatch("submap reset");
    }

    function cancel(): void {
        if (root.active)
            root.finish();
    }

    function finish(): void {
        root.active = false;
        root.entries = [];
        root.index = 0;
    }
}
