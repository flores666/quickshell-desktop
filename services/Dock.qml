pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

/*!
    What the dock shows: the slots the user arranged, then anything pinned
    it has not heard of, then anything else that is running.

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

    /*! A retarget starts moving immediately; the chosen duration is shared
        by application icons and the launcher, on entry, travel and exit. */
    readonly property var magnificationDurationRange: ({ min: 40, max: 300, def: 120 })
    readonly property int magnificationDuration: Settings.pick("dockMagnificationDuration", root.magnificationDurationRange)

    /*!
        [{ key, entry, appId, name, icon, windows, pinned, running }]

        `key` is the application, which is what the dock's arrangement is
        stored in terms of; `windows` its open windows in Hyprland's order,
        empty for a pinned application that is not running.
    */
    readonly property var applications: {
        const out = [];

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
        const byApp = new Map();
        for (const w of Compositor.toplevels) {
            if (!isTaskbarWindow(w))
                continue;
            const appId = Compositor.appIdOf(w);
            const entry = Apps.byAppId(appId);
            const key = entry ? entry.id : appId;
            if (!byApp.has(key))
                byApp.set(key, { entry, appId, windows: [] });
            byApp.get(key).windows.push(w);
        }

        // The application key a pinned id resolves to, so a pin and a running
        // window of the same application land in the same slot. A pin whose
        // application is not installed here is left out, not drawn as an icon
        // that launches nothing — pins travel with the profile, and come back
        // when the application does.
        const pins = new Map();
        for (const id of Settings.pinnedApps) {
            const pinnedEntry = Apps.byId(id);
            if (pinnedEntry)
                pins.set(pinnedEntry.id, { entry: pinnedEntry, id });
        }

        for (const key of new Set([...pins.keys(), ...byApp.keys()])) {
            const group = byApp.get(key);
            const pinned = pins.get(key);
            const entry = group ? group.entry : pinned.entry;
            const appId = group ? group.appId : (entry.startupClass || pinned.id);
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
                pinned: Boolean(pinned),
                running: Boolean(group)
            });
        }

        return out;
    }

    /*! Built-in controls use non-string keys so they cannot collide with apps. */
    readonly property var notesSlot: ({ key: null, widget: "daily-notes" })
    readonly property var launcherSlot: ({ key: 1, widget: "applications" })
    readonly property var controls: [root.notesSlot, root.launcherSlot]

    function isAppSlot(entry: var): bool {
        return typeof entry?.key === "string";
    }

    function keyForOrder(entry: var): var {
        return typeof entry === "string" ? entry : root.controls.find(control => control.widget === entry?.widget)?.key;
    }

    readonly property var layoutKeys: {
        const saved = Settings.dockOrder.map(entry => root.keyForOrder(entry)).filter(key => key !== undefined);
        const keys = new Set(saved.includes(root.notesSlot.key) ? saved : [root.notesSlot.key, ...saved]);
        for (const app of root.applications)
            keys.add(app.key);
        keys.add(root.launcherSlot.key);
        return [...keys];
    }

    readonly property var slots: {
        const byKey = new Map(root.applications.map(app => [app.key, app]));
        byKey.set(root.launcherSlot.key, root.launcherSlot);
        if (Settings.dailyNotesEnabled)
            byKey.set(root.notesSlot.key, root.notesSlot);
        return root.layoutKeys.filter(key => byKey.has(key)).map(key => byKey.get(key));
    }
    readonly property var slotKeys: root.slots.map(entry => entry.key)

    /*! The applications the dock is showing, in the order it shows them. */
    readonly property var items: root.slots.filter(entry => root.isAppSlot(entry))
    readonly property var appKeys: root.items.map(item => item.key)

    // Settings can load before the compositor reports its existing windows.
    // Keep saved app positions around moved controls until the apps appear.
    property var awaitingApps: null

    /*! A closed, unpinned application has given up its place. Keeping its
        old key made the next launch appear among the arranged icons instead
        of joining the end. Keep unavailable pins, whose entries may return.
        Defer until the model and the settings file have finished updating. */
    function forgetClosed(): void {
        if (!Settings.ready)
            return;
        const saved = Settings.dockOrder;
        const present = new Set(root.appKeys);
        const arranged = saved.findIndex(entry => root.keyForOrder(entry) === root.notesSlot.key) > 0
            || saved.some(entry => root.keyForOrder(entry) === root.launcherSlot.key);
        if (root.awaitingApps === null) {
            root.awaitingApps = new Set(arranged ? saved.filter(key => typeof key === "string"
                && !present.has(key) && !Settings.isPinned(key)) : []);
            if (root.awaitingApps.size > 0)
                Compositor.readWindowAppIds();
        }
        if (!arranged)
            root.awaitingApps.clear();
        for (const key of root.awaitingApps) {
            if (!saved.includes(key))
                root.awaitingApps.delete(key);
        }
        const keys = saved.filter(entry => typeof entry === "string"
            ? present.has(entry) || Settings.isPinned(entry) || root.awaitingApps.has(entry)
            : root.keyForOrder(entry) !== undefined);
        if (keys.length !== saved.length)
            Settings.setDockOrder(keys);
    }

    onItemsChanged: {
        if (root.awaitingApps?.size > 0) {
            for (const item of root.items)
                root.awaitingApps.delete(item.key);
        }
        Qt.callLater(root.forgetClosed);
    }
    Component.onCompleted: Qt.callLater(root.forgetClosed)
    Connections {
        target: Settings
        function onReadyChanged(): void { Qt.callLater(root.forgetClosed); }
    }

    Connections {
        target: Compositor
        function onWindowAppIdsRead(appIds: var): void {
            if (appIds === null || !root.awaitingApps?.size)
                return;
            const open = new Set(appIds.map(id => Apps.byAppId(id)?.id ?? id));
            for (const key of root.awaitingApps) {
                if (!open.has(key))
                    root.awaitingApps.delete(key);
            }
            Qt.callLater(root.forgetClosed);
        }
        function onWindowClosed(): void {
            if (root.awaitingApps?.size > 0)
                Compositor.readWindowAppIds();
        }
    }

    function saveLayout(keys: var): void {
        // An implicit launcher follows new apps; an implicit widget starts the row.
        const start = keys[0] === root.notesSlot.key ? 1 : 0;
        const end = keys[keys.length - 1] === root.launcherSlot.key ? -1 : keys.length;
        Settings.setDockOrder(keys.slice(start, end).map(key => typeof key === "string" ? key
            : { widget: root.controls.find(control => control.key === key).widget }));
    }

    /*! Move among visible slots, retaining the order of hidden entries. */
    function moveSlot(from: var, to: var): void {
        const source = root.slotKeys.indexOf(from);
        const target = root.slotKeys.indexOf(to);
        if (!Settings.ready || source === -1 || target === -1 || source === target)
            return;
        const keys = root.layoutKeys.filter(key => key !== from);
        keys.splice(keys.indexOf(to) + (target > source ? 1 : 0), 0, from);
        root.saveLayout(keys);
    }

    /*! Move the application at `from` to where the one at `to` is now. */
    function moveItem(from: int, to: int): void {
        root.moveSlot(root.appKeys[from], root.appKeys[to]);
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
        root.saveLayout(root.layoutKeys);
        Settings.pin(entry.id);
    }
}
