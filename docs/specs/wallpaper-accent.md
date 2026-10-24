# Wallpaper accent: the system's accent from the wallpaper

## Goal

The shell measures the main colour of the wallpaper, and a *Match wallpaper*
toggle under the Accent row makes it the accent: in both themes, at each
theme's own lightness so it stays legible, and again whenever the wallpaper
changes. While it is on, the same colour goes out to Hyprland's active window
border, GTK's accent (the nearest of the colours libadwaita offers) and the
terminal's accent (kitty, and neovim as it starts); off, each goes back to
what it was. A wallpaper with hardly any colour still gives one: the nearest
legible to it.

## Terms

- **W**: `Settings.wallpaperAccent`, the wallpaper's main colour as last
  measured, `""` before any.
- **follow**: `Settings.accentFollowsWallpaper`, the toggle.
- **L, C, h**: a colour's OKLCH lightness, chroma and hue (Björn Ottosson's
  OKLab, sRGB). **tone(x, like)**: x's chroma and hue at like's lightness.
- **tuned**: each theme's own accent, `#c15f3c` (day) and `#d97757` (night);
  the terminal's are palette.conf's `accent #7d93ee` and
  `accent_bright #9aaef5`.
- **legible**: `Appearance.inSeedRange(accent, Appearance.seedRange("accent"))`,
  the rule every picked accent is held to (HSV saturation ≥ 0.2, value ≥ 0.35).
- A picture is given as pixels (RGBA bytes, row by row), as `BackdropProbe`
  hands one to `Backdrop.measure`.

## Plan

### 1. The wallpaper's main colour

`Backdrop.mainColor(pixels, width, height)`: the colour covering the most of
the picture among its colours. Each pixel counts by the square root of its
chroma (max − min channel), so greys count for nothing and a large muted area
outweighs a small vivid one; pixels are tallied by hue (24 bins, each with
half of its neighbours'), and the answer is the weighted mean of the pixels
in the winning bin and its two neighbours. A picture with no colour at all
gives its mean grey. `Backdrop.measure` stores it in `Settings.wallpaperAccent`
when the picture measured is still `Wallpaper.current`.

- 70% `#2a3f66`, 30% `#e8702a` → `#2a3f66` (each channel within 2/255).
- 80% `#808080`, 20% `#c03030` → `#c03030` (within 2/255).
- all `#808080` → `#808080`.
- 90% `#7a7f8a`, 10% `#808080` → h within 5° of `#7a7f8a`'s.
- 0 × 0 → null.
- `Backdrop.measure` of the current wallpaper (70/30 as above) → W ==
  `#2a3f66` (within 2/255); of a picture that is not current → W unchanged.

### 2. The accent follows the wallpaper

`Appearance.accentFor` gives, while follow is on and W is set, tone(W, tuned)
for each theme, its chroma raised as little as it takes to be legible; a W
with no hue at all takes the tuned accent's. `accentText` and `accentSoft`
follow the accent as for a picked one. New `config/ColorMath.qml` holds the
OKLab maths.

- follow, W `#2a3f66` → `day.accent`: L = L(`#c15f3c`) ± 0.01, h = h(W) ± 2°,
  C = C(W) ± 0.01; `night.accent`: L = L(`#d97757`) ± 0.01, h = h(W) ± 2°.
  Both legible.
- follow, W `#ff00ff` → `day.accent` L = L(`#c15f3c`) ± 0.01, h = h(W) ± 3°,
  legible.
- follow, W `#7a7f8a` → `day.accent` h = h(W) ± 5°, legible.
- follow, W `#808080` → `day.accent` h = h(`#c15f3c`) ± 2°, legible.
- follow, W `""` → `day.accent` == the chosen accent (`Settings.accentColor`,
  or `#c15f3c` when that is `""`).
- not follow, W `#2a3f66` → `day.accent` == the chosen accent.
- follow, W `#2a3f66` → `day.accentText` is whichever of `Appearance.ink`
  and white contrasts more with `day.accent`; `day.accentSoft` ==
  `day.accent` at alpha 0.16, `night.accentSoft` at 0.3.

### 3. Settings: Match wallpaper

In `ColorsSection`, under the Accent row: a *Match wallpaper* toggle
(`MenuRow` + `ToggleSwitch`, as *Match top panel*), subtitle "The accent
follows the wallpaper's main color". Present only once there is a W; while
on, the Accent row is not offered. A preference like the other *Match*
toggles: `Settings.setAccentFollowsWallpaper`, kept by *Reset all*, saved in
`profile/`. W and `gtkAccentBefore` (item 5) are this machine's, and
`save-profile.sh` saves them empty.

- W `""` → the toggle (`objectName: "matchWallpaper"`) is not visible.
- W set → visible; its switch reads follow; a click on the row flips follow.
- follow → the Accent picker (`objectName: "accentPicker"`) is not visible;
  the background picker is.
- not follow → the Accent picker is visible.

### 4. Window borders

While follow is on and W is set, `CompositorTheme` adds
`general:col.active_border` = the accent (`Appearance.c.accent`, as Hyprland
spells it). Off, the option leaves `CompositorOptions.derived`, and a derived
option that goes away asks Hyprland to reload, as a cleared override does, so
the config's own value comes back.

- follow, W `#2050c0` → `derived["general:col.active_border"]` ==
  `CompositorTheme.rgba(Appearance.c.accent)`; `hyprctl getoption
  general:col.active_border` reports that colour.
- not follow → no `general:col.active_border` in `derived`; `getoption`
  reports the config's gradient again.

### 5. GTK's accent

New service `DesktopAccent` (the accent handed to other applications) and
module `modules/common/DesktopTheme` (which works out what it hands: a
service cannot read `config/`). While follow is on and W is set,
`org.gnome.desktop.interface accent-color` is the libadwaita accent nearest
to the shell's accent (nearest in OKLab's a/b plane; the nine colours are
tokens in `config/`). The value before it first set one is kept in
`Settings.gtkAccentBefore` and given back when follow goes off, as `Fonts`
does with the font, through `gsettings`. `tools/test.sh` puts `tests/bin`
first on the tests' `PATH`: a `gsettings` that keeps what is set in a file
of the run's own, and a `pkill` that only notes what it was asked (item 6),
so no test writes the machine's dconf or signals the user's terminals.

