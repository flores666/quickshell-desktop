pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

/*!
    What the dock shows: the applications the user arranged, then anything
    pinned it has not heard of, then anything else that is running.

    One icon per application, however many windows it has open — three
    terminals are one icon carrying a count, and the dock's preview tells them
    apart, on a click as on a hover.
*/
Singleton {
    id: root

    /*! How long the dock waits after the pointer leaves before it slides away.
        Long enough by default to cross the gap to a menu it opened. The range
        is also the settings row's. */
    readonly property var hideDelayRange: ({ min: 0, max: 5000, def: 700 })
    readonly property int hideDelay: Settings.pick("dockHideDelay", root.hideDelayRange)

    /*!
        [{ key, entry, appId, name, icon, windows, pinned, running }]

        `key` is the application, which is what the dock's arrangement is
        stored in terms of; `windows` its open windows in Hyprland's order,
        empty for a pinned application that is not running.
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

        // The application key a pinned id resolves to, so a pin and a running
        // window of the same application land in the same slot. A pin whose
        // application is not installed here is left out, not drawn as an icon
        // that launches nothing — pins travel with the profile, and come back
        // when the application does.
        const pinnedKeys = ({});
        for (const id of Settings.pinnedApps) {
            const pinnedEntry = Apps.byId(id);
            if (pinnedEntry)
                pinnedKeys[pinnedEntry.id] = id;
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
            const entry = group ? group.entry : Apps.byId(pinnedKeys[key]);
            const appId = group ? group.appId
                : (entry.startupClass !== "" ? entry.startupClass : pinnedKeys[key]);
            out.push({
                key,
                entry,
                appId,
                name: entry ? entry.name : (appId !== "" ? appId : qsTr("Window")),
                icon: entry ? entry.icon : appId,
                // Window titles are deliberately *not* read here: they change
                // constantly, and this list would be rebuilt on every keystroke
                // in a terminal. Nor is which window has focus: every focus
                // change rebuilt every icon, and the one under the pointer lost
                // its hover, flashing the cursor. Whoever needs either reads it
                // off the toplevel, which only re-evaluates that one binding.
                windows: group ? group.windows : [],
                pinned: key in pinnedKeys,
                running: Boolean(group)
            });
        }

        return out;
    }

    /*! The applications the dock is showing, in the order it shows them. */
    readonly property var appKeys: root.items.map(item => item.key)

    /*! Move the application at `from` to where the one at `to` is now. */
    function moveItem(from: int, to: int): void {
        const items = root.items;
        if (from < 0 || to < 0 || from >= items.length || to >= items.length)
            return;
        const moved = items[from].key;
        const onto = items[to].key;
        if (moved === onto)
            return;
        const keys = root.appKeys.filter(k => k !== moved);
        const at = keys.indexOf(onto);
        keys.splice(to > from ? at + 1 : at, 0, moved);
        Settings.setDockOrder(keys);
    }

    /*!
        Bring an application forward: its window, brought back first if it was
        minimized (Compositor.focusWindow), or the application launched if it
        has none. One with several has the dock's preview to pick from; asked
        anyway, the first of them comes.
    */
    function activate(item: var): void {
        if (!item)
            return;
        if (item.windows.length > 0)
            Compositor.focusWindow(item.windows[0]);
        else if (item.entry)
            Apps.launch(item.entry);
    }

    function launchNew(item: var): void {
        if (item && item.entry)
            Apps.launch(item.entry);
    }

    /*! Close every window the application has open. */
    function close(item: var): void {
        for (const w of item?.windows ?? [])
            Compositor.closeWindow(w);
    }

    /*! Pin a desktop entry, or unpin it: from its icon here, or the launcher. */
    function togglePinned(entry: var): void {
        if (!entry)
            return;
        if (Settings.isPinned(entry.id)) {
            Settings.unpin(entry.id);
            return;
        }
        // Freeze the arrangement first: pinning would otherwise promote the
        // application ahead of everything unpinned, and its icon would jump out
        // from under the pointer that just asked for it. An application
        // pinned from the launcher with no window open joins the end.
        Settings.setDockOrder(root.appKeys);
        Settings.pin(entry.id);
    }
}
