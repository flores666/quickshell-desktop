# AGENTS.md

Instructions for coding agents working on this repository. Read this before
touching anything; most of it is knowledge that cost real debugging to acquire
and is not recoverable from the code alone.

## What this is

A desktop shell for Wayland / Hyprland written in QML against
[Quickshell](https://quickshell.outfoxxed.me) 0.3 and Qt 6.12. It is the whole
desktop UI: top bar, dock, launcher, quick settings, notifications, OSD, session
lock. There is no build step — Quickshell interprets the QML directly and
reloads on file change.

The project is also the rest of the desktop: the packages it needs, the
configs of Hyprland, hyprpaper, kitty, fish and neovim, the scripts it binds,
and the saved preferences. `./install.sh` sets a new computer
up as this desktop from the checkout alone; see *The rest of the desktop*.

## Running and verifying

```sh
qs -c shell                       # run it (resolves ~/.config/quickshell/shell)
qs -c shell ipc call shell <action>   # drive it; see ShellIpc.actions
./tools/lint.sh                   # qmllint over the whole tree
python3 tools/genicons.py         # regenerate components/Icons.qml
./tools/build-overview-plugin.sh  # rebuild the hyprexpo plugin (--if-stale: only if out of date)
```

**Always run `./tools/lint.sh` and check the runtime log before claiming done.**
Plain `qmllint` will not work: it does not understand Quickshell's `root:/`
imports and needs `qmldir` files that Quickshell synthesizes at runtime. The
wrapper copies the tree to a scratch dir, rewrites imports and generates the
qmldirs. Expect a residue of unavoidable warnings — types Quickshell registers
from C++ (`PanelWindow`, `GlobalShortcut` and its base `PostReloadHook`, enum
types) and `QObject*`-typed properties like `Loader.item` and
`ObjectModel.values`. Everything else must be clean. The
wrapper filters one false warning itself: qmllint calls a singleton "not
declared as singleton in qmldir" unless its file uses something else from its
own directory, though the generated qmldirs declare every one.

In the session the shell is the user unit `quickshell.service` (see
`hyprland.conf`: capped at 1.5 GB with no swap, restarted on failure). To check
the runtime log, `systemctl --user restart quickshell`, then read
`journalctl --user -u quickshell -o cat` and grep out the `INFO` lines plus the
environmental warnings (`sni.watcher`, from tray applications; `bluez` on a
machine with no Bluetooth adapter). A healthy start prints nothing else.

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
   operation (`Time`, one tick per minute, shared by all monitors). Three bounded
   exceptions are documented in the code; one is the VPN menu's latency
   (`Vpn`'s tick, which measures every row), every five minutes while there is
   a VPN to measure, since nothing signals a change in round-trip time. If you
   add a `Timer` with `repeat`, justify it in a comment.
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
8. **Everything the desktop needs is in the project.** A package, a font, or
   a config or script of any other application that the desktop comes to
   depend on goes into the project in the same change that brings it in,
   with what `install.sh` needs to put it in place. Nothing is set up on this
   machine by hand alone. See *The rest of the desktop*.

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
tools/               generators, the lint wrapper and save-profile.sh; not
                     loaded at runtime
hyprland.conf        the shell's Hyprland integration, sourced from
                     hypr/conf.d/90-quickshell.conf: the plugin, the shell's
                     global binds, the bindn dismissal binds

install.sh           sets a computer up as this desktop. Safe to re-run
packages.txt         every package from the official repositories
packages-aur.txt     every package from the AUR
hypr/                the Hyprland config (hyprland.conf sources conf.d/*.conf
                     in name order) and hyprpaper.conf
terminal/            kitty.conf (the whole kitty config, in the Soft Surface
                     look), prompt.fish, and palette.conf: the terminal's
                     colours, written there only — kitty takes them through
                     kitty-colors.py (a geninclude), the prompt and neovim
                     read the file. Not QML and not a surface, so they are not
                     tokens
nvim/                the neovim config; its theme is lackluster recoloured
                     with palette.conf, and plain lackluster without it
bin/                 scripts the configs run, linked into ~/.local/bin
profile/             state saved from a machine set up already, for the next:
                     settings.json (the shell's) and gtk.dconf
```

The dependency rule is one-way: `modules/` → `components/` → `config/`, and
anything may read `services/`. **Services never import modules or components.**

UI code never talks to D-Bus, PipeWire or Hyprland directly. If you find
yourself reaching for a system API inside `modules/`, the derivation belongs in
a service.

## The rest of the desktop

Everything outside the QML that makes this desktop is in the project too, so
that `./install.sh` on a fresh Arch install gives the same desktop. Hard rule 8
is what keeps that true: **whenever a change makes the desktop depend on
something new, the change also records it here.** Concretely:

| The desktop comes to need | Record it in | `install.sh` then |
|---|---|---|
| a package, from the official repos | `packages.txt`, under the heading it belongs to, with a comment saying what needs it | installs it with `pacman` when missing |
| a package from the AUR | `packages-aur.txt` | installs it with `yay`/`paru`, or lists it |
| a font, icon or cursor theme | its package, in one of the lists — never a file copied into `~/.local/share/fonts` | as above |
| a config of another application | its own directory or file in the project (`hypr/`, `terminal/`, `nvim/`, …) | links it into place: one `link` line |
| a script a config or bind runs | `bin/`; refer to it by bare name (kitty finds `~/.local/bin` itself; Hyprland binds use `~/.local/bin/<name>`) | links every file in `bin/` into `~/.local/bin` |
| a system or user service | the package; enabling it is a line in `install.sh` — or, for one that needs the graphical session, an `exec-once` in `hypr/conf.d/20-autostart.conf` (the polkit agent) | enables it if it is off |
| a setting that lives in dconf | its directory in `tools/save-profile.sh`'s `gtk` list, then run that | writes each key the machine still has at its default |
| a colour in the terminal, the prompt or neovim | `terminal/palette.conf`, by name | nothing: all three read it |
| a setting for one particular monitor or input device | nothing in the project: screens are detected (`highres, auto, auto`) and a touchpad by the shell. One machine's arrangement or tuning goes in its own `~/.config/hypr/hyprland.conf`, after the `source` line, keyed by the device (`desc:`, a `device` block's `name`) | nothing |
| the shell's preferences | nothing new: run `tools/save-profile.sh` and commit `profile/`; it keeps only pins and dock places of applications the package lists install | `Settings` starts from `profile/settings.json` on a machine with none |

How it fits together:

- **Configs are links, not copies.** Each one points into the project through
  `~/.config/quickshell/shell`, the one link to the checkout, so editing a
  config on any machine edits the project, and moving the checkout takes only
  a re-run. Hyprland's and kitty's own files are the exception: they stay the
  machine's, hold a single `source`/`include` of the project, and take what
  only that machine needs after it (kitty's font size, which
  `bin/kitty-font-size` writes there, is one).
- **State is saved, not linked.** dconf and the shell's `settings.json`
  change as the desktop is used, and a link would put every slider move into
  git and fight the next machine's own changes. `save-profile.sh` snapshots
  them; `install.sh` gives them only to a machine that has none, so a re-run
  never takes back a change made since. `systemFontBefore` and
  `vpnConnections` (names of this machine's NetworkManager profiles) are
  machine state and are saved empty.
- **The pictures are not in the repository.** It is public, and every save
  would have grown its history by megabytes. The wallpaper choice is saved by
  its bare name when the picture is in the folder, and `Wallpaper.current`
  resolves it in the next machine's folder (whatever its Pictures folder is
  called), empty until a picture of that name is put there.
- **`install.sh` never loses a file.** Whatever has to make way is kept beside
  itself as `<name>.bak-<date>`. Every step checks first, so running it twice
  changes nothing the second time.
- **Nothing that is one user's or one machine's.** The project is the
  desktop, not this computer: no monitor layout, no particular mouse, no
  applications of the user's own, no optional extras such as a login
  manager. Hardware is found where it is used — screens by Hyprland, a
  touchpad by `CompositorOptions`, the rest by the services' availability
  flags — and what one machine wants on top lives in its own Hyprland file.
- **Never secrets.** fish's universal variables (`fish_variables`) hold
  database credentials and stay out; so do NetworkManager's connections and
  the rest of dconf (Wi-Fi credentials, proxies, window sizes), which is why
  `save-profile.sh` lists the dconf directories it takes instead of dumping
  everything. Read a new config for credentials before adding it.

Verify an `install.sh` change as a fresh machine: run it twice with
`HOME=<scratch dir>`, a fake `~/.local/share/hyprexpo/hyprexpo.so` there (or it
builds the plugin) and `XDG_CONFIG_HOME` unset; the second run must print
nothing but the closing line. The dconf step cannot be sandboxed that way —
reads come from the scratch home and writes go to the real dconf service — so
it reports setting every key both times. For a Hyprland config change, compare
`hyprctl binds -j`, the options it sets (`hyprctl getoption`) and
`hyprctl configerrors` before and after a `hyprctl reload`;
`Hyprland --verify-config` cannot judge the plugin's options, which only
exist once it is loaded.

---

# Dictionary

## Concepts

**Surface** — a Wayland layer-shell window (`PanelWindow`). The shell has
persistent ones (bar, dock) and transient ones (popups, OSD, toasts). Every
surface has a `WlrLayershell.namespace` of `shell-<name>`, which is how you
identify it in `hyprctl layers`.

**Popup** — launcher, quick settings, settings, date menu, tray menu, dock menu,
VPN menu.
All share `ShellOverlay`. Exactly one can be open at a time.

**Overlay (the service)** — the arbiter that enforces "one popup at a time".
Every open/close routes through it, which is why the invariant holds by
construction rather than by every surface remembering to close its siblings.

**Card** — the visible rounded panel inside a popup's window. The window is
sized to `cardWidth`/`cardHeight` plus `pad` (room for the shadow) — as much
of it as the screen leaves above and below, so the card keeps its place under
the bar and a deep shadow is cut off by the screen's edge; input is masked to
the card alone.

**Window shadow** — `Appearance.windowShadow`, the one shadow of everything
that floats, in CSS `drop-shadow` terms (macOS's: dropped 25 px with a 45 px
blur at 40%, and a 2 px edge at 50%). The shell's floating surfaces cast it as
`Shadow` level 3; `CompositorTheme` gives windows the nearest soft shadow
Hyprland draws — one layer, dropped 6 px, since a deeper drop shows as a slab
(see the Hyprland gotchas) — so a window's shadow is shorter below than a
popup's and shows a little above.

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
is only ever about the numbers. The same goes for the on/off preferences: Do
Not Disturb, *Match window corners* (`roundnessFollowsWindows`) and the dock's
*Auto-hide* (`dockAutoHide`) and *Background* (`dockBackground`).

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
contents. The shell's own surfaces stay where they stand above it, live and
usable, and are left out of the workspaces' pictures.

## Services (`services/`, all `pragma Singleton`)

| Service | Owns | Key surface |
|---|---|---|
| `Appearance` (in `config/`) | the whole palette and every metric | `c` (colours), `day`/`night` (each theme's scheme, from its own seed), `s` `r` `m` `t` `font`, `windowShadow`, `shadowFor(level)` (layers in CSS `drop-shadow` terms, and `pad`), `seedRange(seed)`, `inSeedRange` |
| `Appearance.m` / `Appearance.r` (in `config/`) | sizes and radii, resolved through `Tuning.pick` | `barHeight`, `barItemHeight`, `barFootprint`, `dockIcon`, `dockSlot` (one round slot for every dock item, its highlight included), `dockHeight`, `dockFootprint`, `border`, `navRowHeight`; `r.panel` is **the** radius of every popup card and toast — nothing picks its own — and `r.capsule(height)` is the bar's, the dock's and the OSD's, and their controls': fully round at the tuned roundness, squarer below it. With `r.followsWindows` every radius scales from Hyprland's window rounding instead of the roundness setting |
| `Settings` | the only persisted state, JSON under the Quickshell state dir, its keys and defaults in `SettingsStore.qml`; a machine without the file starts from `profile/settings.json` | `effectiveDark`, `doNotDisturb`, `pinnedApps`, `dockOrder`, `accentColor`, `background{Light,Dark}`, `recentColors`, `pinnedColors`, `rememberColor`, `togglePinnedColor`, `fontFamily`, `systemFontBefore`, `wallpaper`, `roundnessFollowsWindows`, `dockAutoHide`, `dockBackground`, `vpnConnections` (the NetworkManager profiles the VPN menu offers, set by hand), `pin/unpin`, `forgetColor`, `toggleTheme`, `setFontFamily`, `setWallpaper`, `overrideKeys`, `pick`, `setOverride/isOverridden/resetOverrides` |
| `CompositorOptions` | the Hyprland options the settings panel changes, and the one pipeline that pushes any option with `hyprctl keyword` (`Compositor.focusWindow` turns `cursor:no_warps` on for its one dispatch and back) | `spec`, `keys`, `configured`, `value`, `known`, `set`, `hasTouchpad`, `derived` (options that follow the design system — the overview's and the windows' shadow — set by `CompositorTheme`) |
| `Overlay` | which popup is open, on which screen, its context menu, and outside-click and Escape dismissal | `active`, `screen`, `anchorX`, `payload`, `isOpen/open/openWith/openUnanchored/close/toggle`, `menu`, `openMenu/closeMenu`, `setPointerOver`, `dismissOnOutsideClick`, `dismissOnEscape` (a menu first, then the popup; neither while `Compositor.covered`) |
| `Compositor` | Hyprland's workspaces, monitors and windows, and whether something else covers a screen above them | `workspaces`, `toplevels`, `focusedScreen`, `monitorFor`, `appIdOf`, `focusWindow` (leaves the pointer where it is), `closeWindow`, `exec`, `switchToWorkspace`, `cycleWorkspace`, `isFullscreenOn`, `toggleOverview`, `covered` (a foreign surface over a whole screen on the overlay layer: slurp, hyprpicker; every press and key is its) |
| `Dock` | the dock's model: one entry per application, pinned or running, holding its open windows | `items`, `hideDelay`, `activate` (the window used last; while one has focus, the next), `launchNew`, `close` (every window), `togglePinned` |
| `Apps` | the desktop-entry index, search and launch-frequency | `all`, `byId`, `byAppId`, `search`, `launch`, `iconFor` |
| `Audio` | PipeWire sinks/sources, volume, mute, mic-in-use | `hasSink` (bound, not just present), `volume`, `muted`, `micInUse`, `volumeIcon`, `volumeIconFor`, `sinks`, `setVolume` (unmutes), `stepVolume`, `toggleMute`, `setSink` |
| `Network` | NetworkManager state and the Wi-Fi list | `available`, `hasWifi`, `hasWired`, `wifiEnabled`, `icon`, `label`, `signalIcon`, `wifiNetworks`, `activeWifi`, `connect`, `connectWithPassword`, `changePassword`, `forget`, `setScanning`, `restartWifi`, `restarting`, `passwordRequested`, `failure` |
| `Vpn` | the VPN menu: the NetworkManager connections `Settings.vpnConnections` names (states from `nmcli monitor`, switched with `nmcli`, latency a ping to the tunnel's far end), whether anything in the menu is up, and the one five-minute tick that measures every row | `available`, `anyActive`, `connections`, `states`, `isActive`, `status`, `toggle` |
| `V2rayn` | v2rayN, from the files it writes: the active server, its latency (a request through v2rayN's proxy), and in TUN mode a switch — the TUN core's Clash API mode, Rule or Direct, so no root is needed and the TUN stays up. Measured again when `ip monitor` sees the TUN come up | `available`, `active`, `status`, `canSwitch`, `direct`, `toggle`, `measure` |
| `Bt` | BlueZ adapter and devices | `available`, `enabled`, `listed`, `icon`, `label`, `setEnabled`, `toggleConnection` |
| `Power` | UPower battery and power-profiles-daemon | `hasBattery`, `percentage`, `icon`, `timeLabel`, `hasProfiles`, `profile`, `setProfile` |
| `Brightness` | the backlight: read and watched in sysfs, written through logind | `available` (once read), `value`, `set`, `step` |
| `Players` | MPRIS, with one sticky "current" player | `hasPlayer`, `playing`, `title`, `artist`, `playPause`, `seekTo`, `formatTime` |
| `Notifs` | the notification server, toast queue and history | `history`, `count`, `popups`, `remove`, `clearAll`, `plainBody`, `relativeLabel`, `timeoutFor` |
| `Keyboard` | the active XKB layout | `available`, `code` (e.g. `EN`), `cycle` (every keyboard at once) |
| `Osd` | the transient volume/mic/brightness indicator, listening to each source only once it holds a true reading | `shown`, `kind`, `value`, `icon`, `text`, `holdTime` |
| `Screenshot` | screen capture through grim/slurp; a region is dragged out over the screen frozen by hyprpicker | `capture`, `captureRegion` |
| `Wallpaper` | the pictures in ~/Pictures/Wallpapers, and driving hyprpaper | `folder`, `folderPath`, `items`, `available`, `current` (always a path: a saved bare name is that picture in the folder, empty until it is there), `set` |
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
| `Shadow` | a `RectangularShadow` per layer of `Appearance.shadowFor(level)`; `level` 1–3, 3 being the window shadow |
| `Icon` / `Icons` | a monochrome UI glyph drawn with QtQuick.Shapes from generated path data |
| `AppIcon` | an application icon from the XDG theme, with fallbacks; `optical` scales and centres its artwork to the same visual weight as every other icon drawn so (the dock's) |
| `IconShapes` | what `optical` measures: how much of its box each icon covers, once per icon, and the scale and offset that follow |
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
| `CompositorTheme` | pushes the design system's share of Hyprland's options: the shell's colours into the hyprexpo plugin so the overview matches the theme, and the window shadow |
| `MenuItemRow` | one row of a popup menu |

---

# Platform gotchas

These were verified on this machine under Hyprland 0.56.2, Quickshell 0.3.1
and Qt 6.11.2; it now runs Quickshell 0.3.2 and Qt 6.12, and the two that
0.3.2 fixed are marked so. Several of them are the reason code looks the way
it does; if you "simplify" past one you will reintroduce a bug that was
expensive to find.

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
- **`MultiEffect`'s blur stops at a gaussian of σ ≈ 20** (`blurMax` 64, the
  most it takes), grows unevenly below that (32 gives σ 6.7, 48 gives 14), and
  is counted in item pixels, so a smaller `layer.textureSize` does not widen
  it. `RectangularShadow` (QtQuick.Effects, Qt 6.9) draws a rounded
  rectangle's shadow analytically, as far as asked: its `blur` falls off like a
  gaussian of σ = (3 × blur − 4) / 8 (measured, rms 0.01), and its shader
  honours opacity. `Shadow` is built on it.
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
- **A `FileView` written from its own `onLoadFailed` warns** —
  `got operation finished from dropped operation` — because the write drops
  the failed read before it has finished (measured with `writeAdapter()` and
  `setText()` alike, in a bare `qs -p` test). `Settings` defers the write with
  `Qt.callLater`; the adapter still picks up what is written.
- **Do not read churny properties in a model.** `Dock.items` used to read window
  titles; every keystroke in a terminal rebuilt the whole dock. Titles are now
  read per-item off the toplevel. This was worth 0.3% of idle CPU. So is which
  window has focus: reading `activated` there rebuilt all 28 icons of two docks
  on every focus change, and the one under the pointer, newly made, had no
  hover — a click on it flashed the cursor to the arrow and back.
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
  `move` transition and keep their own list of what is still drawn. (The
  notification centre's `ListView`, whose `removeDisplaced` waits for the
  leaving row, does animate its first row out, measured on 6.12.)
- **A positioner's `move` transition writes `x` as well as `y`**: the x it
  read as the move began — during an earlier move, that move's destination —
  set at once, since the transition does not animate it (6.12.0's
  `QQuickItemViewTransitionJob::startTransition`). An item's own animation
  of `x` that ends in between is undone, and the item stays where the move
  caught it: toasts arriving 0.3 s apart, each pushing an older one out,
  rested up to 33 px off to the right. Slide a positioned item on a
  `Translate`, never on its own `x` or `y`.
- **`ListView` drops a height change of its first row while a view
  transition runs on that row** — `add`, or `displaced` as a row above it
  goes (`itemGeometryChanged` returns early, in 6.12.0's source), so the
  rows below keep the place the old height gave them. A positioner
  (`Column`, `Row`) in a delegate lays out again only on the next frame,
  which is exactly then: a wrapped body is measured once the card has its
  width, and a notification arriving with the centre open overlapped the
  one below it. A delegate's height is therefore a binding over what it
  holds, final when the delegate is made; `NotificationCard` is built so.
  Its width must not change afterwards either: rows narrowed only while
  the scrollbar showed rewrapped just as a row arrived and made it show, so
  `NotificationList` keeps the bar's footprint clear always.
- **`visible` reads false for everything in a popup while it is closed**: it
  is the effective visibility, and the popup's window is gone then. A size
  computed from a part's `visible` changes as the popup closes and again as
  it reopens. Every notification card collapsed to one line, and grew back
  while the date menu was applying what had arrived meanwhile — under the
  first-row rule above, so the row below overlapped it. Size from the
  condition the part shows on (`bodyText !== ""`), never from `visible`.
- **A `ListView` row displaced during its `add` transition keeps whatever
  opacity it had reached**: the displacement cuts the add short (Qt documents
  it under *Handling Interrupted Animations*). A burst of notifications into
  the open centre left every row but the newest invisible, so `displaced`
  animates opacity to 1 as well as `y`.
- **Centring a child on a container that sizes itself from its children is a
  binding loop** (`MenuRow`'s trailing slot is already centred). This was the
  one "Binding loop detected" every start used to log.
- **A `Notification` is destroyed the moment it closes** — dismissed,
  expired, or withdrawn by its application — so a card animating out was
  left reading null: its icon fell back to the bell. `NotificationCard`
  holds its notification with a `RetainableLock` until the card goes.
  Quickshell then refuses to close or invoke the held one again and says so
  at critical level; `Notifs.isOpen` (its `tracked`) is what the service
  checks first.
- **Quickshell gives battery charge and Wi-Fi signal as 0–1 fractions**, not
  the 0–100 UPower and NetworkManager speak. `Power.percentage` converts once;
  `Network.signalIcon` holds the thresholds as fractions.
- **Fixed in 0.3.2: a volume write did not reach a Bluetooth headset's
  microphone.** 0.3.1 reported the new level while the device kept the old
  one (wrote 0.3, `wpctl` read 0.6), and `Audio.setMicVolume` went through
  `wpctl set-volume` instead. Under 0.3.2 the node write lands (a WH-1000XM4:
  wrote 0.35, `wpctl` read 0.35 and kept it), so the mic is written like the
  speaker. On 0.3.1 the workaround would be needed again.
- **A `PwNode`'s volume is not real until the node is `ready`** (bound). What
  it reports while binding is its state, not a change: `Audio.hasSink` waits
  for it, and that is what keeps the OSD from flashing at login.
- **Fixed in 0.3.2: `Networking` never recovered from NetworkManager
  restarting** (its changelog: "networking state breaking after restarting
  NetworkManager"). Under 0.3.1 the devices went and were not registered
  again, so Wi-Fi read "Unavailable" while it worked, and `Network` restarted
  the shell's unit whenever NetworkManager's bus name got a new owner; that
  watcher is gone with the upgrade. (A probe that reads `Networking.devices`
  from a timer sees none: the backend connects on first use, then fills in.)
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
- **Qt 6.12 warns on every popup close** —
  `QWaylandTextInputv3::disableSurface … Trying to disable <surface> but
  <other> is focused` — popups with no text field included, so it is not the
  shell's focus handling: Qt disables text input for each window it hides,
  and Hyprland never gave that surface text input. Nothing is lost. A
  `//@ pragma Env QT_LOGGING_RULES=…` does nothing (Quickshell installs its
  own log filter), so the unit's command line in `hyprland.conf` passes
  `--log-rules qt.qpa.wayland.textinput.warning=false`; a `qs` started by
  hand shows the warning.
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
- **A layer rule's `order` puts a higher number *beneath*.** Within one layer
  Hyprland draws surfaces sorted by descending `order`, creation order among
  equals (`arrangeLayersForMonitor` in the 0.56.2 source): the screenshot
  freeze is −1 and slurp −2, so slurp is on top and a toast (0) is under both.
- **A layer surface's fade-out is in a capture taken right after it unmaps.**
  grim run the moment slurp exited took slurp's fading border, a black frame
  around every region shot. `no_anim` drops the snapshot that fades.
- **Layer blur follows the surface's alpha** (`ignore_alpha`). A popup's
  surface spans the screen but is mostly transparent, and only its card is
  blurred behind. Hyprland's blur strength is global (`decoration:blur`), and
  this machine's is light, which is why `c.glass` is high.
- **A colour with alpha stringifies as `#aarrggbb`.** Anything handing a
  token to Hyprland builds `rgba(rrggbbaa)` from the channels
  (`CompositorTheme.rgba`); slicing the string would give the overview white
  borders.
- **Hyprland draws one shadow per window, solid over its own box.** The box
  is the window moved by `decoration:shadow:offset`; past its edge the alpha
  falls as ((range − d) / range)^render_power. A dropped shadow is therefore
  even for the depth of the drop just under the window (measured: 0.27 to
  within 0.001 of that formula), and that reads as a grey slab with a hard
  lower edge — plain at a 22 px and a 12 px drop beside a popup's gaussian,
  gone at 6, where it passes for the window's rim. `decoration:glow` is no
  second layer: it is an inner glow, drawn over the window.
- **`hyprctl keyword` answers `ok` for a plugin option that does not exist.**
  The overview's border weight went to `border_size` (this fork's is
  `border_width`) and never took effect. Read a new one back with
  `hyprctl getoption`.
- **`focuswindow` warps the pointer onto the window it focuses**, and so does a
  foreign-toplevel activate (`CWindow::activate`, which also marks the window
  urgent). Only `cursor:no_warps` stops it, and it stops every warp — a
  keyboard `movefocus` too, which with `follow_mouse = 1` then leaves the
  pointer over the window focus left. `Compositor.focusWindow` turns it on
  inside one `hyprctl --batch` around the dispatch and puts the value it read
  back; Hyprland runs a batch with nothing in between.
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
  the overview's hover. Kill it by PID — the PID of the instance just
  started, told apart from any left running by comparing `hyprctl instances`
  before and after. **Never copy a plugin over the `.so` a running instance
  has loaded**: it crashes that instance later, on its way out, with no
  backtrace and no plugins listed, which reads as a shutdown crash of the
  plugin's own. `debug:disable_logs` is on by default and the log only
  opens at startup, so a nested instance to be traced needs it off in its
  config.
- **Trackpad gestures can be synthesised, but only in the session**: a
  nested compositor gets no touchpad. A `/dev/uinput` device with
  `BTN_TOOL_FINGER`…`BTN_TOOL_TRIPLETAP`, MT slots, axis resolutions and
  `INPUT_PROP_POINTER` is a touchpad to libinput, and three slots moving
  together are a swipe. Hyprland holds one active gesture across *all*
  touchpads, so a real swipe during the test corrupts it; libinput's lines
  in the Hyprland log name the device (`eventN - gesture: [3fg] …`), so
  check that only yours swiped.
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
against different headers**, so it must be rebuilt after every Hyprland update,
and `hyprland.conf` does that by itself: an `exec-once` runs the build script
with `--if-stale` at every login, which compares the Hyprland the plugin was
built against (`built-for`, written beside it) with the installed one, and
only on a difference rebuilds, loads the result into the running Hyprland
(unless one is loaded, or the binary was replaced on disk — see *Testing*)
and sends a notification. Its output is in `journalctl --user -t hyprexpo`.
`master` chases hyprland-git and will not compile against a release.

Five patches are applied, in order, all relative to the source directory:
`hyprexpo-real-wallpaper-bg.patch` (the real wallpaper, blurred, behind the
tiles), `hyprexpo-tile-zoom-and-add-tile.patch`,
`hyprexpo-swipe-open-close.patch`, `hyprexpo-shell-above-overview.patch` and
`hyprexpo-key-zoom.patch`. The second highlights a
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
shell's *Animations* setting, the session's reduced motion), and scales with
how far open the overview is, the way the gaps do, so a workspace leaves the
screen and lands back on it exactly. It also gives the dynamic grid a last tile, the
lowest-numbered workspace this monitor can take — one no workspace has yet,
or one it holds empty and does not show; never another monitor's — drawn as
the empty workspace it is (a missing workspace captures as the bare monitor)
and chosen through the same `ensureWorkspaceForTile` path as any tile.
`gaps_out` in `hyprland.conf` keeps the grid off the screen's edges on every
side; tiles keep the screen's shape, so only the axis the grid fills first
gets exactly that.

The third is the swipe. **How far open the overview is comes from the zoom
itself** (`openness()`, 0 with the current tile filling the screen, 1 with
the grid fitting it), and the gaps, the outer margin and the focus zoom all
follow it. Upstream read `getPercent()` of the animation driving the zoom,
but a swipe moves the zoom with `setValueAndWarp` and never starts one: the
gaps were all there on a swipe's first frame, vanished when the fingers
lifted (the settle animation restarts that clock at 0) and grew back. It
also makes `gesture_direction` open only — a swipe that way over an open
overview does nothing — and registers the opposite direction as upstream's
`cancel` gesture, which closes back to the workspace the overview opened on,
the way Escape and Super+Tab do. Hyprland lets `up` and `down` coexist on
one finger count; only `vertical` would shadow either.

The fourth keeps the shell where it stands. `renderWorkspace`, which the
plugin both replaces with the overview and calls to take each workspace's
picture, draws the top and overlay layers too: upstream the bar and the dock
vanished from the screen and appeared, frozen, inside every tile. Now each
picture is taken with those two layer lists set aside for the one render
(`CShellLayersAside`), and after the overview the hook draws them itself,
where they stand, with Hyprland's `renderLayer` — protected, so found by
name like the hooks, and the whole patch stands down if it is not found. A
pointer move or click where a top or overlay surface's input region is
(`hitTest().layerSurfaceAt`, and the layers' popups) is left to Hyprland
instead of being taken by the overview, and coming off one the shell is told
the pointer left (`setPointerFocus(nullptr)`), since the overview's own moves
never reach Hyprland's focus. While a shell surface holds the keyboard the
overview leaves every key to it, so the launcher opened over it can be
typed into. The grid's outer margin is per side: `gaps_out` past the
monitor's reserved area, so no tile sits under the bar or a dock that stays
out. And each tile shows the work area alone: its picture is cropped (UVs)
by the reserved edges, which only the shell would fill, and the tiles take
the cropped picture's shape — `aspectCorrectTileSize` used to take the
area's, which with per-side margins stretched every picture 12% wide. Both
scale with how far open the overview is, like the margins, so the current
tile still fills the screen uncropped as it opens and closes. **A layout
takes the tiles' shape at the openness of the size it is given**
(`opennessFor`), never the current one: the zoom's targets are laid out
ahead of time, and closing from open with the open shape stopped short of
the tile — the workspace below it stayed on screen until the overview went.
Nor may the crop read the zoom before it exists: the first tile boxes are
laid out while the overview is being made, and a nested Hyprland segfaulted
there. Verified in a nested Hyprland with a stand-in bar and dock — drawn live
above the tiles and absent from them, hover entering and leaving them, the
grid clear of both, tiles of the work area's shape with no band where the
shell was, recorded frame by frame opening, closing and selecting (the same,
another and the new tile) and switching workspace under it — and in the
session: a click on the dock opens the launcher over the overview, typing
reaches it and Escape closes only it; a tile clicked, a number key, Escape
and a three-finger swipe (a uinput touchpad, see *Testing*) each close it
with nothing of another workspace left on screen; a window drags between
tiles; the auto-hiding dock comes up over it on the bottom edge and goes.

The fifth gives **every zoom one pace** — Super+Tab, a tile chosen, a swipe
let go of. On `windowsMove` (easeOutQuint here) a zoom always took the whole
479 ms and left at five times its average pace: measured, the first frame of
an open already stood a third of the way there, and a swipe let go of early
shot across the rest. Now a whole zoom takes four fifths of `windowsMove`'s
time (380 ms here), and any part of one that part of it, so the overview
moves as fast whether a swipe is let go of a fifth of the way or four fifths
(`zoomTo`). A zoom from rest — a key, a close taken back — eases in on
Material's standard curve (2% in its first frame, 90% at about 215 ms); a
swipe's release is already moving and leaves at twice its average pace,
slowing to a stop. Each overview has its own animation config, timed per
zoom, with the curves registered with Hyprland's animation manager — and
again after a config reload, which drops every curve — and on or off with
`windowsMove`. A close starts its zoom after the captures it takes, so its
clock starts when frames can follow. **Stepping the zoom from the frames
instead does not work**: a frame asked for from `render.pre` is taken by the
one being drawn, and once nothing else animated the zoom crawled on whatever
else happened to draw — a terminal's cursor blink. And the toggle, pressed
while the overview is still closing (it looks shut well before its zoom
ends), opens it back from where it stands (`reopenClosingOverviews`); a
close that changed workspace cannot be taken back, so that one is finished
and the overview opened afresh. Before, a close under way was the toggle's
to close again and the press was lost, and after a swipe's release closed it
`isSwiping` stayed set and refused it outright. Verified in a nested
Hyprland with this desktop's animations, frame by frame from a trace: an
open or close 380 ms, 90% at 217 ms, 2% in the first frame, no frame missed;
a close taken back from a third open in 250 ms; with animations off it
jumps.
