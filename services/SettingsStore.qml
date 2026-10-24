pragma ComponentBehavior: Bound

import Quickshell.Io

/*!
    What settings.json holds: every key it may have and its default. Settings
    is the only thing that reads or writes it; nothing else declares a key.
*/
JsonAdapter {
    property string theme: "dark"
    property bool doNotDisturb: false
    property bool roundnessFollowsWindows: false
    /*! Off keeps the dock on screen, reserving its footprint like the bar. */
    property bool dockAutoHide: true
    /*! On, the dock takes the top panel's opacity instead of its own. */
    property bool dockOpacityFollowsBar: false
    property list<string> pinnedApps: []
    /*! Application keys in the order the dock shows them. Keys that are
        neither pinned nor running are ignored, so it never needs pruning. */
    property list<string> dockOrder: []
    /*! App ids whose windows the window plugin (hypr/windows) draws no title
        bar on; toggled from the dock's menu. */
    property list<string> hiddenTitleBars: []
    /*! Empty means "use the built-in colour for the current theme". */
    property string accentColor: ""
    property string backgroundLight: ""
    property string backgroundDark: ""
    property list<string> recentColors: []
    property list<string> pinnedColors: []
    property list<string> hiddenColors: []
    /*! On, the accent is the wallpaper's main colour (Appearance.accentFor). */
    property bool accentFollowsWallpaper: false
    /*! The wallpaper's main colour as last measured (Backdrop.mainColor):
        this machine's, kept so that the accent has it at login. */
    property string wallpaperAccent: ""
    /*! GTK's accent as it was before the shell first set it (DesktopAccent);
        empty while the shell has not. */
    property string gtkAccentBefore: ""
    /*! Empty means the built-in font family. */
    property string fontFamily: ""
    property string systemFontBefore: ""
    /*! NetworkManager connections the bar's VPN menu offers, by name. */
    property list<string> vpnConnections: []
    /*! A path, or a bare name for a picture in the wallpaper folder (see
        Wallpaper.current); empty means the shell has never set the wallpaper
        and leaves whatever the wallpaper daemon was configured with alone. */
    property string wallpaper: ""
    /*! Layout and timing overrides. -1 means "use the tuned value". */
    property int barHeight: -1
    property int barGap: -1
    property int barSideGap: -1
    property int dockIcon: -1
    property int border: -1
    property int roundness: -1
    property int fontScale: -1
    property int barOpacity: -1
    property int dockOpacity: -1
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