- accent-color `purple`; follow, W `#c03030` → `red`, `gtkAccentBefore` ==
  `purple`.
- then W `#2050c0` → `blue`; W `#e8702a` → `orange`; `gtkAccentBefore`
  still `purple`.
- not follow → `purple`, `gtkAccentBefore` == `""`.

### 6. The terminal's accent

While follow is on and W is set, `DesktopAccent` writes
`$XDG_STATE_HOME/quickshell-desktop/palette.conf` (`~/.local/state` when
unset): `accent` = tone(W, `#7d93ee`) and `accent_bright` = tone(W,
`#9aaef5`), held legible on the terminal's background as in item 2. Lines
there replace palette.conf's of the same name: `kitty-colors.py` and
neovim read it after palette.conf. Running kittys are told to reload their
config (`pkill -USR1 -x kitty`); a neovim or a fish prompt takes it as it
starts. Off, the file goes and the kittys reload again. In the tests that
`pkill` is item 5's stand-in. The accent is the terminal's ANSI blue (`color4`, `color12`)
and its link colour: with a red wallpaper, what programs print in blue comes
out red.

- follow, W `#2050c0` → the file holds exactly `accent #…` and
  `accent_bright #…`; accent h = h(W) ± 2°, L = L(`#7d93ee`) ± 0.01;
  accent_bright L = L(`#9aaef5`) ± 0.01.
- `python3 terminal/kitty-colors.py` in the same environment prints
  `color4`, `url_color` = that accent and `color12` = that accent_bright,
  and every other line as it does without the file.
- kitty was told to reload (`-USR1 -x kitty`) once the file was written.
- not follow → the file is gone; `kitty-colors.py` prints palette.conf's
  `#7d93ee` and `#9aaef5`; kitty was told to reload again.
- By hand, in a nested Hyprland: a kitty open there turns to the new blue
  without restarting; `nvim` started after reads the file's accent.

### 7. AGENTS.md

The *Seed* entry and the services and settings tables name the toggle, W,
`gtkAccentBefore`, `DesktopAccent`, `DesktopTheme` and `ColorMath`; *The
rest of the desktop* says what the state file is and who reads it.

## Files and order

| Item | Files |
|---|---|
| 1 | `components/Backdrop.qml`, `services/Settings.qml`, `services/SettingsStore.qml` |
| 2 | `config/ColorMath.qml` (new), `config/Appearance.qml`, `services/Settings*.qml` |
| 3 | `modules/settings/ColorsSection.qml`, `services/Settings*.qml`, `tools/save-profile.sh` |
| 4 | `modules/common/CompositorTheme.qml`, `services/CompositorOptions.qml` |
| 5 | `services/DesktopAccent.qml` (new), `modules/common/DesktopTheme.qml` (new), `shell.qml`, `config/Appearance.qml`, `services/Settings*.qml`; tests: `tools/test.sh`, `tests/bin/` |
| 6 | `services/DesktopAccent.qml`, `modules/common/DesktopTheme.qml`, `terminal/kitty-colors.py`, `nvim/init.lua`, `terminal/palette.conf` (its header) |
| 7 | `AGENTS.md` |

Item 1 stands alone. 2 needs 1's W; 3–6 need 2's accent, and all share
`Settings`. One subtask, built in a worktree off the live checkout and
landed whole.

Tests: `tests/WallpaperColorTest.qml` (1), `tests/AccentFollowTest.qml` (2),
`tests/MatchWallpaperTest.qml` (3), `tests/AccentBorderTest.qml` (4),
`tests/GtkAccentTest.qml` (5), `tests/TerminalAccentTest.qml` (6). All run
by `tools/test.sh` in a nested Hyprland, as the rest are.
