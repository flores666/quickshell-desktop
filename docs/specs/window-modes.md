# Window modes: floating, tiled, maximized, fullscreen, minimized

## Goal

Switching a window between its modes always lands it where it was last left in
that mode. Floating ↔ tiled drops maximize and fullscreen, and a window floated
again comes back at the floating size and place it had before. A maximized
window always keeps room for its title bar. Dragging a maximized or fullscreen
window by its bar restores it under the pointer. Minimize and restore keep the
mode the window had.

## Terms

- **B**: a test window's floating box as it opens (kitty, a class of its own,
  so Placement remembers nothing for it).
- **WA**: the monitor's work area, from `hyprctl monitors -j` (box minus
  `reserved`).
- **MAX**: a maximized floating window's box,
  `[WA.x, WA.y + 28, WA.w, WA.h − 28]`. 28 is the title bar's height
  (`CTitleBar::HEIGHT`).
- **layout**: the bar's floating/tiled button, the same as
  `togglefloating`. **zoom**: `fullscreen 1` (maximize). **full**:
  `fullscreen 0`. **minimize**: `movetoworkspacesilent special:minimized`.
  **restore**: what the dock does (`Compositor.focusWindow`: back to the
  workspace in front, focus, `alterzorder top`).
- `fs`: Hyprland's internal fullscreen mode (0 none, 1 maximized,
  2 fullscreen).

## Plan

### 1. Floating ↔ tiled leaves maximize and fullscreen

Hyprland's `changeFloatingMode` takes the window out of fullscreen, toggles it,
and puts the old mode back. The plugin's `window.floating` listener, outside a
drag, sets the mode to none before Placement places the window.

- floating at B → zoom → layout → `floating false`, `fs 0`.
- … → layout → `floating true`, `fs 0`, box == B.
- floating at B → zoom → minimize → restore → layout → layout →
  `floating true`, `fs 0`, box == B. (The reported sequence.)
- floating at B → full → layout → `floating false`, `fs 0`.

Files: `hypr/windows/main.cpp`.

### 2. Placement remembers the floating size a window had before it was tiled

Placement records an application's state after the toggle, when a window just
tiled no longer has a floating size. Hyprland keeps it on the layout target
(`lastFloatingSize`).

- floating at B → resized to 600×400 → layout → layout → `fs 0`,
  size == 600×400.
- floating at B → zoom → layout → layout → size == B's size (not MAX's).

Files: `hypr/windows/Placement.cpp`.

### 3. Hyprland's floating layout knows where Placement put a window

Placement (and `keepOnScreen`) set the box with `setPositionGlobal`, which
skips the floating layout's record of the box. Un-maximize and
un-fullscreen bring the window back to that record, 14 px higher.

- floating at B → layout → layout (floating at B') → zoom → zoom →
  box == B'.
- … → full → full → box == B'.

Files: `hypr/windows/Placement.cpp`, `hypr/windows/TitleBar.cpp`
(`keepOnScreen`).

### 4. A maximized floating window keeps room for its title bar

The bar's room above a floating window follows its roll, and is reserved only
once the bar is all the way out. A window maximized before then (from
fullscreen, say) is laid out without the room: full height, bar off the top.
Hyprland also never lays a maximized window out again when the room changes.
For a maximized window the bar is out or in at once, and the window is laid
out again whenever the room changes.

- floating → full → zoom → `fs 1`, box == MAX.
- floating → zoom → hide its bar (`windows:hidden_for <class>`) → box == WA.
- … → show it (`windows:hidden_for ""`) → box == MAX.

Files: `hypr/windows/TitleBar.cpp`.

### 5. A maximized or fullscreen window dragged by its bar stays under the pointer

Hyprland restores the window's size and centres it on the pointer, which put
the bar above the screen. A press on the bar of a maximized or fullscreen
floating window that becomes a drag first takes the window out of that mode,
at its floating size, placed so the pointer keeps its place along the bar
and within its height, and only then starts Hyprland's drag.

- floating at B → zoom; press on the bar at (WA.x + 0.5·WA.w, WA.y + 14),
  move to (+60, +186), release → `fs 0`, size == B's size, the bar
  `[x, y − 28, w, 28]` contains the pointer, at the same fraction along the
  bar (0.5) and the same height in it (14) as at the press.

Files: `hypr/windows/Pointer.cpp`, `hypr/windows/TitleBar.*`.

Not a `tests/*Test.qml`: a QML test cannot press a pointer button. Checked by a
script with a wlr-virtual-pointer client on the nested socket (see AGENTS.md,
*Testing*).

### 6. Minimized and restored, a window keeps its mode (guard)

Already true; kept true.

- floating → zoom → minimize → restore → `fs 1`, box == MAX.
- floating → full → minimize → restore → `fs 2`, box == the monitor's.

## Tests

`tests/WindowModesTest.qml` (items 1, 2), `tests/WindowPlaceTest.qml`
(item 3), `tests/WindowMaximizeTest.qml` (items 4, 6), all driving a kitty
through `tests/WindowDriver.qml`. They run under `tools/test.sh` inside a
nested Hyprland that has this branch's plugin loaded, never the live session:
each opens a window.

```sh
# plugin from this branch, into a scratch path (not the installed one)
g++ -shared -fPIC -O2 -std=c++2b --no-gnu-unique -Wall \
    $(pkg-config --cflags pixman-1 libdrm hyprland libinput libudev wayland-server xkbcommon) \
    hypr/windows/*.cpp -o "$SCRATCH/windows.so"
# a nested Hyprland whose config sources hypr/conf.d/50-look-and-feel.conf and
# 80-window-rules.conf and loads $SCRATCH/windows.so, then:
HYPRLAND_INSTANCE_SIGNATURE=<nested> WAYLAND_DISPLAY=<nested socket> ./tools/test.sh
```

## Independence

Items 1–5 change one plugin, built and tested as one `.so` in one nested
Hyprland, and 3 and 4 share `TitleBar.cpp`: one subtask, done in order.
