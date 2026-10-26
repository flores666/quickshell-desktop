# Shell

A desktop shell for Wayland / Hyprland, written in QML against
[Quickshell](https://quickshell.outfoxxed.me) 0.3 and Qt 6.12.

GNOME's interaction model — a top bar, a quick-settings panel, an activities
overview, a searchable app grid — drawn as glass: capsule chrome, and panels
of the theme's surface over a blur Hyprland draws behind them, with no
decoration beyond that.

## Running it

```sh
./install.sh
```

On a fresh Arch install that is all it takes to get this desktop. It installs
what `packages.txt` and `packages-aur.txt` list, enables the services the shell
reads (Bluetooth, power profiles, NetworkManager where nothing else runs the
network), masks any other notification daemon (the shell is one), makes fish
the login shell, links this checkout as the Quickshell config `shell`, builds
the overview plugin if it is not there yet (see below), and puts the configs in
place:

| What | Where it goes |
| --- | --- |
| `hypr/` — Hyprland and hyprpaper | `~/.config/hypr/hyprland.conf` sources it; `hyprpaper.conf` is linked |
| `terminal/kitty.conf` | `~/.config/kitty/kitty.conf` includes it |
| `terminal/prompt.fish` | linked into `~/.config/fish/conf.d` |
| `nvim/` | linked as `~/.config/nvim` |
| `bin/` | each script linked into `~/.local/bin` |
| `profile/` | GTK settings applied where still at their defaults, and the shell starts from `settings.json` |

The configs are links into the project, so editing one edits the project.
What is not a file — the shell's preferences and the GTK settings — is saved
with `tools/save-profile.sh`; run it and commit `profile/` to take them to the
next machine. The wallpapers are not in the repository: put the pictures into
the Pictures folder's `Wallpapers` yourself, and the saved choice, kept by file
name, comes back once one of that name is there. Anything `install.sh` has to replace is kept as
`<name>.bak-<date>`, and it is safe to re-run. Then log in again, or start the
shell with `qs -c shell`.

Only the desktop is in the project, not one computer or one person's things.
Screens are detected — each at its highest resolution and that resolution's
highest refresh rate, placed and scaled automatically — and the shell finds
the touchpad, the battery, the backlight and the Bluetooth adapter where there
are any. A machine that wants more, say one monitor above another, puts it in
its own `~/.config/hypr/hyprland.conf` after the line that sources the project.
The saved dock keeps only applications the project installs, and a login
manager is left to each machine.

## What is where

```
shell.qml                 entry point: instantiates per-monitor chrome and the
                          single-instance overlays
config/                   the design system — colours, spacing, radii, metrics,
                          motion, type. Nothing outside this directory hardcodes
                          a colour or a magic pixel value.
services/                 one singleton per source of system state; the only
                          place the rest of the shell reads the world from
components/               reusable widgets built on one interaction primitive
modules/                  the surfaces themselves
  bar/                    top panel
  dock/                   bottom dock
  panels/                 quick settings, date menu, tray menu, VPN menu
    qs/                     quick-settings sub-pages
  launcher/               application launcher
  tasks/                  task manager: processes; CPU, GPU, RAM (with
                          earlyoom), disks and network; scheduled tasks
  notifications/          toasts and the notification centre
  osd/                    volume / brightness indicator
  lock/                   session lock
  common/                 shared surface chrome and the IPC surface
tools/                    generators, the lint wrapper, save-profile.sh (not
                          loaded at runtime)
install.sh                sets a computer up as this desktop
packages.txt              the packages it needs (packages-aur.txt: the AUR ones)
hypr/                     the Hyprland and hyprpaper config
terminal/                 kitty, and the fish prompt
nvim/                     neovim
earlyoom/                 earlyoom's options, as install.sh first puts them
systemd/                  the user unit the task manager's login tasks hang from
applications/             the task manager's launcher entry
bin/                      the scripts the configs run
profile/                  saved preferences and GTK settings
```

### Services

Each service is a `pragma Singleton` that owns exactly one area of system state
and exposes it as plain, already-derived properties. UI code never talks to
D-Bus, PipeWire or Hyprland directly, and never duplicates a derivation.

| Service | Backed by | Degrades to |
| --- | --- | --- |
| `Audio` | PipeWire registry | `hasSink`/`hasSource` false; controls hidden |
| `Network` | NetworkManager | `available` false; "Offline" |
| `Bt` | BlueZ | `available` false; every control hidden |
| `Power` | UPower + power-profiles-daemon | no battery row, no profile control |
| `Brightness` | `/sys/class/backlight` | `available` false; slider hidden |
| `Players` | MPRIS | `hasPlayer` false; media UI hidden |
| `Notifs` | the notification server | empty history |
| `Apps` | XDG desktop entries | empty index |
| `Compositor` | Hyprland IPC | empty workspace and window lists |
| `Wallpaper` | `~/Pictures/Wallpapers` + hyprpaper IPC | no pictures, and the strip says where they go |
| `Fonts` | Qt's font database | the shell's own family, alone |
| `Keyboard` | Hyprland `activelayout` events | indicator hidden |
| `Vpn` | `nmcli monitor` (the profiles `vpnConnections` names) | no rows; VPN button hidden without v2rayN either |
| `V2rayn` | v2rayN's config and database; in TUN mode its core's Clash API | no row; without TUN mode, no switch |
| `Dock` | `Compositor` + `Settings` | pinned entries only |
| `Processes` | `/proc`, read while the task manager shows it | — |
| `EarlyOom` | its unit file, `/etc/default/earlyoom`, its journal | `available` false; memory gauges only |
| `Tasks` | systemd user timers and the user journal | no tasks |
| `Session`, `Settings`, `Time`, `Osd`, `Overlay`, `InputMode` | — | — |

Two of these deserve a note:

- **`Overlay`** is the arbiter for full-screen surfaces. The launcher, overview,
  quick settings, date menu, task manager, VPN menu and the two popup menus all route their open/close
  through it, which is what makes "only one at a time" true by construction
  rather than by everyone remembering to close everyone else.
- **`Settings`** is the only writable state, persisted as JSON under
  `~/.local/state/quickshell/by-shell/<id>/settings.json`.

### The workspace overview

The overview is the **hyprexpo** compositor plugin, not a shell surface. Only the
compositor can render live workspace contents; a layer surface can only draw a
schematic. `Compositor.toggleOverview()` dispatches to it, so the dock button,
the `overview` IPC action and `Super+Tab` all reach the same thing — and
`Super+Tab` is bound straight to the dispatcher, so it works even with the shell
stopped.

hyprexpo was dropped from the official hyprland-plugins repo as unmaintained, so
`tools/build-overview-plugin.sh` builds the maintained
[sandwichfarm fork](https://github.com/sandwichfarm/hyprexpo), picking the tag
that matches the installed Hyprland. Hyprland refuses to load a plugin built
against different headers, so `hyprland.conf` runs it with `--if-stale` at every
login: after a Hyprland update, or a change to its patches, it rebuilds the
plugin in the background, loads it and sends a notification, and otherwise
does nothing.

Its layout and gestures live in `hyprland.conf`; its three colours are pushed by
the shell (`modules/common/CompositorTheme.qml`) so the overview follows the theme.

### Events only, never polled

Nothing in the project asks on a schedule whether something has changed —
not the shell, the compositor plugins, the scripts or the tests. Everything is
push-driven: PipeWire and NetworkManager signals, the Hyprland event socket,
`nmcli`/`gdbus`/`ip monitor`, inotify on the settings file and the backlight,
`waitpid` on a process ending.

Where nothing reports a change, it is measured on the events it matters at:

- The VPN menu's latencies are measured as the menu opens and as a connection
  comes up; v2rayN also as its settings or core change, and as its core ends.
- The Wi-Fi list asks for one scan as it opens; what turns up comes as
  NetworkManager's events. Bluetooth discovery runs only while its page is on
  screen, and its devices arrive as BlueZ's events.

The only periodic wakeups are clocks showing time passing, which no event can
say: the `Time` service's minute, shared by every monitor, and the media seek
bar's second while the date menu shows something playing (MPRIS does not
signal position; Quickshell works it out, so the tick asks the player nothing).
And one reading: the task manager's process list and memory gauges, read from
`/proc` every two seconds while one of them is on screen, since the kernel
says nothing when a process works or memory fills; a CPU share is the change
between two readings. Its scheduled tasks are systemd's to wait for, and their
runs are heard from the journal.

Two things are asked for once at startup because no event carries them until
they change: the backlight device, and the current keyboard layout.

Measured idle CPU with the shell running and nothing happening: **0.00%**.

### Icons

UI glyphs are vector path data lifted from the Adwaita symbolic icon theme by
`tools/genicons.py` into `components/Icons.qml`, and drawn with QtQuick.Shapes.
They take their colour from the design system, stay crisp at any size, and cost
no image loading or colourising shader. Application icons still come from the
XDG icon theme at runtime.

To change the icon set, edit the map at the top of `tools/genicons.py` and re-run
it.

## Colours

`config/` holds the whole palette. Two seeds are user-settable from quick
settings (the chevron on the *Dark Style* tile): the **accent**, and the
**background** the neutral family is built from — the latter per theme, so light
and dark keep their own.

When a seed is unset the hand-tuned tokens are used verbatim, so the default
appearance is exactly what it was. When one is set, the rest of the family is
derived from it by the same lightness steps that separate the tuned values, and
the accent's text colour is picked for contrast. Changes apply live and persist
in `settings.json`, which also accepts any hex value the swatches do not offer.

This only ever affects the shell. Nothing here touches GTK, Qt or system themes.

## Settings

One tab per thing that can be configured, and each thing configured in exactly
one tab: the dock's hide delay is under *Dock* rather than filed with the other
timings, and the border and corner radius every surface is drawn with are under
*Appearance* rather than under the panel that happened to need them first.

*Appearance* also holds the type: any installed family, and one **text size**
that scales the whole ramp together the way roundness scales the whole set of
radii. *Wallpaper* is a strip of the pictures in `~/Pictures/Wallpapers` that
scrolls sideways under the wheel; picking one drives hyprpaper over IPC and
remembers the choice, which is what puts it back at the next login — hyprpaper
itself forgets an IPC change when it restarts.

## The dock

The dock floats and auto-hides: it declares no exclusive zone, so a maximized
window gets the full height of the screen. It slides away when the pointer
leaves and slides back when the pointer reaches the bottom edge in the dock's
own width — the trigger is a 3px invisible strip that grows to meet the dock
while it is out, so crossing between the two never drops the hover and starts a
hide. Its window is wider and taller than the dock to give hover tooltips
somewhere to live, and input is masked to the dock plus that strip, so every
pixel around it stays click-through.

Each open window gets its own icon — three terminals are three icons, each
activating its own window and carrying its own focused state. A pinned
application collapses to one launcher icon only while it has no windows open,
and one that is not installed on this machine is not shown.

## The task manager

`Ctrl+Shift+Esc`, or *Task Manager* in the launcher. **Processes** lists every
process with its CPU, memory, disk I/O and PID; your own can be ended from a
row's menu, and any can be protected from earlyoom or marked to go first.
**CPU**, **GPU** (where one reports how busy it is), **RAM**, **Disks** and
**Network** each show what the thing is, a chart of its last minute, and the
five processes that use it most: by CPU, GPU time and disk I/O over that
minute, by memory held and connections open now. Under RAM, earlyoom: the
memory and swap left against the levels it acts at, its options — applied
together, through a password prompt, since they are root's — and what it has
stopped.
**Schedule** runs commands on systemd user timers — once, hourly, daily,
weekly, by any calendar expression, or at login — and shows how each last run
went.

[earlyoom](https://github.com/rfjakob/earlyoom) stops the process using the
most memory before the machine runs out. `install.sh` installs it with the
project's options (`earlyoom/earlyoom`) and enables it; every process it stops
comes up as a notification.

## Interaction

Every interactive element implements hover, pressed, selected, disabled and
keyboard-focus states once, in `components/Clickable.qml`. Focus rings follow the
`:focus-visible` rule — they appear during keyboard navigation and not on click,
tracked by the `InputMode` service.

- `Esc` closes any open popup.
- Clicking outside a popup closes it, and that click still reaches whatever is
  under it. See below.
- Opening any popup closes whatever else was open.

### Popups never capture the pointer

Each popup's window is exactly the size of its card — there is no full-screen
catcher anywhere in the shell. While a popup is open the rest of the desktop is
completely live: hover works, clicks land where they are aimed.

Dismissal comes from Hyprland's **non-consuming** binds (`bindn`, in
hyprland.conf) for both the pointer and Escape: they report the press without
swallowing it, so the application still gets it. `Overlay` then
closes the popup unless the pointer is over one of the shell's own surfaces —
tracked as continuously-maintained hover state, not event ordering, which is
also what lets a bar button toggle its own panel shut instead of reopening it.

Two mechanisms were tried and rejected: a full-screen catcher eats the click,
and `HyprlandFocusGrab` both eats the click and stops clearing entirely once the
surface takes keyboard focus. For the same reason popups ask for **on-demand**
keyboard focus rather than exclusive — an exclusive layer surface in Hyprland
takes the pointer along with the keyboard.

## The terminal

`terminal/` gives kitty and fish the *Soft Surface* look: a deep blue-black
ground with a periwinkle accent, no title bar, roomy padding and line height,
and a prompt of rounded pills — the working directory, the git branch, and the
last command's status only when it failed — with a blank line above each one.

`terminal/kitty.conf` is the whole kitty config — the font, the keys, the
look. Your own `kitty.conf` only includes it, then `font-size.conf`, where
`bin/kitty-font-size` keeps the size Ctrl+=/Ctrl+- set for that machine (a
machine starts at the project's 13 pt); anything you add after the include wins
over the project. The prompt is fish's, so fish is made the login shell; its
syntax colours are fish's default theme, drawn in the terminal's palette.

The colours are written once, in `terminal/palette.conf`: kitty takes them
through `kitty-colors.py` (a `geninclude`), and the prompt and neovim
(`nvim/init.lua`, on the terminal's own background) read the file themselves.
The terminal keeps its own colours rather than following the shell's theme and
accent.

## Development

```sh
./tools/lint.sh          # qmllint over the whole tree
python3 tools/genicons.py  # regenerate the icon set
qs -c shell              # run it; edits reload live
```

`tools/lint.sh` copies the tree to a scratch directory first, rewriting
Quickshell's `root:/` imports to relative paths and synthesising the `qmldir`
files qmllint needs. The source is untouched.

Remaining lint output is limited to types qmllint cannot see because Quickshell
registers them from C++ (`PanelWindow`, `GlobalShortcut`, the enum types) and to
`QObject*`-typed properties such as `Loader.item`.
