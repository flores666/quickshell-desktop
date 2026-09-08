# AGENTS.md

Instructions for coding agents working on this repository. Read this before
touching anything; most of it is knowledge that cost real debugging to acquire
and is not recoverable from the code alone.

## What this is

A desktop shell for Wayland / Hyprland written in QML against
[Quickshell](https://quickshell.outfoxxed.me) 0.3 and Qt 6.11. It is the whole
desktop UI: top bar, dock, launcher, quick settings, notifications, OSD, session
lock. There is no build step — Quickshell interprets the QML directly and
reloads on file change.

## Running and verifying

```sh
qs -c shell                       # run it (resolves ~/.config/quickshell/shell)
qs -c shell ipc call shell <action>   # drive it; see ShellIpc.actions
./tools/lint.sh                   # qmllint over the whole tree
python3 tools/genicons.py         # regenerate components/Icons.qml
./tools/build-overview-plugin.sh  # rebuild the hyprexpo plugin
```

**Always run `./tools/lint.sh` and check the runtime log before claiming done.**
Plain `qmllint` will not work: it does not understand Quickshell's `root:/`
imports and needs `qmldir` files that Quickshell synthesizes at runtime. The
wrapper copies the tree to a scratch dir, rewrites imports and generates the
qmldirs. Expect a residue of unavoidable warnings — types Quickshell registers
from C++ (`PanelWindow`, `GlobalShortcut`, enum types) and `QObject*`-typed
properties like `Loader.item`. Everything else must be clean.

To check the runtime log, start the shell with stdout captured and grep out the
`INFO` lines plus the two environmental warnings (`sni.watcher`, `bluez` — this
machine has no Bluetooth adapter). A healthy start prints nothing else.

### Verifying behaviour, not just compilation

The shell has almost no logic that can be unit-tested; correctness is "does the
compositor do the right thing". Use the real session:

- `grim` for screenshots, ImageMagick (`magick`) to crop and to compare region
  brightness when you need a yes/no signal.
- `hyprctl layers` to see which surfaces are mapped and how big they are. **This
  is the single most useful diagnostic in the project** — a surface that should
  be gone but is still listed at 1920x1080 is a shell that has eaten the mouse.
- `hyprctl clients -j` for window geometry (e.g. proving the dock reserves no
  space).
- `/dev/uinput` is writable by this user, so synthetic input works. See the
  testing gotcha about hover below.

## Hard rules

1. **Nothing outside `config/` hardcodes a colour, size, duration or font.** If
   you need a value that does not exist, add it to the right token file.
2. **No full-screen surfaces that take input.** Ever. See *Popups* below.
3. **Event-driven, never polled.** There is exactly one periodic timer in normal
   operation (`Time`, one tick per minute, shared by all monitors). Two bounded
   exceptions are documented in the code. If you add a `Timer` with `repeat`,
   justify it in a comment.
4. **Every widget's interaction states come from `Clickable`.** Do not
   re-implement hover/press/selected/disabled/focus.
5. **Degrade, never fake.** If hardware or a service is absent, the control is
   absent. No placeholder rows, no disabled buttons that would do nothing, no
   mock data.
6. Keep files small. The largest is under 300 lines; that is the ceiling.

## Architecture

```
shell.qml            entry point; instantiates per-monitor chrome (Variants over
                     Quickshell.screens) and the single-instance surfaces
config/              the design system — pure tokens, no logic
services/            one singleton per source of system state
components/          reusable widgets, all built on Clickable
modules/             the surfaces themselves
  bar/ dock/ panels/ launcher/ settings/ notifications/ osd/ lock/
  common/            shared surface chrome (ShellOverlay), IPC, overview theming
tools/               generators and the lint wrapper; not loaded at runtime
```

The dependency rule is one-way: `modules/` → `components/` → `config/`, and
anything may read `services/`. **Services never import modules or components.**

UI code never talks to D-Bus, PipeWire or Hyprland directly. If you find
yourself reaching for a system API inside `modules/`, the derivation belongs in
a service.

---

# Dictionary

## Concepts

**Surface** — a Wayland layer-shell window (`PanelWindow`). The shell has
persistent ones (bar, dock) and transient ones (popups, OSD, toasts). Every
surface has a `WlrLayershell.namespace` of `shell-<name>`, which is how you
identify it in `hyprctl layers`.

**Popup** — launcher, quick settings, settings, date menu, tray menu, dock menu.
All share `ShellOverlay`. Exactly one can be open at a time.

**Overlay (the service)** — the arbiter that enforces "one popup at a time".
Every open/close routes through it, which is why the invariant holds by
construction rather than by every surface remembering to close its siblings.

**Card** — the visible rounded panel inside a popup's window. The window is
sized to `cardWidth`/`cardHeight` plus `pad` (room for the shadow); input is
masked to the card alone.

**Token** — a named design value in `config/`. `Appearance.c.accent`,
`Appearance.s.lg`, `Appearance.t.fast` and so on.

**Override** — a token or timing the user has changed, in `settings.json`. Every
one is an integer whose negative value means "unset", the way `""` means it for
a colour seed, so an untouched shell renders exactly what was tuned. The layout
overrides and their legal ranges live in one table, `config/Tuning.qml`, which
is what both the clamp and the settings panel's sliders read — a knob cannot
drift from its own guard rail. Timings are not design tokens and stay with the
service that acts on them (`Notifs.defaultTimeout`, `Dock.hideDelay`).

**Seed** — a preference chosen from a list rather than measured: the accent and
background colours the rest of a palette family is derived from, the font
family, the wallpaper. Every one is a string whose empty value means "unset", so
an untouched shell looks exactly as it was tuned, and every one carries its own
way back inside its own control — which is why *Reset all* leaves them alone and
is only ever about the numbers.

**Placement** — where a popup attaches: `BelowBar`, `AboveDock`, `Centre`.

**State layer** — the translucent hover/press/selected wash `Clickable` paints
under a widget's content.

**Focus visible** — the `:focus-visible` rule: focus rings appear during
keyboard navigation only, tracked by the `InputMode` service.

**Overview** — the workspace overview. **Not a shell surface**: it is the
`hyprexpo` compositor plugin. Only the compositor can render live workspace
contents.

## Services (`services/`, all `pragma Singleton`)

| Service | Owns | Key surface |
|---|---|---|
| `Appearance` (in `config/`) | the whole palette and every metric | `c` (colours), `s` `r` `m` `t` `font`, `shadowFor(level)` |
| `Appearance.m` / `Appearance.r` (in `config/`) | sizes and radii, resolved through `Tuning.pick` | `barHeight`, `barItemHeight`, `barFootprint`, `dockIcon`, `dockCell`, `dockFootprint`, `border` |
| `Settings` | the only persisted state, JSON under the Quickshell state dir | `effectiveDark`, `doNotDisturb`, `pinnedApps`, `accentColor`, `background{Light,Dark}`, `fontFamily`, `wallpaper`, `pin/unpin`, `toggleTheme`, `setFontFamily`, `setWallpaper`, `overrideKeys`, `setOverride/isOverridden/resetOverrides` |
| `Overlay` | which popup is open, on which screen, and outside-click dismissal | `active`, `screen`, `anchorX`, `payload`, `isOpen/open/openWith/openUnanchored/close/toggle`, `setPointerOver`, `dismissOnOutsideClick` |
| `Compositor` | Hyprland's workspaces, monitors and windows | `workspaces`, `toplevels`, `focusedScreen`, `monitorFor`, `appIdOf`, `focusWindow`, `closeWindow`, `switchToWorkspace`, `cycleWorkspace`, `isFullscreenOn`, `toggleOverview` |
| `Dock` | the dock's model: pinned apps + one entry per open window | `items`, `hideDelay`, `activate`, `launchNew`, `close`, `togglePinned` |
| `Apps` | the desktop-entry index, search and launch-frequency | `all`, `byId`, `byAppId`, `search`, `launch`, `iconFor` |
| `Audio` | PipeWire sinks/sources, volume, mute, mic-in-use | `hasSink`, `volume`, `muted`, `micInUse`, `volumeIcon`, `sinks`, `setVolume`, `toggleMute`, `setSink` |
| `Network` | NetworkManager state and the Wi-Fi list | `available`, `icon`, `label`, `wifiNetworks`, `activeWifi`, `vpnActive`, `connect`, `setScanning`, `passwordRequested` |
| `Bt` | BlueZ adapter and devices | `available`, `enabled`, `listed`, `icon`, `label`, `setEnabled`, `toggleConnection` |
| `Power` | UPower battery and power-profiles-daemon | `hasBattery`, `percentage`, `icon`, `timeLabel`, `hasProfiles`, `profile`, `setProfile` |
| `Brightness` | the sysfs backlight | `available`, `value`, `set`, `step` |
| `Players` | MPRIS, with one sticky "current" player | `hasPlayer`, `playing`, `title`, `artist`, `summary`, `playPause`, `seekTo`, `formatTime` |
| `Notifs` | the notification server, toast queue and history | `history`, `count`, `popups`, `remove`, `clearAll`, `plainBody`, `relativeLabel`, `timeoutFor` |
| `Keyboard` | the active XKB layout | `available`, `code` (e.g. `EN`), `cycle` |
| `Osd` | the transient volume/mic/brightness indicator | `shown`, `kind`, `value`, `icon`, `text` |
| `Screenshot` | screen capture through grim/slurp | `capture`, `captureRegion` |
| `Wallpaper` | the pictures in ~/Pictures/Wallpapers, and driving hyprpaper | `folder`, `folderPath`, `items`, `available`, `current`, `set` |
| `Fonts` | the font families Qt found at startup | `families`, `available`, `search` |
| `Session` | lock, suspend, logout, reboot, shutdown | `lock` (raises `lockRequested`), `suspend`, `logout`, … |
| `Time` | one clock for the whole shell | `now`, `time`, `dateShort`, `dateLong` |
| `InputMode` | whether the user is currently navigating by keyboard | `keyboard`, `pointerUsed`, `keyboardUsed` |

Every service exposes an availability flag (`available`, `hasSink`,
`hasBattery`, …). The UI keys visibility off that flag; that is how rule 5 is
implemented.

## Components (`components/`)

| Component | Purpose |
|---|---|
| `Clickable` | **the interaction primitive.** Hover, press, selected, disabled, focus ring, keyboard activation. Everything clickable derives from it |
| `Surface` | an opaque rounded panel with a border and a `Shadow` |
| `Shadow` | one gaussian-blurred silhouette via `MultiEffect`; `level` 1–3 |
| `Icon` / `Icons` | a monochrome UI glyph drawn with QtQuick.Shapes from generated path data |
| `AppIcon` | an application icon from the XDG theme, with fallbacks |
| `Label` | text with the type scale applied; use instead of bare `Text` |
| `IconButton`, `TextButton`, `ToggleSwitch`, `Slider`, `MenuRow`, `SearchField`, `Spinner`, `Divider`, `ThinScrollBar`, `Tooltip` | the rest of the kit |

## Module chrome (`modules/common/`)

| File | Purpose |
|---|---|
| `ShellOverlay` | the base every popup derives from: sizing, placement, masking, fade, Escape, outside-click dismissal. Its `frame` samples the bar's and dock's footprints when the surface maps and holds them until it unmaps — those are user-settable, and the popup that changes them is the settings panel itself |
| `ShellIpc` | the external control surface. Every action exists once in `run(action)`; the IPC handler and the global shortcuts both dispatch to it |
| `OverviewTheme` | pushes the shell's colours into the hyprexpo plugin so the overview matches the theme |
| `MenuItemRow` | one row of a popup menu |

---

# Platform gotchas

These are all verified on this machine (Hyprland 0.56.2, Quickshell 0.3.1,
Qt 6.11.2). Several of them are the reason code looks the way it does; if you
"simplify" past one you will reintroduce a bug that was expensive to find.

### QML / Qt

- **`escape` is an illegal QML method name**, as are other JS globals. This has
  bitten twice (`Apps.escapeRegExp`, `ShellIpc.escapeKey`). Symptom:
  `Illegal method name` at load.
- **`Palette` collides with a QtQuick type.** The palette component is called
  `ColorScheme` for this reason. Watch for the same with `Icon`, `Label`,
  `Slider` if `QtQuick.Controls` is ever imported (it currently is not).
- **`import QtCore` shadows the `Settings` singleton** with QtCore's own
  `Settings` type, and every use of ours then fails to resolve. `Wallpaper`
  needs `StandardPaths` from it, so it imports it qualified (`as Core`).
- **A Flickable adopts anything declared inside it into its content item**, so a
  pointer handler written there is parented but never registered and silently
  never fires. `Filmstrip` catches the wheel with a `MouseArea` that accepts no
  buttons, laid over the list — a `WheelHandler` on the wrapper is not offered
  the event either. Note also that `WheelHandler.orientation` is a single
  `Qt.Orientation`, not a set: a handler asked for both axes matches neither.
- **A file name that matches a singleton shadows it.** `modules/dock/Dock.qml`
  would hide the `Dock` service, which is why the window is `DockPanel.qml` and
  the OSD window is `OsdWindow.qml`. Do not name a module file after a service.
- **`NumberAnimation.finished` never fires inside a `Behavior`.** Never unmap a
  window or free a resource from it. Use a `Timer` whose `running` is a plain
  binding — a binding cannot silently fail to fire.
- **A derived component's `on<Signal>` handler replaces the base's.** In a base
  component like `ShellOverlay`, react to your own signals with
  `Connections { target: root }`, not an `onFooChanged` handler, or a subclass
  will silently displace it.
- **Quickshell singletons are lazy.** They initialise on first access, which is
  why `shell.qml` touches them all in `Component.onCompleted` — otherwise the
  bar renders one frame of empty placeholders.
- **Do not read churny properties in a model.** `Dock.items` used to read window
  titles; every keystroke in a terminal rebuilt the whole dock. Titles are now
  read per-item off the toplevel. This was worth 0.3% of idle CPU.
- Use `required property` in every delegate; the codebase sets
  `pragma ComponentBehavior: Bound` everywhere.

### Hyprland / Wayland

- **`WlrKeyboardFocus.Exclusive` captures the pointer too**, not just the
  keyboard. An exclusive layer surface stops clicks reaching applications
  underneath. Popups use `OnDemand`, which still allows typing.
- **`HyprlandFocusGrab` is not usable for outside-click dismissal.** The grab
  covers the entire grabbed *surface* regardless of its input region, and
  Hyprland **consumes** the press that breaks the grab. Measured:
  `cleared=1, appClicks=0`. With exclusive keyboard focus it never clears at all.
- **`bindn` is non-consuming and is how dismissal works.** A `bindn` mouse or
  key bind reports the press to the shell *and* still delivers it to the
  application. See the `shell:dismiss` / `shell:escapeKey` binds in
  `hyprland.conf`.
- **`mask: Region { item: null }` is genuinely click-through** (verified with a
  hover probe: `item: catcher` → 1 hover, `item: null` → 0). This is what lets a
  surface be visible but inert.
- **An "ignore exclusive zones" surface starts at the screen edge**, not below
  the bar. Toasts set `margins.top` explicitly for this reason.
- **A layer surface's input region does not shrink its rendering.** Masking
  controls input only.

### Testing

- **`hyprctl dispatch movecursor` does not generate pointer enter events.**
  Hover state will not update. Synthetic tests must emit real relative motion
  through `/dev/uinput` first; see the helper scripts pattern in the scratchpad
  (`clicknudge.py`: create device → emit `REL_X` ±3 → press).
- **Check the probe window is on the active workspace and focused** before
  concluding that a click did not arrive. Several hours were lost to a test app
  that had drifted onto another workspace.
- `pkill -f <pattern>` will match the shell running your own command line and
  kill your script. Use `pkill -x qs` or kill by PID.

### Icons

`components/Icons.qml` is **generated** — do not hand-edit. `tools/genicons.py`
lifts path data out of the Adwaita symbolic theme. Two details matter:

- Subpaths sharing an opacity are merged into one path, and **a merged path's
  leading relative `m` must be upper-cased to `M`** or it becomes relative to
  the previous subpath's end point. Symptom: glyph fragments scattered across
  the screen.
- Icons render as at most two opacity layers; `Icon.qml` has exactly two
  `ShapePath` slots. If a new icon needs more, the generator warns.

### The overview plugin

`hyprexpo` was dropped from the official `hyprland-plugins` repo as unmaintained
and is absent from its `v0.56.0` release. The build script uses the maintained
[sandwichfarm fork](https://github.com/sandwichfarm/hyprexpo), picking the tag
matching the installed Hyprland. **Hyprland refuses to load a plugin built
against different headers**, so it must be rebuilt after every Hyprland update.
`master` chases hyprland-git and will not compile against a release.
