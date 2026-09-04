# Shell

A desktop shell for Wayland / Hyprland, written in QML against
[Quickshell](https://quickshell.outfoxxed.me) 0.3 and Qt 6.11.

GNOME's interaction model — a top bar, a quick-settings panel, an activities
overview, a searchable app grid — with a warm, opaque, minimal visual language:
no blur, no translucency, no decorative chrome.

## Running it

```sh
mkdir -p ~/.config/quickshell
ln -sfn ~/quickshellProjects ~/.config/quickshell/shell
./tools/build-overview-plugin.sh     # the workspace overview; see below
qs -c shell
```

Then add `source = ~/quickshellProjects/hyprland.conf` to your `hyprland.conf`
for autostart, the overview plugin and keybindings.

The shell is the session's notification daemon, so any other one must go:

```sh
systemctl --user mask dunst.service     # or whichever you were using
pkill dunst
```

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
  panels/                 quick settings, date menu, tray menu
    qs/                     quick-settings sub-pages
  launcher/               application launcher
  notifications/          toasts and the notification centre
  osd/                    volume / brightness indicator
  lock/                   session lock
  common/                 shared surface chrome and the IPC surface
tools/                    generators and the lint wrapper (not loaded at runtime)
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
| `Keyboard` | Hyprland `activelayout` events | indicator hidden |
| `Dock` | `Compositor` + `Settings` | pinned entries only |
| `Session`, `Settings`, `Time`, `Osd`, `Overlay`, `InputMode` | — | — |

Two of these deserve a note:

- **`Overlay`** is the arbiter for full-screen surfaces. The launcher, overview,
  quick settings, date menu and the two popup menus all route their open/close
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
that matches the installed Hyprland. **Re-run it after every Hyprland update** —
Hyprland refuses to load a plugin built against different headers.

Its layout and gestures live in `hyprland.conf`; its three colours are pushed by
the shell (`modules/common/OverviewTheme.qml`) so the overview follows the theme.

### Event-driven, not polled

There is exactly one periodic timer in normal operation: `SystemClock` at
minute precision, shared by every monitor. Everything else is push-driven —
PipeWire and NetworkManager signals, the Hyprland event socket, inotify on the
settings file and the backlight.

Two bounded exceptions, both deliberate:

- The media seek bar polls MPRIS position once a second, and only while the date
  menu is open and something is actually playing. MPRIS does not signal position.
- Wi-Fi scanning and Bluetooth discovery run only while their page is on screen.

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
application collapses to one launcher icon only while it has no windows open.

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
