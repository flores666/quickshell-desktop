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

In the session the shell is the user unit `quickshell.service` (see
`hyprland.conf`: capped at 1.5 GB with no swap, restarted on failure). To check
the runtime log, `systemctl --user restart quickshell`, then read
`journalctl --user -u quickshell -o cat` and grep out the `INFO` lines plus the
two environmental warnings (`sni.watcher`, `bluez` — this machine has no
Bluetooth adapter). A healthy start prints nothing else.

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
   absent. No placeholder rows, no mock data. The one exception is quick
   settings' front page (`panels/qs/FrontPage`), whose tiles and sliders keep
   their places and go *disabled* — "Unavailable" — so that the layout is the
   same on every machine and does not shift as devices come and go. The
   footer's battery reading is not a control and is simply absent without a
   battery. Disabling is `Clickable`'s own state; nothing else gets a disabled
   stand-in, and the bar still shows only what is there.
6. **The wheel only ever scrolls.** No control changes a value or a selection
   from it, so a wheel anywhere inside a panel reaches the surface that
   scrolls. Do not add an `onWheel` to a widget; the two on the bar
   (`Workspaces`, `Tray`) are outside the panels and are the only exceptions.
   (`CardMenu`'s handler changes nothing: it closes the menu and hands the
   wheel on with `event.accepted = false`.)
7. Keep files small. The largest is under 300 lines; that is the ceiling.

## Architecture

