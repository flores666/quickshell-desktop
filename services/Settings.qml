pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

/*!
    Persisted user preferences.

    Backed by a single JSON file under the Quickshell state directory
    (SettingsFile), watched so that an external edit is picked up live.
*/
Singleton {
    id: root

    readonly property bool effectiveDark: store.theme !== "light"
    readonly property bool doNotDisturb: store.doNotDisturb
    readonly property var pinnedApps: store.pinnedApps
    readonly property var dockOrder: store.dockOrder
    readonly property var hiddenTitleBars: store.hiddenTitleBars
    readonly property string accentColor: store.accentColor
    readonly property string backgroundLight: store.backgroundLight
    readonly property string backgroundDark: store.backgroundDark
    /*! Colours made in the picker, newest first, and the ones pinned to stay.
        One pair for every seed: each row offers only those that fall inside
        its own range (Appearance.seedRange), which keeps them apart. */
    readonly property var recentColors: store.recentColors
    readonly property var pinnedColors: store.pinnedColors
    /*! Built-in colour choices the user has removed from their rows. */
    readonly property var hiddenColors: store.hiddenColors
    // The wallpaper's colour as the accent; see SettingsStore.
    readonly property bool accentFollowsWallpaper: store.accentFollowsWallpaper
    readonly property string wallpaperAccent: store.wallpaperAccent
    readonly property string gtkAccentBefore: store.gtkAccentBefore
    /*! How many unpinned colours are remembered, across all the seeds. */
    readonly property int recentColorLimit: 24
    readonly property string fontFamily: store.fontFamily
    /*! The GTK interface font as it was before the shell first set it, so that
        going back to Default can give it back; empty while the shell has not. */
    readonly property string systemFontBefore: store.systemFontBefore
    /*! NetworkManager connections the VPN menu offers; set by hand in
        settings.json, since which of the profiles belong there is the user's. */
    readonly property var vpnConnections: store.vpnConnections
    readonly property string wallpaper: store.wallpaper
    /*! The shell's corners follow Hyprland's window rounding; see Radii. */
    readonly property bool roundnessFollowsWindows: store.roundnessFollowsWindows
    /*! The dock slides away when unused; off, it stays and reserves its room. */
    readonly property bool dockAutoHide: store.dockAutoHide
    /*! The dock lays down the top panel's opacity rather than its own. */
    readonly property bool dockOpacityFollowsBar: store.dockOpacityFollowsBar

    // ------------------------------------------------------------- overrides
    //
    // Every one of these replaces a value the design system or a service tuned
    // by hand.  A negative value means "unset", exactly as an empty string does
    // for the colour seeds above, so a fresh settings.json reproduces the
    // built-in look precisely.  The legal range for each lives with whoever owns
    // the value — the layout keys in Appearance.m.adjustable, the timings in the
    // service that acts on them — so nothing here has an opinion about them.

    readonly property int barHeight: store.barHeight
    readonly property int barGap: store.barGap
    readonly property int barSideGap: store.barSideGap
    readonly property int dockIcon: store.dockIcon
    readonly property int border: store.border
    readonly property int roundness: store.roundness
    readonly property int fontScale: store.fontScale
    readonly property int barOpacity: store.barOpacity
    readonly property int dockOpacity: store.dockOpacity
    readonly property int popupOpacity: store.popupOpacity
    readonly property int notificationTimeout: store.notificationTimeout
    readonly property int dockHideDelay: store.dockHideDelay
    // Hyprland options; ranges and encoding in CompositorOptions.spec.
    readonly property int hyprGapsIn: store.hyprGapsIn
    readonly property int hyprGapsOut: store.hyprGapsOut
    readonly property int hyprBorder: store.hyprBorder
    readonly property int hyprRounding: store.hyprRounding
    readonly property int hyprBlur: store.hyprBlur
    readonly property int hyprBlurSize: store.hyprBlurSize
    readonly property int hyprAnimations: store.hyprAnimations
    readonly property int hyprActiveOpacity: store.hyprActiveOpacity
    readonly property int hyprInactiveOpacity: store.hyprInactiveOpacity
    readonly property int hyprMouseSpeed: store.hyprMouseSpeed
    readonly property int hyprMouseAccel: store.hyprMouseAccel
    readonly property int hyprMouseScroll: store.hyprMouseScroll
    readonly property int hyprTouchpadScroll: store.hyprTouchpadScroll
    readonly property int hyprTouchpadSpeed: store.hyprTouchpadSpeed
    readonly property int hyprNaturalScroll: store.hyprNaturalScroll
    readonly property int hyprTapToClick: store.hyprTapToClick

    /*! Every key `setOverride` accepts, and everything `resetOverrides` clears. */
    readonly property var overrideKeys: [
        "barHeight", "barGap", "barSideGap", "dockIcon", "border",
        "roundness", "fontScale", "barOpacity", "dockOpacity", "popupOpacity",
        "notificationTimeout", "dockHideDelay",
        "hyprGapsIn", "hyprGapsOut", "hyprBorder", "hyprRounding", "hyprBlur", "hyprBlurSize",
        "hyprAnimations", "hyprActiveOpacity", "hyprInactiveOpacity", "hyprMouseSpeed",
        "hyprMouseAccel", "hyprTouchpadSpeed", "hyprNaturalScroll", "hyprTapToClick",
        "hyprMouseScroll", "hyprTouchpadScroll"
    ]

    function setTheme(name: string): void {
        store.theme = name === "light" ? "light" : "dark";
    }

    function toggleTheme(): void {
        root.setTheme(root.effectiveDark ? "light" : "dark");
    }

    function setDoNotDisturb(on: bool): void {
        store.doNotDisturb = on;
    }

    function setRoundnessFollowsWindows(on: bool): void {
        store.roundnessFollowsWindows = on;
    }

    function setDockAutoHide(on: bool): void {
        store.dockAutoHide = on;
    }

    function setDockOpacityFollowsBar(on: bool): void {
        store.dockOpacityFollowsBar = on;
    }

    function setAccentColor(value: string): void {
        store.accentColor = value;
    }

    function setAccentFollowsWallpaper(on: bool): void {
        store.accentFollowsWallpaper = on;
    }

    function setWallpaperAccent(value: string): void {
        store.wallpaperAccent = value;
    }

    function setGtkAccentBefore(value: string): void {
        store.gtkAccentBefore = value;
    }

    /*! Applies to whichever theme is active; the other keeps its own colour. */
    function setBackgroundColor(value: string): void {
        if (store.theme === "light")
            store.backgroundLight = value;
        else
            store.backgroundDark = value;
    }

    /*! Puts a picked colour at the front of the recent ones, in place of
        `replacing` if that is given: one visit to the picker is one colour, not
        every stop along the way. A pinned colour keeps its place. */
    function rememberColor(value: string, replacing: string): void {
        if (value === "" || root.isColorPinned(value))
            return;
        const gone = [value, replacing ?? ""];
        store.recentColors = [value].concat(store.recentColors.filter(x => !gone.includes(x)))
            .slice(0, root.recentColorLimit);
    }

    function isColorPinned(value: string): bool {
        return store.pinnedColors.indexOf(value) !== -1;
    }

    /*! Pinning takes a colour out of the recent ones so it never ages out,
        and puts it at the front of the pinned ones; unpinning returns it to
        the front of the recent ones. */
    function togglePinnedColor(value: string): void {
        if (value === "")
            return;
        if (root.isColorPinned(value)) {
            store.pinnedColors = store.pinnedColors.filter(x => x !== value);
            root.rememberColor(value, "");
        } else {
            store.recentColors = store.recentColors.filter(x => x !== value);
            store.pinnedColors = [value].concat(store.pinnedColors);
        }
    }

    /*! Takes a colour out of every row: out of the history, pinned or not,
        and out of the built-in choices if it is one. A seed set to it keeps
        it; "" — the theme's own colour, the way back — cannot be removed. */
    function forgetColor(value: string): void {
        if (value === "")
            return;
        store.recentColors = store.recentColors.filter(x => x !== value);
        store.pinnedColors = store.pinnedColors.filter(x => x !== value);
        if (store.hiddenColors.indexOf(value) === -1)
            store.hiddenColors = store.hiddenColors.concat([value]);
    }

    /*! Empty means the shell's own face. Any installed family is accepted. */
    function setFontFamily(value: string): void {
        store.fontFamily = value;
    }

    function setSystemFontBefore(value: string): void {
        store.systemFontBefore = value;
    }

    /*! The wallpaper's picture: a path, or a name in the folder (Wallpaper.current). */
    function setWallpaper(path: string): void {
        store.wallpaper = path;
    }

    /*! Set one override. A negative value restores the built-in value. */
    function setOverride(key: string, value: int): void {
        // An undeclared key would have JsonAdapter grow a property nothing reads
        // and then write it out to the file forever.
        if (store[key] === undefined)
            return;
        store[key] = value;
    }

    /*!
        An override held to `range` ({ min, max, def }), or `def` while unset.
        The one guard rail for every override, so a hand-edited settings.json
        cannot push a value outside what its own control offers.
    */
    function pick(key: string, range: var): int {
        const v = root[key];
        if (v === undefined || v < 0)
            return range.def;
        return Math.max(range.min, Math.min(range.max, v));
    }

    function isOverridden(key: string): bool {
        return store[key] !== undefined && store[key] >= 0;
    }

    function resetOverrides(): void {
        for (const key of root.overrideKeys)
            store[key] = -1;
    }

    function isPinned(id: string): bool {
        return id !== "" && store.pinnedApps.indexOf(id) !== -1;
    }

    function pin(id: string): void {
        if (id === "" || root.isPinned(id))
            return;
        store.pinnedApps = store.pinnedApps.concat([id]);
    }

    function unpin(id: string): void {
        if (!root.isPinned(id))
            return;
        store.pinnedApps = store.pinnedApps.filter(x => x !== id);
    }

    function isTitleBarHidden(appId: string): bool {
        return appId !== "" && store.hiddenTitleBars.indexOf(appId) !== -1;
    }

    function toggleTitleBar(appId: string): void {
        if (appId === "")
            return;
        store.hiddenTitleBars = root.isTitleBarHidden(appId)
            ? store.hiddenTitleBars.filter(x => x !== appId)
            : store.hiddenTitleBars.concat([appId]);
    }

    /*! The order the user dragged the dock into, as application keys. */
    function setDockOrder(keys: var): void {
        store.dockOrder = keys;
    }

    readonly property bool ready: file.loaded

    SettingsStore {
        id: store
    }

    SettingsFile {
        id: file
        adapter: store
    }
}
