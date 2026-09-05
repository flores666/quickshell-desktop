pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland

/*!
    What the dock shows: the applications the user arranged, then anything
    pinned it has not heard of, then anything else that is running.

    Every open window gets its own icon — three terminals are three icons, each
    activating its own window. A pinned application collapses to a single
    launcher icon only while it has no windows open; once it does, its windows
    take that slot individually.
*/
Singleton {
    id: root

    /*!
        [{ key, appKey, entry, appId, name, icon, toplevel, pinned, running, active, grouped }]

        `toplevel` is null for a pinned application that is not running.
        `key` identifies the icon; `appKey` the application it belongs to, which
        is what the dock's arrangement is stored in terms of.
    */
    readonly property var items: {
        const out = [];
        const claimed = ({});

        /*!
            Whether a window is one a taskbar should stand for. Both tests are
            about what the compositor says the window is, not about which
            application it belongs to.

            A foreign-toplevel handle is the first: that protocol exists to list
            the windows a taskbar shows, so a Hyprland toplevel without one is
            not a window at all. Quickshell keeps a stub for every address it
            heard about in an event and never got data for, and those stubs are
            never dropped — nine of them were standing in this dock as anonymous
            icons that outlived the windows they came from.

            An application identity is the second: a window with neither an app
            id nor a class cannot be named or given an icon, and the ones that
            reach here are internal surfaces rather than windows — XWayland drag
            proxies most of all.

            A child window would be excluded by its handle's `parent`, which is
            what that field is for. Hyprland 0.56.2 never sends it: measured on
            the wire against a client that calls xdg_toplevel.set_parent, both
            natively and through XWayland, zero parent events for a dialog and a
            tool window it had just parented. The test is kept because it is the
            right one and costs a term; nothing else Hyprland reports separates
            a dialog from a window except `floating`, which is a state the user
            drives as well.
        */
        function isTaskbarWindow(w) {
            const handle = w.wayland;
            return Boolean(handle) && !handle.parent && Compositor.appIdOf(w) !== "";
        }

        // Group the open windows by the desktop entry they resolve to, keeping
        // Hyprland's own ordering so icons do not shuffle as focus moves.
        const byApp = ({});
        const order = [];
        for (const w of Compositor.toplevels) {
            if (!isTaskbarWindow(w))
                continue;
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
                appKey: key,
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

        // The application key a pinned id resolves to, so a pin and a running
        // window of the same application land in the same slot.
        const pinnedKeys = ({});
        for (const id of Settings.pinnedApps) {
            const pinnedEntry = Apps.byId(id);
            pinnedKeys[pinnedEntry ? pinnedEntry.id : id] = id;
        }

        // Whatever the user dragged into place first, then pins it has not been
        // told about, then the rest of what is running, in Hyprland's order.
        const keys = [];
        function want(key) {
            if (claimed[key] || (!(key in byApp) && !(key in pinnedKeys)))
                return;
            claimed[key] = true;
            keys.push(key);
        }
        for (const key of Settings.dockOrder)
            want(key);
        for (const key of Object.keys(pinnedKeys))
            want(key);
        for (const key of order)
            want(key);

        for (const key of keys) {
            const group = byApp[key];
            const pinned = key in pinnedKeys;
            if (group) {
                for (const w of group.windows)
                    out.push(windowEntry(key, group, w, pinned));
                continue;
            }
            const id = pinnedKeys[key];
            const pinnedEntry = Apps.byId(id);
            out.push({
                key: `p:${key}`,
                appKey: key,
                entry: pinnedEntry,
                appId: pinnedEntry && pinnedEntry.startupClass !== ""
                    ? pinnedEntry.startupClass : id,
                toplevel: null,
                pinned: true,
                running: false,
                active: false,
                name: pinnedEntry ? pinnedEntry.name : id,
                grouped: false,
                icon: pinnedEntry ? pinnedEntry.icon : id
            });
        }

        return out;
    }

    /*! The applications the dock is showing, in the order it shows them. */
    readonly property var appKeys: {
        const out = [];
        for (const item of root.items)
            if (out.indexOf(item.appKey) === -1)
                out.push(item.appKey);
        return out;
    }

    /*!
        Move the application an icon belongs to so that it sits where the icon at
        `to` is now. Stored as an arrangement of applications rather than of
        icons, because a window's icon lives only as long as its window does.
    */
    function moveItem(from: int, to: int): void {
        const items = root.items;
        if (from < 0 || to < 0 || from >= items.length || to >= items.length)
            return;
        const moved = items[from].appKey;
        const onto = items[to].appKey;
        if (moved === onto)
            return;
        const keys = root.appKeys.filter(k => k !== moved);
        const at = keys.indexOf(onto);
        keys.splice(to > from ? at + 1 : at, 0, moved);
        Settings.setDockOrder(keys);
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
        if (Settings.isPinned(item.entry.id)) {
            Settings.unpin(item.entry.id);
            return;
        }
        // Freeze the arrangement first: pinning would otherwise promote the
        // application ahead of everything unpinned, and its icon would jump out
        // from under the pointer that just asked for it.
        Settings.setDockOrder(root.appKeys);
        Settings.pin(item.entry.id);
    }
}