```
shell.qml            entry point; instantiates per-monitor chrome (Variants over
                     Quickshell.screens) and the single-instance surfaces
config/              the design system — pure tokens, no logic
services/            one singleton per source of system state
components/          reusable widgets, all built on Clickable
modules/             the surfaces themselves
  bar/ dock/ panels/ launcher/ settings/ notifications/ osd/ lock/
  panels/qs/         quick settings' pages: FrontPage, the sub-pages it opens,
                     and their tiles and rows
  settings/          one *Section per tab, its rows (SettingRow /
                     SettingToggle) on SettingGroup cards; ThemeCard previews a
                     theme; SeedPicker is one colour seed: one row of choices
                     and a picker; ResetSection is the one place "Reset all"
                     lives
  common/            shared surface chrome (ShellOverlay, OverlayCard), IPC,
                     overview theming
tools/               generators and the lint wrapper; not loaded at runtime
hyprland.conf        sourced by the user's own config: the plugin, the shell's
                     global binds, the bindn dismissal binds
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

**Glass** — how every floating surface is drawn. `Surface` lays `c.chrome`
(the opaque `c.surface` at `c.glass` opacity) over a blur Hyprland draws
behind any shell surface wherever it is more than half opaque (the
`shell-glass` layer rule). Shadows stay below that threshold, so the frost
stops at a panel's edge. `raised`, `sunken`, `border` and `borderStrong` are
translucent washes, not colours: they take on the glass, the seeds and the
wallpaper beneath them, which is what lets one set serve any palette. Use
`c.surface` only where something must be opaque (a knob is `c.knob`); never
`Qt.alpha` a token by hand to make glass. The lock screen is the one opaque
surface.

**Override** — a token or timing the user has changed, in `settings.json`. Every
one is an integer whose negative value means "unset", the way `""` means it for
a colour seed, so an untouched shell renders exactly what was tuned. The layout
overrides and their legal ranges live in one table, `config/Tuning.qml`, which
is what both the clamp and the settings panel's sliders read — a knob cannot
drift from its own guard rail. Timings are not design tokens and stay with the
service that acts on them, range and all (`Notifs.timeoutRange`,
`Dock.hideDelayRange`). Every override is clamped by the one `Settings.pick`. Hyprland
options (`hyprGapsIn`, `hyprBlur`, …) are overrides too, with the same
arrangement in `CompositorOptions.spec`: Hyprland's name for each, its range,
and how the integer maps onto it (a 0–1 float is a percentage, a −1..1
sensitivity is 0–200 with 100 neutral). `hyprland.conf` stays the source of
every default and is never rewritten.

**Seed** — a preference chosen from a list rather than measured: the accent and
background colours the rest of a palette family is derived from, the font
family, the wallpaper. Every one is a string whose empty value means "unset", so
an untouched shell looks exactly as it was tuned, and every one carries its own
way back inside its own control — which is why *Reset all* leaves them alone and
is only ever about the numbers. The same goes for the two on/off preferences,
Do Not Disturb and *Match window corners* (`roundnessFollowsWindows`).

A colour seed can also come from the picker, which is held to
`Appearance.seedRange`: the derived family and the hand-tuned text colours only
stay legible over a background near the theme's own. Picked colours go into one
shared history (`recentColors`, newest first, capped; `pinnedColors`, kept).
Each seed's row shows only those inside its own range, which is what keeps
accents and backgrounds apart — so the ranges must not overlap. Choosing a
colour from it applies it. Each seed shows one line of swatches, never two:
the colour in force first, with a halo; the pinned ones, newest pin first; then the recent
ones and the built-in choices; as many as fit, and the add button last. A
right click opens a `CardMenu` to pin, unpin or remove one; removing a
built-in choice keeps it in `hiddenColors` (`forgetColor` does both), and ""
— the theme's own colour, the way back — cannot be removed. User-visible
text is American English ("color"); the code and its comments are not
rewritten for it.

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
| `Appearance` (in `config/`) | the whole palette and every metric | `c` (colours), `day`/`night` (each theme's scheme, from its own seed), `s` `r` `m` `t` `font`, `shadowFor(level)`, `seedRange(seed)`, `inSeedRange` |
| `Appearance.m` / `Appearance.r` (in `config/`) | sizes and radii, resolved through `Tuning.pick` | `barHeight`, `barItemHeight`, `barFootprint`, `dockIcon`, `dockCell`, `dockFootprint`, `border`, `navRowHeight`; `r.panel` is **the** radius of every popup card and toast — nothing picks its own — and `r.capsule(height)` is the bar's, the dock's and the OSD's, and their controls': fully round at the tuned roundness, squarer below it. With `r.followsWindows` every radius scales from Hyprland's window rounding instead of the roundness setting |
| `Settings` | the only persisted state, JSON under the Quickshell state dir | `effectiveDark`, `doNotDisturb`, `pinnedApps`, `dockOrder`, `accentColor`, `background{Light,Dark}`, `recentColors`, `pinnedColors`, `rememberColor`, `togglePinnedColor`, `fontFamily`, `systemFontBefore`, `wallpaper`, `roundnessFollowsWindows`, `pin/unpin`, `forgetColor`, `toggleTheme`, `setFontFamily`, `setWallpaper`, `overrideKeys`, `pick`, `setOverride/isOverridden/resetOverrides` |
| `CompositorOptions` | the Hyprland options the settings panel changes, and the one pipeline that pushes any option with `hyprctl keyword` | `spec`, `keys`, `configured`, `value`, `known`, `set`, `hasTouchpad`, `derived` (options that follow the design system — the overview's — set by `OverviewTheme`) |
| `Overlay` | which popup is open, on which screen, its context menu, and outside-click and Escape dismissal | `active`, `screen`, `anchorX`, `payload`, `isOpen/open/openWith/openUnanchored/close/toggle`, `menu`, `openMenu/closeMenu`, `setPointerOver`, `dismissOnOutsideClick`, `dismissOnEscape` (a menu first, then the popup) |
| `Compositor` | Hyprland's workspaces, monitors and windows | `workspaces`, `toplevels`, `focusedScreen`, `monitorFor`, `appIdOf`, `focusWindow`, `closeWindow`, `exec`, `switchToWorkspace`, `cycleWorkspace`, `isFullscreenOn`, `toggleOverview` |
| `Dock` | the dock's model: pinned apps + one entry per open window | `items`, `hideDelay`, `activate`, `launchNew`, `close`, `togglePinned` |
| `Apps` | the desktop-entry index, search and launch-frequency | `all`, `byId`, `byAppId`, `search`, `launch`, `iconFor` |
| `Audio` | PipeWire sinks/sources, volume, mute, mic-in-use | `hasSink` (bound, not just present), `volume`, `muted`, `micInUse`, `volumeIcon`, `volumeIconFor`, `sinks`, `setVolume` (unmutes), `stepVolume`, `toggleMute`, `setSink` |
| `Network` | NetworkManager state and the Wi-Fi list | `available`, `hasWifi`, `hasWired`, `wifiEnabled`, `icon`, `label`, `signalIcon`, `wifiNetworks`, `activeWifi`, `vpnActive`, `connect`, `connectWithPassword`, `changePassword`, `forget`, `setScanning`, `restartWifi`, `restarting`, `passwordRequested`, `failure` |
| `Bt` | BlueZ adapter and devices | `available`, `enabled`, `listed`, `icon`, `label`, `setEnabled`, `toggleConnection` |
| `Power` | UPower battery and power-profiles-daemon | `hasBattery`, `percentage`, `icon`, `timeLabel`, `hasProfiles`, `profile`, `setProfile` |
| `Brightness` | the backlight: read and watched in sysfs, written through logind | `available` (once read), `value`, `set`, `step` |
| `Players` | MPRIS, with one sticky "current" player | `hasPlayer`, `playing`, `title`, `artist`, `playPause`, `seekTo`, `formatTime` |
| `Notifs` | the notification server, toast queue and history | `history`, `count`, `popups`, `remove`, `clearAll`, `plainBody`, `relativeLabel`, `timeoutFor` |
| `Keyboard` | the active XKB layout | `available`, `code` (e.g. `EN`), `cycle` (every keyboard at once) |
| `Osd` | the transient volume/mic/brightness indicator, listening to each source only once it holds a true reading | `shown`, `kind`, `value`, `icon`, `text`, `holdTime` |
| `Screenshot` | screen capture through grim/slurp | `capture`, `captureRegion` |
| `Wallpaper` | the pictures in ~/Pictures/Wallpapers, and driving hyprpaper | `folder`, `folderPath`, `items`, `available`, `current`, `set` |
| `Fonts` | the font families Qt found, and applying the chosen one to applications — the GTK interface font and a fontconfig file the shell owns (`conf.d/50-quickshell-font.conf`); *Default* restores the GTK font it first replaced | `families`, `available`, `chosen`, `search` |
| `Session` | lock, suspend, logout, reboot, shutdown | `lock` (raises `lockRequested`), `suspend`, `logout`, … |
| `Time` | one clock for the whole shell | `now`, `time`, `dateShort`, `dateLong` |
| `InputMode` | whether the user is currently navigating by keyboard | `keyboard`, `pointerUsed`, `keyboardUsed` |

Every service exposes an availability flag (`available`, `hasSink`,
`hasBattery`, …). The UI keys visibility off that flag; that is how rule 5 is
implemented.

## Components (`components/`)

| Component | Purpose |
|---|---|
| `Clickable` | **the interaction primitive.** Hover, press, selected, disabled, focus ring, keyboard activation (Space/Enter click; Menu or Shift+F10 right-click). Everything clickable derives from it |
| `Surface` | a glass panel: `c.chrome` (the surface at `c.glass` opacity), a hairline and a `Shadow`; the compositor blurs what is behind it |
| `Shadow` | one gaussian-blurred silhouette via `MultiEffect`; `level` 1–3 |
| `Icon` / `Icons` | a monochrome UI glyph drawn with QtQuick.Shapes from generated path data |
| `AppIcon` | an application icon from the XDG theme, with fallbacks |
| `Label` | text with the type scale applied; use instead of bare `Text` |
| `ColorPicker` | an HSV plane and hue strip, optionally held to a saturation/value band; `moved`/`committed` like `Slider`, arrow keys, no wheel |
| `Filmstrip` | a sideways-scrolling row of choices wider than its room: wallpaper previews, font samples |
| `MenuRow` | a popover list row; `flush` drops the inset and wash so it sits among a settings pane's sliders |
| `FieldWell` | the well every text input sits in: no border, a wash on hover and a stronger one while the input has the keyboard; its hover is a `Clickable` laid over the input taking no buttons, and anything with its own hover goes in `trailing` above it |
| `IconButton`, `TextButton` (`compact` for in-row actions), `ToggleSwitch`, `Slider`, `SearchField`, `Spinner`, `Divider`, `ThinScrollBar`, `Tooltip` (`below` for one at the top of a popup) | the rest of the kit |

## Module chrome (`modules/common/`)

| File | Purpose |
|---|---|
| `ShellOverlay` | the base every popup derives from: the surface, placement, sizing, masking, the map/settle/unmap lifecycle and outside-click dismissal. Its `frame` samples the bar's and dock's footprints when the surface maps and holds them until it unmaps — those are user-settable, and the popup that changes them is the settings panel itself |
| `OverlayCard` | the card inside it: the entry slide, the fade (as one flattened layer), clipping, hover reporting to `Overlay`, and swallowing Escape (the global bind acts on it) |
| `CardMenu` | a context menu inside the open popup — whatever `Overlay.menu` asks for — drawn over the card's content so the content's clipping cannot cut it off; a press anywhere else on the card closes it |
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
  bitten three times (`Apps.escapeRegExp`, `ShellIpc.escapeKey`,
  `Overlay.dismissOnEscape`). Symptom: `Illegal method name` at load, and the
  whole shell fails to start — **qmllint does not catch it**; only the
  runtime log does.
- **`Palette` collides with a QtQuick type.** The palette component is called
  `ColorScheme` for this reason. Watch for the same with `Icon`, `Label`,
  `Slider` if `QtQuick.Controls` is ever imported (it currently is not).
- **A module import can shadow one of our singletons.** `import QtCore` brings
  its own `Settings` type, and `import Quickshell.Networking` its own `Network`;
  every use of ours in that file then goes to the imported type and fails —
  the Wi-Fi page once did nothing at all for this reason. Import them
  qualified (`QtCore as Core` in `Wallpaper`, `Quickshell.Networking as QsNet`
  in `WifiPage`). `Network.qml` itself may import it bare: it never names
  itself.
- **A Flickable adopts anything declared inside it into its content item**, so a
  pointer handler written there is parented but never registered and silently
  never fires; a `WheelHandler` on a wrapper item around the list is not offered
  the event either. Catching a wheel over a list therefore needs a `MouseArea`
  laid over it, taking no buttons so that what is underneath stays clickable.
  Note also that `WheelHandler.orientation` is a single `Qt.Orientation`, not a
  set: a handler asked for both axes matches neither.
- **A `MouseArea` accepts the wheel merely by having `onWheel` connected**, so a
  handler that declines to act on the event still swallows it and the scrolling
  surface underneath never sees it. `event.accepted = false` hands it back;
  declaring no `onWheel` at all is better where nothing wants it, which is how
  hard rule 6 is kept.
- **Qt's `PathSvg` misreads SVG's compacted arc syntax.** In `a1 1 0 00-1 1`
  the large-arc and sweep flags are single digits with no separator; Qt takes
  `00` for one number, shifts every later argument along, and the arc comes out
  a straight line. `tools/genicons.py` pulls every argument apart before
  emitting it. Adwaita's `legacy/` icons are the ones written that way.
- **A file name that matches a singleton shadows it.** `modules/dock/Dock.qml`
  would hide the `Dock` service, which is why the window is `DockPanel.qml` and
  the OSD window is `OsdWindow.qml`. Do not name a module file after a service.
- **`NumberAnimation.finished` never fires inside a `Behavior`.** Never unmap a
  window or free a resource from it. Use a `Timer` whose `running` is a plain
  binding — a binding cannot silently fail to fire.
- **A derived component's `on<Signal>` handler does not replace the base's**;
  both run, base first. Verified on Qt 6.11.2 plain and under Quickshell 0.3.1
  with a QML property on a `PanelWindow` root. (Earlier versions of this file
  said otherwise and `ShellOverlay` carried a `Connections { target: root }`
  workaround; there was never a measurement behind it.) Bindings, unlike
  handlers, *are* replaced: a subclass assigning a property the base binds
  wins.
- **Quickshell singletons are lazy.** They initialise on first access, which is
  why `shell.qml` touches them all in `Component.onCompleted` — otherwise the
  bar renders one frame of empty placeholders.
- **Do not read churny properties in a model.** `Dock.items` used to read window
  titles; every keystroke in a terminal rebuilt the whole dock. Titles are now
  read per-item off the toplevel. This was worth 0.3% of idle CPU.
- **A `Rectangle` with both a `gradient` and a `radius` ignores its parents'
  opacity** (measured: 51% alpha under a 30% parent; a plain fill, or a
  gradient with no radius, comes out at 30%). A popup's fade then leaves it at
  full strength, and two of them stacked leave a light fringe at the corners.
  Draw the gradient square and round it with a mask — `ColorPicker`'s
  `RoundedFill`.
- **A `Repeater` handed a new JS array rebuilds every delegate**, even the ones
  whose entries are unchanged: every toast faded in again and restarted its
  expiry on each new arrival. Services replace their arrays wholesale, so a
  view over one uses `ScriptModel { values: … }`, which diffs and keeps the
  delegates of what is still listed.
- **`ListView` cannot animate its first row leaving.** Removing row 0 moves
  the view's origin rather than the rows below, so the leaving delegate is
  culled on the first frame and nothing animates. Toasts are a `Column` with a
  `move` transition and keep their own list of what is still drawn.
- **Centring a child on a container that sizes itself from its children is a
  binding loop** (`MenuRow`'s trailing slot is already centred). This was the
  one "Binding loop detected" every start used to log.
- **Quickshell gives battery charge and Wi-Fi signal as 0–1 fractions**, not
  the 0–100 UPower and NetworkManager speak. `Power.percentage` converts once;
  `Network.signalIcon` holds the thresholds as fractions.
- **Quickshell 0.3.1's volume write does not reach a Bluetooth headset's
  microphone.** It reports the new level while the device keeps the old one
  (wrote 0.3, `wpctl` read 0.6); muting does reach it, and the true level read
  back then made the slider jump. `Audio.setMicVolume` goes through
  `wpctl set-volume`, coalesced to one process at a time. The speaker's
  writes do land and stay on the node.
- **A `PwNode`'s volume is not real until the node is `ready`** (bound). What
  it reports while binding is its state, not a change: `Audio.hasSink` waits
  for it, and that is what keeps the OSD from flashing at login.
- **Quickshell 0.3.1's `Networking` never recovers from NetworkManager
  restarting**: the devices go and are not registered again, so Wi-Fi reads
  "Unavailable" while it works. It is a process-wide C++ singleton, so no QML
  reload rebuilds it; 0.3.2 watches the service and fixes it. Until then
  `Network` watches NetworkManager's bus name (`gdbus monitor`) and restarts
  the shell's unit when it gets a new owner — only inside the unit
  (`INVOCATION_ID`), so a `qs` run by hand is never duplicated. Remove that
  watcher with the upgrade. (A probe that reads `Networking.devices` from a
  timer sees none: the backend connects on first use, then fills in.)
- **UPower reports a time to empty for a full battery on AC**, computed from
  its trickle (≈30 days). `Power.timeLabel` answers only while charging or
  discharging.
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
- **So Escape reaches a focused popup twice**: once through that bind, once as
  the key event. Only the bind acts (`Overlay.dismissOnEscape`); `OverlayCard`
  swallows the key. Acting on both took two steps per press — a card menu
  closed by one, and the popup behind it by the other.
- **`mask: Region { item: null }` is genuinely click-through** (verified with a
  hover probe: `item: catcher` → 1 hover, `item: null` → 0). This is what lets a
  surface be visible but inert.
- **An "ignore exclusive zones" surface starts at the screen edge**, not below
  the bar. Toasts set `margins.top` explicitly for this reason.
- **A layer surface's input region does not shrink its rendering.** Masking
  controls input only.
- **Hyprland forgets every `hyprctl keyword` when it reloads its config.**
  `CompositorOptions` re-pushes everything, the overview's options included,
  on `configreloaded`. A keyword does not itself raise that event, so this
  cannot loop. Loading a plugin raises it too, which is how options pushed
  before the plugin was up still land. There is no keyword for "back to what
  the file said": clearing an override asks Hyprland to reload, and the
  re-push restores the rest. Per-device options (touchpad speed) can be set
  but not read back, which is why that row says "As configured".
- **A `layerrule[name] { … }` block needs `match:namespace`.** The bracketed
  name only names the rule; a rule with no match applies to nothing, silently
  (`canMatch()` in the 0.56.2 source). The namespace is a regex that must match
  the *whole* namespace (`RE2::FullMatch`), so `shell-.*`, not `^shell-`.
  `hyprland.conf`'s first two rules once sat without one.
- **Layer blur follows the surface's alpha** (`ignore_alpha`). A popup's
  surface spans the screen but is mostly transparent, and only its card is
  blurred behind. Hyprland's blur strength is global (`decoration:blur`), and
  this machine's is light, which is why `c.glass` is high.
- **A colour with alpha stringifies as `#aarrggbb`.** Anything handing a
  token to Hyprland builds `rgba(rrggbbaa)` from the channels
  (`OverviewTheme.rgba`); slicing the string would give the overview white
  borders.
