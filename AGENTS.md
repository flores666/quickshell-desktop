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
./tools/test.sh                   # the tests in tests/, each as the whole shell under qs -p
python3 tools/genicons.py         # regenerate components/Icons.qml
./tools/build-overview-plugin.sh  # rebuild the hyprexpo plugin (--if-stale: only if out of date)
./tools/build-windows-plugin.sh   # rebuild the window plugin (--if-stale: likewise)
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

`./tools/test.sh` runs `tests/*Test.qml`. Quickshell is built into `qs`, so
`qmltestrunner` cannot import it: each test is run as the whole shell, under
`qs -p`, in a copy of the tree whose `shell.qml` holds that test alone, with
state and cache directories of its own (Settings starts from `profile/` and
writes nothing real). A test reports through `tests/Check.qml` — a `PASS` or
`FAIL` line per check, then `TESTS DONE n failed` — and the script stops the
instance after that line, since nothing in QML can make `qs` quit. What the
tests reach is the logic a popup hangs on (the hand-off, a card's geometry);
how it looks is still checked on screen. Run them inside a nested Hyprland
(`HYPRLAND_INSTANCE_SIGNATURE` and `WAYLAND_DISPLAY` set to its own; see
*Testing*): a test that needs a window opens one.

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
  common/            shared surface chrome (OverlaySurface, ShellOverlay,
                     OverlayCard), IPC,
                     overview theming
tools/               generators, the lint and test wrappers and
                     save-profile.sh; not loaded at runtime
tests/               *Test.qml, run by tools/test.sh, and Check, what they
                     report through; WindowDriver, a kitty the Window*Test
                     ones switch between modes
docs/specs/          what a change set out to do, item by item, with the
                     checks its tests encode
hyprland.conf        the shell's Hyprland integration, sourced from
                     hypr/conf.d/90-quickshell.conf: the plugins, the shell's
                     global binds, the bindn dismissal binds

install.sh           sets a computer up as this desktop. Safe to re-run
packages.txt         every package from the official repositories
packages-aur.txt     every package from the AUR
hypr/                the Hyprland config (hyprland.conf sources conf.d/*.conf
                     in name order) and hyprpaper.conf; windows/ is the
                     window plugin's source (see *The window plugin*)
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
identify it in `hyprctl layers`; the popups share one, `shell-popups`.

**Popup** — launcher, quick settings, settings, date menu, tray menu, dock menu,
VPN menu.
Each is a `ShellOverlay`, and all their cards are drawn in the one window,
`OverlaySurface`. Exactly one can be open at a time.

**Overlay (the service)** — the arbiter that enforces "one popup at a time".
Every open/close routes through it, which is why the invariant holds by
construction rather than by every surface remembering to close its siblings.

**Flight** — a popup opened while another is open on the same screen does not
fade in: its card starts exactly over the other's and flies to its own place
in `t.popupResize`, as one card. The other's contents ride along as a picture and
fade out over the first half of the way, the new contents fade in over the
second, each at its own size, centred and clipped by the card — to its
rounded shape (`RoundedClip`), since a plain `clip` is square and the contents,
bigger than the card for most of the way, filled its corners. Every popup's
card is drawn in one window (`OverlaySurface`), in the same coordinates, so
the hand-off is one change to one scene: the old card is hidden in the very
frame the new one takes off. Each popup had a window of its own once, and two
surfaces cannot change together (see the Hyprland gotchas): the swap blinked.
`Overlay.open` records the hand-off (`flight`); the old card holds, takes a
picture of itself (`grabToImage`) and hands it over with its place and how
strongly it is drawn (`depart`); the new one takes off once it has settled,
as strong as the old one was — still fading in, switched away from at once —
and coming in from there, and the old card goes as it does (`arrive`). A
handed-over card stays hidden until it is up again, opened alone or taking
off itself: switched straight back to, it is still on its way out, and was
drawn beside the card flying from its place. A hand-off with nothing to hand over (the
old card not yet settled), or whose picture is not in by the time the new
card would have appeared anyway (`t.popupFade`), is dropped (`abandon`), and both
open and close as they would alone. Another screen is no hand-off. The same
popup given a new subject while it is up (a second dock icon's or tray
icon's menu) takes over from itself (`renewing`): `Overlay.openWith` holds
the new subject and its anchor in the hand-off, the card hands over a
picture of itself, and the subject goes in in the very frame it takes off
from where it is, so its contents cross-fade as it moves instead of
changing in one frame; dropped, the subject goes in at once. While a card
flies its rest (`liveX`, `liveHeight`) does not glide as well: the flight
carries it there on the same clock and curve, and the two together slowed
the start and hurried the end. Quick settings' gear opens the settings
panel over it, not after closing it, so that is a flight too. The popups' surface maps without Hyprland's
layer animation (`hyprland.conf`'s `shell-popups` rule): the cards draw their
own coming and going.

**Card** — the visible rounded panel of a popup, in the popups' window. The
window spans the room between the bar and the dock (or a taller card) plus
`pad` (room for the shadow) — as much of it as the screen leaves above and
below, so a card keeps its place under the bar or above the dock and a deep
shadow is cut off by the screen's edge; input is masked to the open popup's
card alone.

**Popup pace** — a popup's own motion is `Appearance.t.popupPace` (1.3) times
as quick as the rest of the shell's: `popupFade`, `popupMove` and
`popupResize` are `fast`, `base` and `resize` at that pace. Every animation
of a popup's card (its fade, door, flight, resize and re-anchoring),
whatever is timed against those (the card let go after its fade, a hand-off's
wait for its picture), and quick settings' page swap, which the card's resize
follows, take them, as do the dock's window preview and a floating window's
title bar, which roll as a popup's door does; the controls inside a popup
keep the shell's pace, and so do the date menu's notifications, which leave
as toasts do.

**Door** — how a popup opens and closes when no other is open: its card rolls
out of the edge of the panel it opens off, as a garage door, and back into it
(`OverlayCard.door`, `rolled`) — the dock's above the dock, the bar's under
it, and a centred popup (the launcher, settings) hangs under the bar too. The
dock's window preview rolls up out of the dock the same way; both hang from
one `Door` (`components/`). The card's own box grows from the edge it hangs
from, so its shadow, glass and corners follow with no clip line, and its
contents ride the moving edge, the far end showing first. It is never shorter
than its two corners (`Door.shut`), so it is the card's own rounded rectangle
all the way: grown from nothing it was a capsule until it passed them. It
fades in from there in `t.popupFade`, and rolls out in `t.popupMove` on
`emphasizedEasing`; in again in `t.popupFade`, before the popup lets its card
go. A popup taking over from another flies instead (*Flight*). The door holds
still while a card flies: closed mid-flight, a card lands whole and only then
rolls in, where it used to land on whatever the door had reached meanwhile —
150 px shorter in one frame. A window's title bar rolls out of the window's
top edge and back into it the same way, in the compositor (the `windows`
plugin, on the door's timings and curves), without the fade: it is opaque,
part of the window.

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
surface. The bar and the dock lay down a share of the glass the user sets
(`Appearance.barOpacity`, `dockOpacity`; `Surface.glass`): 100% is the theme's
own and never more, 0 none — and below about 57% the panel is no longer over
half opaque, so nothing behind it is blurred.

**Backdrop** — what the wallpaper is under a part of a screen: its mean colour
there, as hyprpaper lays the picture (cover). Thinned, the bar's and the dock's
glass is read against it so that what is on them stays legible. The glass
itself takes the other theme's tint (`Appearance.glassOver`) once the theme's
text would read on the mix at under WCAG's 4.5:1 over the mean behind the whole
panel — never at 100%, where the theme's glass reads over black and white
alike. Each control, window dot and divider then takes whichever theme's
colours read better (`Appearance.schemeOn`) over the wallpaper behind it
alone (`Surface.schemeOver`), and the tray's icons are drawn in that ink
(`AppIcon.ink`). Applications' own icons in the dock are their artwork and
are not touched. Each screen's picture is measured once per picture and size
(`BackdropProbe`, in the bar), and every lookup after that is four reads of a
summed-area table (`Backdrop`). The wallpaper is all it knows: a window under
the auto-hiding dock is not seen, and what Hyprland does to the wallpaper —
dimming it behind a special workspace, and a little where its blur is drawn
(from about 57% up) — is left out of the mix, so near where the tint changes
it changes a few percent early or late.

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
*Auto-hide* (`dockAutoHide`) and *Match top panel*
(`dockOpacityFollowsBar`, the dock taking the bar's opacity).

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

**Title bar** — the macOS-style bar on every window whose client does not draw
its own frame, unless the user hid it for that application from the dock's
menu, in the application's own colour where that can be told. **Not a shell surface** either: it is the `windows` compositor
plugin, built from `hypr/windows`, a window decoration Hyprland positions,
draws and offers input to. **Minimized** is a window on `special:minimized`,
since Hyprland has no such state.

**Switcher** — Alt+Tab, as macOS's Command-Tab: hold Alt and press Tab to go
round the windows of the workspace in front, most recently used first, and
let go to bring the one chosen forward; a quick Alt+Tab is the window before.
Only that workspace's: the focused one, and a special one shown over it while
the window with focus is there — never the workspace of a window that last
had focus (an empty workspace offers nothing), nor the minimized.
**Not a popup**: it takes no keyboard focus, Hyprland holds every key of it
(`hyprland.conf`: Alt+Tab enters a `switcher` submap, Alt's release commits),
and it closes whatever popup is open. `services/Switcher` keeps the order and
the choice, `modules/switcher` draws it, after `t.glance`: its card fades and
slides into place and back out at the popups' pace, 1.5 times quicker still
(`t.switcherPace`, `switcherFade`, `switcherMove`), holding what it shows
through the fade out, and the title under the row changes only once the last
has faded out.

**Safe triangle** — the dock's window preview, open over one application's
icon, is not taken by the icons the pointer crosses on its way up to it:
inside the triangle from where the pointer left that icon to the two ends of
the card's lower edge (`DockPreview.aim`, `aiming`), the icons it passes over
and the gaps between them count for nothing. Out of it, or resting on another
icon for `t.hop`, the preview rolls back into the dock and out again over that
one if it has windows to show; one without has its tooltip once the preview
is in.

**Placement** of a window (not a popup's, above) — windows open floating, and
each application as it was last left: tiled, or floating at its size. Also
the `windows` plugin; see *The window plugin*.

**Stacking** — windows stack in the order they were last clicked, tiled ones
among the floating: a tiled window clicked is drawn over the floating windows
on it, and takes the pointer there; a hover focuses without raising. Also the
`windows` plugin; see *The window plugin*.

## Services (`services/`, all `pragma Singleton`)

| Service | Owns | Key surface |
|---|---|---|
| `Appearance` (in `config/`) | the whole palette and every metric | `c` (colours), `day`/`night` (each theme's scheme, from its own seed), `barOpacity`/`dockOpacity` (0–1 of the glass; the dock's may be the bar's), `glassOver` (a thinned panel's tint over what shows through), `schemeOn` (the theme, or the other, whichever's text reads better on a colour), `laid` (a fill at a share over a colour), `contrast`, `luminance`, `s` `r` `m` `t` `font`, `windowShadow`, `shadowFor(level)` (layers in CSS `drop-shadow` terms, and `pad`), `seedRange(seed)`, `inSeedRange` |
| `Appearance.m` / `Appearance.r` (in `config/`) | sizes and radii, resolved through `Tuning.pick` | `barHeight`, `barItemHeight`, `barFootprint`, `dockIcon`, `dockSlot` (one round slot for every dock item, its highlight included), `dockHeight`, `dockFootprint`, `border`, `navRowHeight`; `r.panel` is **the** radius of every popup card and toast — nothing picks its own — and `r.capsule(height)` is the bar's, the dock's and the OSD's, and their controls': fully round at the tuned roundness, squarer below it. With `r.followsWindows` every radius scales from Hyprland's window rounding instead of the roundness setting |
| `Settings` | the only persisted state, JSON under the Quickshell state dir, its keys and defaults in `SettingsStore.qml`; a machine without the file starts from `profile/settings.json` | `effectiveDark`, `doNotDisturb`, `pinnedApps`, `dockOrder`, `hiddenTitleBars` (app ids, from the dock's menu), `isTitleBarHidden/toggleTitleBar`, `accentColor`, `background{Light,Dark}`, `recentColors`, `pinnedColors`, `rememberColor`, `togglePinnedColor`, `fontFamily`, `systemFontBefore`, `wallpaper`, `roundnessFollowsWindows`, `dockAutoHide`, `dockOpacityFollowsBar`, `vpnConnections` (the NetworkManager profiles the VPN menu offers, set by hand), `pin/unpin`, `forgetColor`, `toggleTheme`, `setFontFamily`, `setWallpaper`, `overrideKeys`, `pick`, `setOverride/isOverridden/resetOverrides` |
| `CompositorOptions` | the Hyprland options the settings panel changes, and the one pipeline that pushes any option with `hyprctl keyword` (`Compositor.focusWindow` turns `cursor:no_warps` on for its one dispatch and back) | `spec`, `keys`, `configured`, `value`, `known`, `set`, `hasTouchpad`, `derived` (options that follow the design system — the overview's, the title bars' and the windows' shadow — set by `CompositorTheme`) |
| `Overlay` | which popup is open, on which screen, its context menu, and outside-click and Escape dismissal | `active`, `screen`, `anchorXOf` (each popup's anchor, by name, set only as that popup opens: one anchor for all slid the card being taken over from towards the next popup's button), `payload`, `isOpen/open/openWith/openUnanchored/close/toggle`, `menu`, `openMenu/closeMenu`, `setPointerOver`, `dismissOnOutsideClick`, `dismissOnEscape` (a menu first, then the popup; neither while `Compositor.covered`), `flight` (`{ from, to, rect, strength, contents, away }`, and `at` and `subject` for a popup taking over from itself; see *Flight*), `depart/arrive/abandon` (each acts only for the popup the hand-off names) |
| `Compositor` | Hyprland's workspaces, monitors and windows, and whether something else covers a screen above them | `workspaces`, `toplevels`, `focusedScreen`, `monitorFor`, `appIdOf`, `focusWindow` (leaves the pointer where it is; brings a minimized window back first; raises it), `minimizedWorkspace`, `closeWindow`, `exec`, `switchToWorkspace`, `cycleWorkspace`, `isFullscreenOn`, `toggleOverview`, `covered` (a foreign surface over a whole screen on the overlay layer: slurp, hyprpicker; every press and key is its) |
| `TitleBars` | the window plugin's title bars from the shell's side: the applications they are hidden for, handed to the plugin (`windows:hidden_for`), and which windows have one | `hidden`, `byWindow` (address → whether it has a bar; only the plugin knows), `read` (asked as the dock's menu opens) |
| `Dock` | the dock's model: one entry per application, pinned or running, holding its open windows | `items`, `hideDelay`, `activate` (an application's one window, brought back if minimized, or a launch; one with several has the preview, on a click as on a hover), `launchNew`, `close` (every window), `togglePinned` |
| `Switcher` | Alt+Tab: the windows in order of focus since the shell started, and, while it is open, what it goes round and which is chosen | `recent`, `active`, `entries` (taken as it opens: the dock's windows on the workspace in front), `index`, `current`, `step`, `point`, `commit`, `choose`, `cancel` |
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
| `Clickable` | **the interaction primitive.** Hover, press, selected, disabled, focus ring, keyboard activation (Space/Enter click; Menu or Shift+F10 right-click). Everything clickable derives from it. `scheme` is the `ColorScheme` its state layer and ring are drawn in, `Appearance.c` unless it stands on thinned glass |
| `Surface` | a glass panel: `c.chrome` (the surface at `c.glass` opacity), a hairline and a `Shadow`; the compositor blurs what is behind it. `glass` fades all three together, eased, and leaves the content alone. Given its `screen` and where it rests there (`placedAt`), as the bar and the dock are, its `scheme` (the tint) and `schemeOver(item)` (the colours for anything on it, from where that rests: parents' positions read one by one so a binding hears each move) follow the wallpaper behind it (see *Backdrop*) |
| `Backdrop` | the wallpaper's mean colour under any rectangle of a screen (`colorUnder`), from a summed-area table per screen; `measured`, `measure`, `gauge` (one pixel per `cell`, 8 logical px) |
| `BackdropProbe` | measures one screen's picture for `Backdrop` whenever it or the screen's size changes: decoded off the main thread, already shrunk, into a canvas nobody sees (a canvas needs a window; the bar holds it) |
| `RoundedClip` | its children cut to a rounded rectangle by one mask while `active` (two layers and a `MultiEffect`), and drawn as they are while not: `ColorPicker`'s square gradients, a popup card's contents while it flies or resizes |
| `Shadow` | a `RectangularShadow` per layer of `Appearance.shadowFor(level)`; `level` 1–3, 3 being the window shadow |
| `Door` | how a card hanging from an edge rolls out of it and back (see *Door*): `edge`, `out`, `full`, `radius` in; `rolled`, `rolling`, `shut`, `extent` (its height), `drop` (where its box starts), `contentY` out. A popup's card and the dock's window preview hang from one |
| `Icon` / `Icons` | a monochrome UI glyph drawn with QtQuick.Shapes from generated path data |
| `AppIcon` | an application icon from the XDG theme, with fallbacks; `optical` scales and centres its artwork to the same visual weight as every other icon drawn so (the dock's); `ink` draws it among the shell's glyphs (the tray's): desaturated, and a one-tone glyph levelled (Qt5Compat's `LevelAdjust`) so its tone comes out in the ink; artwork of both tones, a light sign on a dark plate, reads on either and keeps them |
| `IconShapes` | what `optical` and `ink` measure: how much of its box each icon covers, once per icon, the scale and offset that follow, and how much of its artwork is `light` |
| `Label` | text with the type scale applied; use instead of bare `Text`. `scheme` as `Clickable`'s |
| `ColorPicker` | an HSV plane and hue strip, optionally held to a saturation/value band; `moved`/`committed` like `Slider`, arrow keys, no wheel |
| `Filmstrip` | a sideways-scrolling row of choices wider than its room: wallpaper previews, font samples |
| `MenuRow` | a popover list row; `flush` drops the inset and wash so it sits among a settings pane's sliders |
| `FieldWell` | the well every text input sits in: no border, a wash on hover and a stronger one while the input has the keyboard; its hover is a `Clickable` laid over the input taking no buttons, and anything with its own hover goes in `trailing` above it |
| `IconButton`, `TextButton` (`compact` for in-row actions), `ToggleSwitch`, `Slider`, `SearchField`, `Spinner`, `Divider`, `ThinScrollBar`, `Tooltip` (`below` for one at the top of a popup) | the rest of the kit |

## Module chrome (`modules/common/`)

| File | Purpose |
|---|---|
| `OverlaySurface` | the one window every popup's card is drawn in (`shell.qml` puts the popups in it): the room between the bar and the dock, its shadow padding, masking to the open popup's card, keyboard focus and outside-click dismissal. Its `frame` samples the bar's and dock's footprints when the surface maps and holds them until it unmaps — those are user-settable, and the popup that changes them is the settings panel itself. Mapped while any card is drawn, so a hand-off never maps or unmaps it |
| `ShellOverlay` | the base every popup derives from, an item over the surface's room: placement, sizing, the open/settle/fade lifecycle. `liveX`/`liveHeight` are the card's eased rest; `cardItem` the card. Its settle waits for a hand-off's picture, bounded by `t.popupFade`, and its card stays up for one that is holding |
| `OverlayCard` | the card inside it: the door (`door`, `rolled`) and the fade (as one flattened layer), clipping, hover reporting to `Overlay`, swallowing Escape (the global bind acts on it), and the flight: `rest`, `from`, `flown`, `flying`, `outgoing`/`incoming` (the two contents' strengths), `holding`, `renewing` (taking over from itself, for a new subject), `depart()`, `arrive()` |
| `CardMenu` | a context menu inside the open popup — whatever `Overlay.menu` asks for — drawn over the card's content so the content's clipping cannot cut it off; a press anywhere else on the card closes it |
| `ShellIpc` | the external control surface. Every action exists once in `run(action)`; the IPC handler and the global shortcuts both dispatch to it |
| `CompositorTheme` | pushes the design system's share of Hyprland's options: the shell's colours into the hyprexpo plugin so the overview matches the theme, the title bars' colours and timings, and the window shadow |
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
- **An `Item` cannot declare a property named `top`** (or `left`, `bottom`,
  …): those are its anchor lines (`parent.top`), and final. Symptom: `Cannot
  override FINAL property` at load, the type unavailable — again caught by the
  runtime log, not qmllint. The card's is `windowTop`.
- **`Qt.quit()` and `Qt.exit()` do nothing under `qs`**: it logs that the
  engine's `quit()`/`exit()` signal has no receivers and keeps running, which
  is why `tools/test.sh` stops a test itself.
- **`grabToImage` is refused for an item whose window is not up yet**
  (`item is not attached to a window`, and it returns false) — in
  `Component.onCompleted` of a window's content, say. The result arrives a
  frame or two later (45–85 ms measured for a popup's card); its `url` is good
  for as long as the result object is held.
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
- **A key taken out of `SettingsStore` leaves settings.json at the next
  write**: the adapter writes only what it declares, and the hot reload of
  the edit rewrote the file within seconds (`dockBackground`, replaced by
  `dockOpacity`). Read a renamed preference's value off the file before the
  edit lands, to carry it over.
- **`Canvas.loadImage` of a picture the image cache already holds emits no
  `imageLoaded`**: it is loaded at once, and `isImageLoaded` says so straight
  after the call (measured in a `qs -p` test: a second canvas asking for the
  same picture at the same size never heard the signal). Check it after
  asking, as `BackdropProbe` does. A canvas also keeps one picture per URL, at
  the size first asked for: unload it to ask again at another.
- **`createImageData` takes a picture by string, not by `url`**: handed a
  `url`-typed value it returns undefined, and the same text as a string gives
  the pixels.
- **Reading a `CanvasPixelArray` element by element is slow**: 32 ms to read
  480×228 pixels once, where `new Uint8Array(data)` copies them in 8 and the
  typed array then reads fast. And the engine compiles a function only once it
  has been called a few times, so a loop run once stays interpreted: building
  `Backdrop`'s table in one loop took 17–20 ms per screen at startup, a call per
  row 10–12.
- **Qt5Compat's `LevelAdjust` levels alpha as it does colour**: from the output
  colours' own alphas. Give the low end alpha 0 and the high end 1, or an
  icon's transparent background comes out in the low colour.
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
  Draw the gradient square and round it with a mask — `RoundedClip`, as
  `ColorPicker` does.
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
  is the effective visibility, and the popup (`ShellOverlay`) is hidden then. A size
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
- **A property declared on a `Binding` and read by its own `value` logs a
  binding loop** at every load — `value` reads it before it has been
  evaluated. `CompositorTheme`'s title bar options are a function for this
  reason; `windowShadow`, a plain literal, gets away with being a property.
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
- **Two surfaces cannot change together.** Each commits its own frames, and
  the compositor draws whatever each has committed by then: a popup's card
  handed from one popup's window to another's showed a frame with neither
  card (the old window's empty frame committed first: 1 swap in 42, measured
  in a nested Hyprland) or one with both stacked — glass on glass, about 9%
  darker over a light wallpaper — in most of the rest. Ordering the commits
  removes the first and leaves the second. What has to change at once goes in one
  surface: every popup's card is in `OverlaySurface` for this reason.
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
  second layer: it is an inner glow, drawn over the window. The box takes in
  the decorations' boxes, so any room a decoration holds that it does not
  fill shows the shadow's solid core: a title bar that held its 28 px while
  fading in showed a grey band.
- **Firefox (Zen) draws its page in a subsurface that lags a resize by
  60–100 ms.** GTK acknowledges the new size on the toplevel within a frame
  or two, and the subsurface's first buffer at the new size is the old
  picture, the rest of it transparent; the page follows. Hyprland, while the
  window's box animates, scales and crops subsurfaces by the acknowledged
  size, so the lag shows whatever the box does meanwhile: an empty band as
  it grows. Holding the box still until the acknowledgement, or until the
  subsurface's next damaged commit, was measured frame by frame in a nested
  Hyprland and only traded the band for the page drawn small in the old box.
  It is the application's, and is left alone.
- **Hyprland's floating ↔ tiled toggle keeps a window's fullscreen mode**:
  `changeFloatingMode` takes it out, toggles, and puts the old mode back.
- **A maximized window is laid out once, as it maximizes.** Its box is the
  work area less the room its decorations reserve, read then; a change of
  that room later recalculates the window's target, which returns early for
  a fullscreen window unless a position is queued. Recalculating its space
  checks the box against the work area again (`syncTargetSizeAndPosition`).
- **`setPositionGlobal` on a floating target skips the floating layout's
  record of it** (`lastBox`), which un-maximize and un-fullscreen restore:
  a window placed so came back where Hyprland had first put it.
  `g_layoutManager->setTargetGeom` sets the box and the record.
- **kitty remembers its last size and whether it was maximized**, in
  `~/.cache/kitty/main.json`, and asks for both as it opens: a kitty run in
  a nested Hyprland and closed maximized made the session's next one ask to
  open maximized at the nested screen's size. A test's kitty takes a cache
  of its own (`KITTY_CACHE_DIRECTORY`).
- **`hyprctl keyword` applies no option's refresh bits.** A plugin's
  `SColorValueOptions{.refresh = …}` take effect on a config reload only; a
  keyword gets just the side effects `dispatchKeyword` hard-codes by name
  (`decoration:` damages every monitor, `windowrule` reloads the rules), and no
  plugin hears that its option changed. A change a plugin has to act on goes
  through a dispatcher (`windows:hidden_for`).
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
- **A key's release is matched in the submap it was pressed in**
  (`submapAtPress`), not the one in force. Alt goes down before Tab, so
  Alt+Tab's commit on Alt's release is a main-map bind, though Alt+Tab
  entered the `switcher` submap.
- **A release bind on a modifier is shadowed once another key goes down with
  it** — how `bindr = SUPER, SUPER_L` stays out of Super+key — unless it is
  `global` or transparent (`shadowKeybinds`). The switcher's `submap reset` on
  Alt's release is `bindrt` for this reason: as `bindr` it never ran after
  Alt+Tab, and the next Alt release committed nothing.
- **Hyprland collects a key's binds in config order and stops at one that
  changes submap**, so the `global` comes before the `submap` it pairs with.
- **Only one bind may claim a global shortcut.** Two would open and close the
  same popup on one press. Super+Space is the XKB layout toggle on this
  machine (`grp:win_space_toggle`), which is why the launcher is Super+R.

### Testing

- **The `Window*Test` tests open a window**: a kitty they switch between
  modes through hyprctl (`tests/WindowDriver.qml`), so `tools/test.sh` runs
  with a nested instance's `HYPRLAND_INSTANCE_SIGNATURE` and
  `WAYLAND_DISPLAY`, its config loading the branch's `windows.so` (built to
  a scratch path, never over the installed one). A drag by the title bar
  needs a pointer button, which QML cannot press: that is a
  wlr-virtual-pointer client on the nested socket (below).
  `BackdropProbeTest` needs a second screen and a saved wallpaper, and in a
  nested instance with one screen never finishes.
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
- **The shell's hot reload misses a file replaced rather than rewritten**:
  `sed -i` gives it a new inode, and the watch on it is gone. Nor does
  writing identical bytes reload. A real change to another loaded file
  reloads the whole tree, the missed file with it.
- **A new module directory is not picked up by a hot reload**: the reload
  fails (`SwitcherWindow is not a type`) and the shell keeps the config it
  had. `systemctl --user restart quickshell`.
- **Hyprland fades a layer surface in as it maps** (`fadeLayersIn`, about
  180 ms here) unless a layer rule gives it `no_anim`. A shell surface that
  draws its own fade — the popups', the switcher's — needs the rule, or the
  two stack.
- **A nested session is where tests and live checks go**, not the user's
  desktop: a nested Hyprland on a hidden special workspace with headless
  screens of its own (above), its sockets in the environment of `qs -p` (a
  copy of the tree with a `shell.qml` holding only the popups under test, in
  an `OverlaySurface`, and
  an `IpcHandler` to drive them) and of `grim -o <screen>`. Leave out the date
  menu, whose notification centre would take the session's notification bus
  name from the real shell, and the settings panel, whose `Fonts` writes the
  machine's GTK font. Captures there are about 40–85 ms apart; a hand-off's
  one frame is told from them by how much of the old card's place differs
  from a capture of the bare screen.
- **`hyprctl -i <nested> reload` can lose a nested Hyprland's window**: its
  output went to FALLBACK and the host listed it no more. Restart it instead.
- **Keys can be typed into a nested Hyprland alone** through the
  virtual-keyboard protocol, so a bind is tested without the session's input:
  a small client (`wayland-scanner` over Hyprland's
  `protocols/virtual-keyboard-unstable-v1.xml`, an xkb keymap handed over in
  a memfd) sending evdev codes to the nested socket, and Mod1 with
  `modifiers` after Alt's key, which binds then see as ALT. To have a shell
  answer them, run `qs -p` on a copy of the tree whose `shell.qml` holds only
  what is under test, with the nested instance's `HYPRLAND_INSTANCE_SIGNATURE`
  and `WAYLAND_DISPLAY`: never the whole shell, whose `Fonts` and `Wallpaper`
  write the machine's own settings.
- **The pointer too, but not with `movecursor`.** `hyprctl -i <nested>
  dispatch movecursor` moves a nested Hyprland's cursor and tells no client:
  Qt hears no motion and no hover changes, as in the session. A client of
  wlr-virtual-pointer on the nested socket does it: `motion_absolute` (in an
  extent of the screen's size) then `frame`, from one connection kept open,
  so a path is a stream of moves. Hyprland's header
  `protocols/wlr-virtual-pointer-unstable-v1.hpp` gives the requests' order
  (motion, motion_absolute, button, axis, frame, …), which is all an XML for
  `wayland-scanner` needs.
- **After an NVIDIA driver update nothing new gets the GPU until a reboot.**
  pacman replaces the libraries while the old kernel module stays loaded
  (`nvidia-smi`: "Driver/library version mismatch"): a nested Hyprland
  asserts in `CHyprOpenGLImpl`'s constructor, before any plugin loads, and a
  Quickshell started then falls back to shared-memory buffers (no dock
  previews' dmabufs). What was running keeps working. Check `nvidia-smi`
  before blaming a plugin.
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
with `--if-stale` at every login, which compares what the plugin was built
from (`built-for`, written beside it: the Hyprland and a hash of the patches)
with what is installed and checked out, and only on a difference rebuilds,
loads the result into the running Hyprland (unless one is loaded — a patch
change then takes effect at the next login — or the binary was replaced on
disk, see *Testing*) and sends a notification. install.sh runs the same
check, so a patch changed after the plugin was built is not missed. Its output is in `journalctl --user -t hyprexpo`.
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

### The window plugin

`hypr/windows` is the project's own plugin for how windows behave: the title
bars (`TitleBar`), where a window opens (`Placement`) and how windows stack
(`Stacking`). `main.cpp` wires them to Hyprland's event bus. `tools/build-windows-plugin.sh` builds it from the
checkout (no clone, no patches) into `~/.local/share/hypr-windows`, with the
overview's `--if-stale` stamp and login hook; its log is
`journalctl --user -t hypr-windows`.

**Unloading must leave no bar behind.** A plugin's decorations are destroyed
with their window, through a vtable into the plugin: one that outlives
`dlclose` takes the compositor down when its window goes (measured: SIGILL,
then SIGSEGV, in a nested Hyprland). Hyprland removes a plugin's decorations
after `PLUGIN_EXIT`, but only from the windows it still lists, and from a
closing or hidden one only queues the removal (`updateWindowDecos` skips it),
while a closed window can stay alive in the last frame's render pass. So the
plugin keeps a weak reference to every window it gave a bar and strips the
bars itself in `PLUGIN_EXIT`. A plugin loaded with `hyprctl plugin load` is not
unloaded by a config reload that drops its line, so changing the `.so`'s path
in a running session loads the new one beside it.

#### Title bars

The decoration is the project's own, not upstream `hyprbars`. It takes
hyprbars' approach — an `IHyprWindowDecoration` drawn in Hyprland's render
pass — but hyprbars reserves space on every window, takes clicks by cancelling
them on the event bus, and knows nothing of client-side decorations.

**Who gets one**: every window but one whose client said it draws its own
frame. Hyprland answers every xdg-decoration request with server-side mode, so
the answer tells nothing; the request does. Chromium and Electron windows that
draw their own controls ask for client-side mode (VS Code, Claude: no bar); Qt,
and kitty with decorations (`terminal/kitty.conf`; `hide_window_decorations
yes` asks for client-side), ask for server-side (a bar). GTK never makes the
object and gets one too: its header bars carry no window buttons on this
desktop (`button-layout=':'`, `profile/gtk.dconf`), so the bar is where they
are. An X11 window cannot say — Hyprland does not read `_MOTIF_WM_HINTS`, and
reading it would be a round trip to Xwayland from the compositor's thread — so
every X11 application window gets one (`_NET_WM_WINDOW_TYPE` normal, dialog or
none; not a menu, a tooltip or a splash), and one that draws its own frame as
well is the user's to hide. The protocol keeps the objects private:
`CTitleBar::wanted` reads them through an explicit instantiation rather than
`#define private public`, and maps each key back with the public
`fromResource`, since the toplevel's own resource is private too. Decided when
the window maps.

**Hidden per application.** The dock's menu offers *Hide Title Bar* (then
*Show Title Bar*) on an application whose windows have one; the choice is
`Settings.hiddenTitleBars`, by app id. `TitleBars` hands the list to the
plugin with the `windows:hidden_for` dispatcher, comma-separated, whenever it
changes and after every config reload (loading the plugin raises one), and the
plugin places every bar again. A dispatcher, not an option: `hyprctl keyword`
tells no plugin its option changed, and a bar hidden above a floating window
kept the 28 px it had reserved, which the window's shadow — solid over the
window's box with its decorations — filled as a dark band. A hidden bar is
kept, not removed, so it can come back while the window is open. Whether a
window has one only the plugin knows, so the menu asks as it opens:
`hyprctl decorations` lists `TitleBar` (`TitleBars.byWindow`).

**Where it is.** Floating, a STICKY top decoration that reserves its 28 px,
drawn on the UNDER layer as part of the window (the shadow takes it in): the
window's rounding at the top, and the two corners under it filled so that the
window's own rounding leaves no notch. Tiled, STICKY on all four edges with
nothing reserved — its box is the window's — so the window keeps its whole
tile, and the bar is drawn on the OVERLAY layer over its top only once the
pointer has rested at the window's top edge — its top 4 px, or the gap above
them — for `t.reveal` (half a tooltip's dwell), as macOS's menu bar comes out
over a full-screen window. Never on the rest of the 28 px: that is the
application's, and a browser's tabs are there (a bar that came out wherever
it would be took the tab the pointer rested on). A pointer on its way past —
up to the shell's bar, over a window that fills the screen — brings nothing
out; the bar stays while the pointer is on it or that edge and for the
linger after (`Pointer.cpp`). Fullscreen, the
same, a floating window's bar included: it moves over the window while it is
fullscreen. **Hyprland draws no decoration at all on a fullscreen window** —
`renderWindow` is told not to decorate it, overlay layer included — and with
nothing over it draws that window alone (the solitary client), or hands its
buffer straight to the screen (direct scanout) with no render pass. So while
its bar is out the plugin clears the monitor's solitary client in
`render.preChecks`, which runs after Hyprland settles it and before scanout is
tried, and paints the bar at `RENDER_LAST_MOMENT`, a stage every frame reaches.
`window.floating` and `window.fullscreen` move it between above and over (a
dragged tile is floated by the same call); only a float keeps the window on
screen, since one leaving fullscreen is still on its way to its own box. A window
Hyprland places floating is moved down, and shortened if it must be, until its
bar is in the work area: `newTarget` centres a window by its own box, and one
floated from a full-height tile had its bar off the screen. One dragged there
stays there.

**Input.** Clicks come through `onInputOnDeco`, which Hyprland calls after the
binds and before the client, so a `bindn` (the popups' dismissal) still sees
the click and a mouse bind (Super+drag) still wins; cancelling
`input.mouse.button` on the bus, as hyprbars does, takes it before either.
The bar's box over a tiled window is the whole window, so it claims
`DECORATION_ALLOWS_MOUSE_INPUT` only while shown. A button acts on release
over the button it was pressed on; a press on the background becomes a move
once the pointer moves (`beginDragTarget`, as a mouse bind starts one), which
for a tile is Hyprland's own tile drag. A maximized or fullscreen floating
window is taken out of that mode first, at the size Hyprland kept as it
maximized it, with the pointer where it took the bar, along it and down it
(`restoreUnder`): Hyprland's own drag restored it centred on the pointer,
its bar above the screen. Hover is the one listener on
`input.mouse.move`, and it skips an event another plugin cancelled — the
overview takes the pointer while it is open — so the title bars' `plugin =`
line comes after the overview's. No bar newly takes the pointer while a
button is held (counted from `input.mouse.button`, never cancelled): a
selection dragged up to a tile's edge would otherwise bring a bar over it
that took its release.

**The buttons**: close (`Config::Actions::closeWindow`), minimize
(`movetoworkspacesilent special:minimized`), zoom (`fullscreenWindow` with
`FSMODE_MAXIMIZED`, the toggle `fullscreen 1` is; a maximized window keeps its
bar) and layout (`floatWindow`, the toggle `togglefloating` is; Placement
places and remembers it as for any float or tile). Grey in a window without
focus, coloured with their glyphs under the pointer. The glyphs are drawn with
Cairo into a texture of the button's own box: a cross, a bar, a plus, and for
layout two rounded panes on a floating window, one on a tiled one. Characters
set in a face sat on their baseline and came out off centre. `Compositor.focusWindow`, which the dock goes through, brings a
minimized window back to the focused workspace before focusing it; focusing it
where it is would show the whole special workspace.

**Colours.** A bar takes its application's colour (`AppColor`): a row 2 px
inside the window's top edge, across the middle four fifths, read from the
buffer while a frame is drawn (the context is current and the buffer the
frame shows is ready) — a texture attached to a framebuffer and
`glReadPixels`, with the swizzle Hyprland gives a shared-memory format applied
by hand, since a read skips it. Only a colour three quarters of the row agree
on counts; a picture, a gradient, something translucent or a buffer that
cannot be read (external, turned) leaves the system's, `bar_color`
(`c.surface`). Each read waits on the GPU, so a window is read again only
after it commits, and at most every 250 ms, the last commit of a burst
included — except while it opens (`m_animatingIn`, until its opening
animation ends): then every commit is read and the colour taken at once, so a
new window's bar comes in with it in its own colour, never the system's first. What is drawn on a bar is the scheme of its lightness — on a light
bar `light_*`, the day theme's, on a dark one `dark_*`, the night's: the
title in `text`, the buttons in `danger`, `warning`, `success` and `accent`,
their glyphs in `surface` — all pushed by `CompositorTheme`, so a dark
terminal's bar is dark with the night theme's buttons under the light theme.
The title is set in fontconfig's sans-serif, which `Fonts` points at the
chosen family. The `decorate = off` window rule leaves one window without a
bar.

**Animations** are the shell's: a bar coming out or going, focus and a new
colour ease over `fade_duration` (`t.fast`), the buttons lighting under the
pointer over `hover_duration` (`t.instant`, `Clickable`'s wash), all on
`curve` — `t.standardCurve`, `standardEasing` as a CSS `cubic-bezier()`,
registered with Hyprland's animation manager as `windowsStandard` and again
after a reload, which drops it. On or off with Hyprland's `fade`, and with
`animations:enabled`, the shell's *Animations* setting. A bar going above
its window or leaving it — the window floating or tiled, in or out of
fullscreen, its bar shown or hidden — rolls out of the window's top edge and
back into it as a popup's door does: out over `roll_out_duration`
(`t.popupMove`) on `roll_curve` (`t.emphasizedCurve`, registered as
`windowsEmphasized`), in over `roll_in_duration` (`t.popupFade`) on `curve`.
Never over the window: it used to move there at once and fade out over the
application's top, and fade in above it from nothing. It is laid out on a
whole bar from its upper edge and cut to as much as is out, so its far side
shows first; rolled out less than its rounding, its corners meet the
window's own, one rounded shape all the way. The room it holds above the
window follows it frame by frame (`reposition` from the roll's update), so
the window's shadow is under the bar and nowhere else (see the Hyprland
gotchas), and is reserved only once the bar is all the way out: a roll never
resizes a tile or a maximized window. Over a maximized window the bar does
not roll: the room is taken from the window, so it is all there or none at
once, and the window is laid out again with it (`reposition`, see the
Hyprland gotchas) — maximized from fullscreen, it used to keep the whole
height with its bar off the top. Not from `getPositioningInfo`: a roll
started there places the bar again while the positioner is placing it. Only
a new window's bar is at once what it is, since the window's own fade brings
it in. One that is away takes a new colour at once.

**Limitations**, each because the way round it is worse:

- An X11 window that draws its own frame (Steam, JetBrains IDEs, GTK on X11)
  has two until the user hides one, for the reason above.
- A GTK header bar keeps its title, so a GTK window that shows one shows it
  twice.
- The request is read when the window maps; a client that changes its mode
  later keeps what it had.
- Under a tiled window's bar the client keeps pointer focus: it shows its
  hover effects and sets its cursor (a text cursor over a terminal's bar).
  Taking focus there would mean cancelling pointer motion, which also skips
  focus-follows-mouse. Clicks are the bar's.
- The corners filled under a floating bar show through a window drawn
  translucent (`inactive_opacity` below 1).
- The title turns light or dark when the bar's colour sets off, not partway:
  it is a texture of one colour.

Verified in a nested Hyprland with kitty, dolphin (Qt), VS Code (Electron) and
GNOME Calculator (GTK): who gets a bar; floating, tiled (no size change while
it shows), maximized and fullscreen; each button; dragging a floating window,
and a tile into the other half; floating ↔ tiled both ways; colours pushed
with no pointer motion; the held-button selection; unload and reload; the
overview loaded first, with nothing of a hidden bar in its tiles. In the
session: the theme toggle redraws the bars, and Quickshell's model names a
window moved to `special:minimized` by that workspace. Since every window
gets one (nested): GNOME Text Editor (GTK, no object) and kitty asking
server-side with a bar, kitty asking client-side without, GNOME Calculator
under `GDK_BACKEND=x11` with one; `windows:hidden_for` hiding and showing the
bars of two applications and not a third's, the reserved room going and
coming back, an empty list over the socket clearing it.

Since the application's colour (nested, frame by frame and zoomed): a new
kitty's bar dark from its first frame; the glyphs centred; a maximized
window's bar rounded; over a fullscreen window nothing at 120 ms and the bar
after the reveal; floating ↔ fullscreen, ↔ maximized and tiled ↔ fullscreen
each back to the same box.

Since the roll (nested, with Zen, frame by frame at the shell's timings and
slowed tenfold): tiled → floating by the bar's layout button and by a
dispatch, the bar out of the window's top edge with the buttons coming in
from above and the shadow under the bar alone; floating → tiled, back in and
never over the page; hidden and shown from the dispatcher with the window's
box unchanged; maximized keeping its bar, fullscreen with none and back to
the same box; the bar revealed over a tiled window; the window closed, and
the plugin unloaded and loaded again, mid-roll.

#### Placement

**Floating by default** is a window rule, not code: `float-by-default`, first
in `hypr/conf.d/80-window-rules.conf`, so any later rule overrides it. It has
to be a rule. Hyprland sends a new Wayland window its predicted *tiled* size
in the first configure unless a float rule already applies
(`CWindow::commitWindow`), so a window floated any later had drawn its first
buffer at a tile's size, and that was all its "own" size ever was.

**The rest is the plugin**, at `window.openEarly`: after Hyprland has read
the rules, before the layout places the window. A window it manages is one
the default rule matches, with an app id, no parent, not fixed-size or a
dialog (`shouldBeFloated`), not asking for fullscreen, and no other matching
rule (exec rules included, `exec [float; size …] app`) with a `float`, `tile`,
`size`, `move`, `center`, `fullscreen`, `fullscreenstate` or `maximize`
effect — told apart from the default by its name. For one, it sets what a
`size` and a `move` rule would: `m_isFloating` false if the app was last left
tiled, or else `static_.size` and `static_.position`, which the floating
algorithm reads on the first map. So Hyprland places the window itself,
animation and all; nothing moves it after it maps.

**The size**: the one the app was last left at, floating and not maximized or
fullscreen; else its own (the first commit's geometry), cut down to 70% × 80%
of the work area, the title bar counting towards the height; else, if it asks
for none, that share. Measured on this desktop: Nautilus asks 957×518,
Dolphin 760×620, Text Editor 954×622, Calculator 360×616, pavucontrol
500×400, all kept; kitty and apps that saved a tiled size ask for the whole
screen, and get the cap. Centred in the work area with its bar. The space's
work area is a cache refreshed on Hyprland's schedule (a first window after
an output change was placed by the old one), so it is rechecked first. A
window the user floats from a tile gets the same box, rather than Hyprland's
pick from the tile; the float a dragged tile goes through is the drag's.
Placed through the floating layout (`setTargetGeom`), which keeps the box,
so maximize and fullscreen give it back (see the Hyprland gotchas); and so
is a window `keepOnScreen` moves.

**Floating ↔ tiled leaves maximize and fullscreen.** Hyprland's toggle puts
the mode back afterwards: a maximized window tiled stayed maximized, and
floated again came back maximized rather than at its own size. The
`window.floating` listener (outside a drag) sets the mode to none before
Placement places it. Minimized and restored, a window keeps its mode.

**Remembered**, by app id, in `~/.local/state/hypr-windows/remembered` (one
line each: floating, width, height, id; written whole through a rename):
when a window closes, when it is floated or tiled (outside a drag, whose drop
re-tiles it), and for every window at `exit`, since a logout may close none.
A window just tiled has no floating size of its own any more: the one it had
is its layout target's `lastFloatingSize`, taken as it tiles (not as a
dropped tile re-tiles, whose was the drag's) — before, a window resized,
tiled and floated again came back at the size it first opened at. Machine
state, so not in `profile/`.

**Limits**: the position is not remembered — every window opens centred, two
of one app on top of each other. Windows of one app share one memory, the
last closed wins. A remembered size reaches the app after it maps, as a
`size` rule's does: its first frame is the size it asked for.

Verified in a nested Hyprland with its own `XDG_STATE_HOME`: kitty (with a
size asked of it), Nautilus, Calculator, Text Editor under a `size` rule:
first launch at their own size or the cap, centred; resized, closed, and
reopened at that size, after a restart too; tiled and reopened tiled;
floated again at the remembered size; a bad entry (a 0 height) falls back to
the default; the ruled window neither placed nor remembered; unload with a
closed, barred window still held, then that window freed.

#### Stacking

**Hyprland draws every tiled window below every floating one**
(`renderWorkspaceWindows`: a tiled pass, then a floating one) and its hit
test offers the pointer to a floating window first — asked without
`ALLOW_FLOATING` too, after its fullscreen check. Yet it raises whatever is
clicked, tiled or floating, in its window list (`processMouseDownNormal`),
and `Compositor.focusWindow` raises with `alterzorder top`: the order is
kept and only drawing and hitting ignore it. `Stacking` hooks both, found by
name as the overview's patch finds `renderLayer`. The draw hook calls
Hyprland's own whenever no tiled window it would draw is above a floating
one, and otherwise draws in the list's order, each run of tiled windows as
the tiled pass does (the focused one last, the closing tiled windows after
the first run, the focused one's popups) and each floating window whole.
The hit test hook looks above the floating window Hyprland found for a
tiled window on its workspace whose box (`getWindowBoxUnified`, as a
floating one is hit) or popup is at the point. A workspace with a
fullscreen or maximized window is Hyprland's: it draws those with
`renderWorkspaceWindowsFullscreen`. Both hooks or neither: drawn one way and
hit the other, a covered window would take the clicks. A Hyprland where one
is not found gets a notification and its own order.

Verified in a nested Hyprland with a wlr-virtual-pointer client clicking and
hovering, focus read with `hyprctl activewindow`: a floating window over a
tiled one covered by a click on the tiled one (the pixel there turns the
tiled window's colour) and hovering where it lies beneath focusing the tiled
one; brought back by the dock's `focuswindow` + `alterzorder top` and by a
click on what shows of it; one straddling two tiles covered by the clicked
tile only; hover raising nothing; a maximized window left to Hyprland;
unload with a tiled window raised, Hyprland's order back.
