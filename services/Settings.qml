pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/*!
    Persisted user preferences.

    Backed by a single JSON file under the Quickshell state directory.  Writes
    are debounced by the adapter itself (one write per property change batch) and
    the file is watched so an external edit is picked up live.
*/
Singleton {
    id: root

    readonly property bool effectiveDark: adapter.theme !== "light"
    readonly property bool doNotDisturb: adapter.doNotDisturb
    readonly property var pinnedApps: adapter.pinnedApps
    readonly property var dockOrder: adapter.dockOrder
    readonly property string accentColor: adapter.accentColor
    readonly property string backgroundLight: adapter.backgroundLight
    readonly property string backgroundDark: adapter.backgroundDark
    readonly property string fontFamily: adapter.fontFamily
    readonly property string wallpaper: adapter.wallpaper

    // ------------------------------------------------------------- overrides
    //
    // Every one of these replaces a value the design system or a service tuned
    // by hand.  A negative value means "unset", exactly as an empty string does
    // for the colour seeds above, so a fresh settings.json reproduces the
    // built-in look precisely.  The legal range for each lives with whoever owns
    // the value — the layout keys in Appearance.m.adjustable, the timings in the
    // service that acts on them — so nothing here has an opinion about them.

    readonly property int barHeight: adapter.barHeight
    readonly property int barGap: adapter.barGap
    readonly property int barSideGap: adapter.barSideGap
    readonly property int dockIcon: adapter.dockIcon
    readonly property int screenGap: adapter.screenGap
    readonly property int border: adapter.border
    readonly property int roundness: adapter.roundness
    readonly property int fontScale: adapter.fontScale
    readonly property int notificationTimeout: adapter.notificationTimeout
    readonly property int dockHideDelay: adapter.dockHideDelay

    /*! Every key `setOverride` accepts, and everything `resetOverrides` clears. */
    readonly property var overrideKeys: [
        "barHeight", "barGap", "barSideGap", "dockIcon", "screenGap",
        "border", "roundness", "fontScale", "notificationTimeout", "dockHideDelay"
    ]

    function setTheme(name: string): void {
        adapter.theme = name === "light" ? "light" : "dark";
    }

    function toggleTheme(): void {
        root.setTheme(root.effectiveDark ? "light" : "dark");
    }

    function setDoNotDisturb(on: bool): void {
        adapter.doNotDisturb = on;
    }

    function setAccentColor(value: string): void {
        adapter.accentColor = value;
    }

    /*! Applies to whichever theme is active; the other keeps its own colour. */
    function setBackgroundColor(value: string): void {
        if (adapter.theme === "light")
            adapter.backgroundLight = value;
        else
            adapter.backgroundDark = value;
    }

    /*! Empty means the shell's own face. Any installed family is accepted. */
    function setFontFamily(value: string): void {
        adapter.fontFamily = value;
    }

    /*! The picture the wallpaper is set from, as an absolute path. */
    function setWallpaper(path: string): void {
        adapter.wallpaper = path;
    }

    /*! Set one override. A negative value restores the built-in value. */
    function setOverride(key: string, value: int): void {
        // An undeclared key would have JsonAdapter grow a property nothing reads
        // and then write it out to the file forever.
        if (adapter[key] === undefined)
            return;
        adapter[key] = value;
    }

    function isOverridden(key: string): bool {
        return adapter[key] !== undefined && adapter[key] >= 0;
    }

    function resetOverrides(): void {
        for (const key of root.overrideKeys)
            adapter[key] = -1;
    }

    function isPinned(id: string): bool {
        return id !== "" && adapter.pinnedApps.indexOf(id) !== -1;
    }

    function pin(id: string): void {
        if (id === "" || root.isPinned(id))
            return;
        adapter.pinnedApps = adapter.pinnedApps.concat([id]);
    }

    function unpin(id: string): void {
        if (!root.isPinned(id))
            return;
        adapter.pinnedApps = adapter.pinnedApps.filter(x => x !== id);
    }

    /*! The order the user dragged the dock into, as application keys. */
    function setDockOrder(keys: var): void {
        adapter.dockOrder = keys;
    }

    readonly property bool ready: file.loaded

    JsonAdapter {
        id: adapter

        property string theme: "dark"
        property bool doNotDisturb: false
        property list<string> pinnedApps: []
        /*! Application keys in the order the dock shows them. Keys that are
            neither pinned nor running are ignored, so it never needs pruning. */
        property list<string> dockOrder: []
        /*! Empty means "use the built-in colour for the current theme". */
        property string accentColor: ""
        property string backgroundLight: ""
        property string backgroundDark: ""
        /*! Empty means the built-in font family. */
        property string fontFamily: ""
        /*! Absolute path; empty means the shell has never set the wallpaper and
            leaves whatever the wallpaper daemon was configured with alone. */
        property string wallpaper: ""
        /*! Layout and timing overrides. -1 means "use the tuned value". */
        property int barHeight: -1
        property int barGap: -1
        property int barSideGap: -1
        property int dockIcon: -1
        property int screenGap: -1
        property int border: -1
        property int roundness: -1
        property int fontScale: -1
        property int notificationTimeout: -1
        property int dockHideDelay: -1
    }

    FileView {
        id: file

        path: Quickshell.statePath("settings.json")
        adapter: adapter
        watchChanges: true
        printErrors: false

        onFileChanged: file.reload()
        onAdapterUpdated: file.writeAdapter()
        // A missing file on first run is expected; write the defaults out so the
        // user has something to edit by hand if they want to.
        onLoadFailed: file.writeAdapter()
    }
}