- **`hyprctl keyword` answers `ok` for a plugin option that does not exist.**
  The overview's border weight went to `border_size` (this fork's is
  `border_width`) and never took effect. Read a new one back with
  `hyprctl getoption`.
- **Applications are launched with Hyprland's `exec` dispatcher**
  (`Compositor.exec`), never `DesktopEntry.execute()`. Hyprland's
  `misc:initial_workspace_tracking` only follows processes it spawned itself:
  one the shell spawns opens on whatever workspace is focused when its window
  maps, so launching on 3 and switching to 5 put it on 5.
- **`switchxkblayout` is not a dispatcher in 0.56**; it is a `hyprctl`
  command. `Keyboard.cycle` runs `hyprctl switchxkblayout all next`.
- **A `plugin =` path gets no tilde expansion** — it goes straight to dlopen.
  `hyprctl plugin load` does expand `~`, which hides the fault when testing by
  hand. Use `$HOME`, which the config parser expands.
- **Only one bind may claim a global shortcut.** Two would open and close the
  same popup on one press. Super+Space is the XKB layout toggle on this
  machine (`grp:win_space_toggle`), which is why the launcher is Super+R.

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
- **The shell under test is the user's live desktop.** Synthetic clicks and
  keys land wherever the pointer and focus are; check with a screenshot that
  the target is a shell surface before sending input to it. Restart it with
  `systemctl --user restart quickshell`, not by relaunching `qs` by hand: a
  shell started outside the unit has no memory cap.
