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
    /*! Colours made in the picker, newest first, and the ones pinned to stay.
        One pair for every seed: each row offers only those that fall inside
        its own range (Appearance.seedRange), which keeps them apart. */
    readonly property var recentColors: adapter.recentColors
    readonly property var pinnedColors: adapter.pinnedColors
    /*! How many unpinned colours are remembered, across all the seeds. */
    readonly property int recentColorLimit: 24
    readonly property string fontFamily: adapter.fontFamily
    /*! The GTK interface font as it was before the shell first set it, so that
        going back to Default can give it back; empty while the shell has not. */
    readonly property string systemFontBefore: adapter.systemFontBefore
    readonly property string wallpaper: adapter.wallpaper
    /*! The shell's corners follow Hyprland's window rounding; see Radii. */
    readonly property bool roundnessFollowsWindows: adapter.roundnessFollowsWindows

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
    // Hyprland options; ranges and encoding in CompositorOptions.spec.
    readonly property int hyprGapsIn: adapter.hyprGapsIn
    readonly property int hyprGapsOut: adapter.hyprGapsOut
    readonly property int hyprBorder: adapter.hyprBorder
    readonly property int hyprRounding: adapter.hyprRounding
    readonly property int hyprBlur: adapter.hyprBlur
    readonly property int hyprAnimations: adapter.hyprAnimations
    readonly property int hyprActiveOpacity: adapter.hyprActiveOpacity
    readonly property int hyprInactiveOpacity: adapter.hyprInactiveOpacity
    readonly property int hyprMouseSpeed: adapter.hyprMouseSpeed
    readonly property int hyprMouseAccel: adapter.hyprMouseAccel
    readonly property int hyprMouseScroll: adapter.hyprMouseScroll
    readonly property int hyprTouchpadScroll: adapter.hyprTouchpadScroll
    readonly property int hyprTouchpadSpeed: adapter.hyprTouchpadSpeed
    readonly property int hyprNaturalScroll: adapter.hyprNaturalScroll
    readonly property int hyprTapToClick: adapter.hyprTapToClick

    /*! Every key `setOverride` accepts, and everything `resetOverrides` clears. */
    readonly property var overrideKeys: [
        "barHeight", "barGap", "barSideGap", "dockIcon", "screenGap",
        "border", "roundness", "fontScale", "notificationTimeout", "dockHideDelay",
        "hyprGapsIn", "hyprGapsOut", "hyprBorder", "hyprRounding", "hyprBlur",
        "hyprAnimations", "hyprActiveOpacity", "hyprInactiveOpacity", "hyprMouseSpeed",
        "hyprMouseAccel", "hyprTouchpadSpeed", "hyprNaturalScroll", "hyprTapToClick",
        "hyprMouseScroll", "hyprTouchpadScroll"
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

    function setRoundnessFollowsWindows(on: bool): void {
        adapter.roundnessFollowsWindows = on;
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

    /*! Puts a picked colour at the front of the recent ones, in place of
        `replacing` if that is given: one visit to the picker is one colour, not
        every stop along the way. A pinned colour keeps its place. */
    function rememberColor(value: string, replacing: string): void {
        if (value === "" || root.isColorPinned(value))
            return;
        const gone = [value, replacing ?? ""];
        adapter.recentColors = [value].concat(adapter.recentColors.filter(x => !gone.includes(x)))
            .slice(0, root.recentColorLimit);
    }

    function isColorPinned(value: string): bool {
        return adapter.pinnedColors.indexOf(value) !== -1;
    }

    /*! Pinning takes a colour out of the recent ones so it never ages out;
        unpinning returns it to the front of them. */
    function togglePinnedColor(value: string): void {
        if (value === "")
            return;
        if (root.isColorPinned(value)) {
            adapter.pinnedColors = adapter.pinnedColors.filter(x => x !== value);
            root.rememberColor(value, "");
        } else {
            adapter.recentColors = adapter.recentColors.filter(x => x !== value);
            adapter.pinnedColors = adapter.pinnedColors.concat([value]);
        }
    }

    /*! Empty means the shell's own face. Any installed family is accepted. */
    function setFontFamily(value: string): void {
        adapter.fontFamily = value;
    }

    function setSystemFontBefore(value: string): void {
        adapter.systemFontBefore = value;
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
        property bool roundnessFollowsWindows: false
        property list<string> pinnedApps: []
        /*! Application keys in the order the dock shows them. Keys that are
            neither pinned nor running are ignored, so it never needs pruning. */
        property list<string> dockOrder: []
        /*! Empty means "use the built-in colour for the current theme". */
        property string accentColor: ""
        property string backgroundLight: ""
        property string backgroundDark: ""
        property list<string> recentColors: []
        property list<string> pinnedColors: []
        /*! Empty means the built-in font family. */
        property string fontFamily: ""
        property string systemFontBefore: ""
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
        /*! Hyprland overrides, pushed as keywords by CompositorOptions. */
        property int hyprGapsIn: -1
        property int hyprGapsOut: -1
        property int hyprBorder: -1
        property int hyprRounding: -1
        property int hyprBlur: -1
        property int hyprAnimations: -1
        property int hyprActiveOpacity: -1
        property int hyprInactiveOpacity: -1
        property int hyprMouseSpeed: -1
        property int hyprMouseAccel: -1
        property int hyprMouseScroll: -1
        property int hyprTouchpadScroll: -1
        property int hyprTouchpadSpeed: -1
        property int hyprNaturalScroll: -1
        property int hyprTapToClick: -1
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
