# Audit refactor

Resolve the confirmed findings in the November 4 audit while preserving the
desktop's defaults, event sources and sampling exceptions.

1. A scrollbar paints and drags through the same clamped progress and actual
   thumb travel, including a minimum thumb, overscroll and a ListView origin.
   `ScrollBarTest` exercises both axes and a pointer grab.
2. A chart keeps each series delegate across samples, reuses mapped points for
   its fill, and builds no presentation while hidden. Date-menu cards stop
   forwarding hidden samples; `Processes` and `Usage` keep their history.
   `ChartTest` checks delegate identity and reopening with the latest data.
3. Dock menus resolve the opening subject's stable key against the current
   model, and hold their presentation through the closing fade. Window actions
   use the current list. `DockMenuTest` opens/closes more windows while a menu
   is up and closes the whole current group.
4. Standalone notifications use the shared `r.panel` corner; history rows keep
   `r.md`. Notification suites cover their lifecycle.
5. Widget, calendar, dock, quick-settings and settings dimensions, spinner
   motion and compositor-shadow fit values belong to `config/`. Fixed values
   keep their existing defaults and add no user preferences.
6. Slider, picker and scrollbar gestures use `Clickable`'s pointer events and
   interaction state. Moving knobs can be its focus-ring target. Value mapping
   stays in each widget. `DragControlsTest` checks pointer/keyboard input,
   disabled focus and wheel pass-through. A hue arrow applies one picker step.
7. Bar audio/network indicators appear only for an actual sink/adapter.
   Disconnected hardware retains its indicator; FrontPage's disabled tiles
   retain their documented places.
8. Bluetooth discovery is a page's retained request, synchronized by adapter
   and enabled events. `BluetoothDiscoveryTest` covers absent/off/on adapters,
   re-enabling, page exit and adapter appearance with a stand-in backend.
9. Remove caller-free `Apps.iconFor`, `Fonts.available`, `Network.limited`,
   `Osd.hide`, `Players.appIcon`, `Players.raise`, and `Processes.sample`, plus
   their stale API mentions. Sampling entry points remain intact.
10. Application search constructs its escaped word-boundary matcher once per
    nonempty query; scoring, frequency and name tie-breaks stay unchanged.
11. Quick-settings and settings furniture use semantic metrics; wallpaper
    thumbnail decoding derives from its display width.
12. Each capture reserves its own timestamp-prefixed destination with mktemp.
    Cancellation/failure removes it and releases the freeze, including a
    reservation failure. Only completed captures are announced.
    `ScreenshotTest` covers same-second requests and cancellation.
13. A v2rayN mode response belongs to its endpoint and generation. Disabling
    TUN invalidates pending responses and clears queued reads; a switch also
    requires a current endpoint. `V2raynResponseTest` releases delayed curl
    replies after disabling, replacing and reusing an endpoint.
14. `Processes.sample` removal changes no counter cadence, watcher extras or
    first-sample behavior. Processes/GPU/Usage/Activity suites check these.
15. AuthPrompt/TaskManager integration assertions execute the actual Lua
    registration against a recording API, without running startup callbacks.
    `BackdropProbeTest` creates a private wallpaper instead of depending on
    the user's picture. It requires two nested outputs and fails promptly
    when its fixture requirements are missing.

The native window plugin takes title-bar geometry, typography and initial size
caps through the existing style pipeline. A style batch ends with `restyle`,
which updates reserved space and damages the bars in the same compositor step.
Font cache identity includes the font settings. `NativeStyleTest` reads back
the options and changes bar height on a maximized window. Placement determines
eligibility once per float/tile event and records through a private helper;
standalone remember paths still validate eligibility. Title-bar input actions
live with pointer handling, keeping both files below the size ceiling.

The overview's final patch takes focus duration, curve, zoom and current-tile
strength from config through its option pipeline. Frame-driven damage and
reduced-motion behavior remain in place. Both plugins are built and exercised
in nested Hyprland, never replaced in the running desktop.

`nvim-help` has one terminal dispatch helper, preserving all terminal argv
forms and its dependency prompts. Its jq/less/procps-ng requirements are listed
with its existing packages. There is no change to VFR, process sampling,
clocks, native commit throttles, watchers or event streams, and no claim of a
material CPU improvement.