- **Test a plugin build in a nested Hyprland, not the session.** A plugin
  that crashes takes the compositor and every open window with it. Run
  `hyprctl dispatch exec "[workspace special:x silent] Hyprland -c <conf>"`
  with a minimal config whose `plugin =` names the new `.so`. A nested
  compositor on a hidden workspace gets no frame callbacks and never renders,
  so give it its own screen: `hyprctl -i <instance> output create headless
  <name>`, move its workspaces there, and capture with
  `WAYLAND_DISPLAY=<its socket> grim -o <name>`. `hyprexpo:kb_selecti N`
  chooses a tile and closes the overview onto it without any input; inside
  the nested instance `hyprctl -i <instance> dispatch movecursor` does move
  the overview's hover. Kill it by PID.
- **A plugin cannot be loaded into a Hyprland whose binary was replaced on
  disk** — a `pacman -Syu` mid-session. `findFunctionsByName` canonicalises
  `/proc/self/exe`, which then reads `/usr/bin/Hyprland (deleted)`, and the
  plugin throws in its init; the old build fails exactly the same way, so
  unloading the working one loses the overview until the next login. Check
  `ls -l /proc/$(pidof Hyprland)/exe` before `hyprctl plugin unload`.
- **A hung shell cannot be attached to.** `ptrace_scope` is 1, so `gdb -p` and
  `eu-stack` get nothing. `systemctl --user kill -s ABRT quickshell` instead:
  Quickshell's crash handler writes a report with the main thread's stack and
  the log tail to `~/.cache/quickshell/crashes/`, and re-execs the shell in
  place, still inside the unit.
  Do that *before* the cap kills it — an OOM kill leaves no stack.

