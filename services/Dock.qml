pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland

/*!
    What the dock shows: pinned applications first, then everything else that is
    running.

    Every open window gets its own icon — three terminals are three icons, each
    activating its own window. A pinned application collapses to a single
    launcher icon only while it has no windows open; once it does, its windows
    take that slot individually.
*/
Singleton {
    id: root

    /*!
        [{ key, entry, appId, name, icon, toplevel, pinned, running, active, grouped }]

        `toplevel` is null for a pinned application that is not running.
    */
    readonly property var items: {
        const out = [];
        const claimed = ({});

        // Group the open windows by the desktop entry they resolve to, keeping
        // Hyprland's own ordering so icons do not shuffle as focus moves.
        const byApp = ({});
        const order = [];
        for (const w of Compositor.toplevels) {
            const appId = Compositor.appIdOf(w);
            const entry = Apps.byAppId(appId);
            const key = entry ? entry.id : (appId !== "" ? appId : "window");
            if (!(key in byApp)) {
                byApp[key] = { entry, appId, windows: [] };
                order.push(key);
            }
            byApp[key].windows.push(w);
        }

        function windowEntry(key, group, w, pinned) {
            const name = group.entry ? group.entry.name
                : (group.appId !== "" ? group.appId : qsTr("Window"));
            return {
                key: `w:${w.address}`,
                entry: group.entry,
                appId: group.appId,
                toplevel: w,
                pinned,
                running: true,
                active: w.activated,
                name,
                // Window titles are deliberately *not* read here: they change
                // constantly, and this list would be rebuilt on every keystroke
                // in a terminal. Whoever needs the title reads it off the
                // toplevel, which only re-evaluates that one binding.
                grouped: group.windows.length > 1,
                icon: group.entry ? group.entry.icon : group.appId
            };
        }

        for (const id of Settings.pinnedApps) {
            const pinnedEntry = Apps.byId(id);
            const key = pinnedEntry ? pinnedEntry.id : id;
            const group = byApp[key];
            if (group) {
                claimed[key] = true;
                for (const w of group.windows)
                    out.push(windowEntry(key, group, w, true));
            } else {
                const name = pinnedEntry ? pinnedEntry.name : id;
                out.push({
                    key: `p:${key}`,
                    entry: pinnedEntry,
                    appId: pinnedEntry && pinnedEntry.startupClass !== ""
                        ? pinnedEntry.startupClass : id,
                    toplevel: null,
                    pinned: true,
                    running: false,
                    active: false,
                    name,
                    grouped: false,
                    icon: pinnedEntry ? pinnedEntry.icon : id
                });
            }
        }

        for (const key of order) {
            if (claimed[key])
                continue;
            const group = byApp[key];
            for (const w of group.windows)
                out.push(windowEntry(key, group, w, false));
        }

        return out;
    }

    /*! Focus this item's window, or launch the application if it has none. */
    function activate(item: var): void {
        if (!item)
            return;
        if (item.toplevel)
            Compositor.focusWindow(item.toplevel);
        else if (item.entry)
            Apps.launch(item.entry);
    }

    function launchNew(item: var): void {
        if (item && item.entry)
            Apps.launch(item.entry);
    }

    function close(item: var): void {
        if (item && item.toplevel)
            Compositor.closeWindow(item.toplevel);
    }

    function togglePinned(item: var): void {
        if (!item || !item.entry)
            return;
        if (Settings.isPinned(item.entry.id))
            Settings.unpin(item.entry.id);
        else
            Settings.pin(item.entry.id);
    }
}