### Icons

`components/Icons.qml` is **generated** — do not hand-edit. `tools/genicons.py`
lifts path data out of the Adwaita symbolic theme, and out of `tools/icons/`
for the glyphs Adwaita lacks (the Wi-Fi restart's magic wand), drawn the same
way: 16×16, filled paths. Two details matter:

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

Two patches are applied, in order, both relative to the source directory:
`hyprexpo-real-wallpaper-bg.patch` (the real wallpaper, blurred, behind the
tiles) and `hyprexpo-tile-zoom-and-add-tile.patch`. The second highlights a
tile with a focus zoom instead of a border, so the shell pushes
`border_width` 0: the tile under the pointer or the keyboard keeps its size
and the workspace in it grows 2% inside the tile's rounded edge (a crop of
the capture through the renderer's custom UVs), the current workspace rests
40% of the way there. No tile is in focus as the overview opens: the
pointer takes focus only once it has moved since — a change of position, not
a move event, since opening simulates one — and the keyboard has none until
a key is pressed (upstream's `ensureKbFocusInitialized` then puts it on the
current workspace). Each tile eases on its own clock — hyprutils'
`CBezierCurve`, `cubic-bezier(0.22, 1, 0.36, 1)`, 400 ms — from wherever it
stands when its target changes, jumps with `animations:enabled` off (the
shell's *Animations* setting, the session's reduced motion), and unwinds
with the close the way the gaps do, so the chosen workspace lands exactly on
the screen. It also gives the dynamic grid a last tile, the
lowest-numbered workspace this monitor can take — one no workspace has yet,
or one it holds empty and does not show; never another monitor's — drawn as
the empty workspace it is (a missing workspace captures as the bare monitor)
and chosen through the same `ensureWorkspaceForTile` path as any tile.
`gaps_out` in `hyprland.conf` keeps the grid off the screen's edges on every
side; tiles keep the screen's shape, so only the axis the grid fills first
gets exactly that.
