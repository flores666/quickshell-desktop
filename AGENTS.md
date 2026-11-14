# AGENTS.md

## Project and ownership

Wayland desktop for Hyprland 0.57, Quickshell 0.3 and Qt 6.12. QML reloads
without a build. `native/` provides optional `Desktop.Native` icon-theme and
MPRIS recovery helpers; compositor plugins require separate builds.
`install.sh` provisions the desktop, including other applications' configs.

- `shell.qml`: entry point, per-screen chrome and shared surfaces.
- `config/`: design tokens and theme derivation.
- `services/`: system state, intent, availability and actions.
- `components/`: reusable widgets built on `Clickable`.
- `modules/`: surfaces; `modules/common/` owns shared popup chrome and IPC.
- `hypr/`, root `hyprland.lua`: compositor config and window plugin sources.
- `tools/`, `tests/`, `docs/specs/`: tooling, regression coverage and feature contracts.

Dependencies: `modules → components → config`; anything may read services.
Services never import components/modules. UI never calls system APIs directly.
Before editing, trace action/IPC → surface → component → service → backend;
read callers and callees. Identify identity, lifetime, failure and observable result.
Reuse working code, extend its owner, then use a fitting platform facility before
adding code. Refactor coherently when ownership requires it.

## Rules

1. **Design values belong in `config/`.** No hardcoded UI colors, sizes, fonts
   or durations elsewhere. Reuse tokens by meaning. Native/plugin styling goes
   through `CompositorTheme → CompositorOptions.derived`; native defaults are
   startup fallbacks. Algorithm/protocol/artwork constants and service-owned
   behavioral timings are exceptions. Fixed tokens need no new preference.
2. **No full-screen input catchers.** Mask popup input to its card; outside
   stays click-through. All popup cards share `OverlaySurface`; only one opens
   at a time, through `Overlay`.
3. **Events only; no polling**, including scripts, tooling and tests. Use signals,
   process output/exit, event streams or file watches. Timers are single-shot
   settle/dwell/timeout delays. Exceptions: visible clocks and `Processes`
   sampling `/proc`/`/sys`, timed from the previous sample's completion. Machine
   counters/history stay active; per-process reads require keyed
   `Processes.watch`, with GPU/network extras only while requested.
4. **Interaction states come from `Clickable`**: hover, press, selection,
   disabled and keyboard focus. Drags use its pointer signals and
   `focusRingTarget`; controls own value mapping. Use `Label` for shell text.
5. **Absent hardware/services mean absent controls.** Only quick settings'
   `FrontPage` keeps unavailable tiles/sliders disabled in place. Its battery
   reading and the bar still hide absent hardware. Never invent readings.
6. **The wheel only scrolls.** No widget `onWheel` or wheel value/selection
   changes. Existing bar `Workspaces`/`Tray` are exceptions. `CardMenu` closes
   on wheel and forwards it with `event.accepted = false`.
7. **Keep source files at most 300 lines.** Split by responsibility.
8. **Provision every new dependency** in the same change: packages, fonts,
   application configs, scripts and service setup belong in the repository
   and `install.sh`.
9. **One owner per invariant.** No parallel state machines, option writers,
   application indexes or command policies. Prove APIs unused across production,
   tests, native code and explicit IPC before deleting them. `install.sh`
   publishes every `bin/` command, including those with no repository caller.

## Reuse and lifecycle

| Need | Owner / invariant |
|---|---|
| Controls | `Clickable`, `Slider`, `ColorPicker`, `IconButton`, `MenuRow`, `FieldWell` |
| Surface styling | `Surface`, `Appearance.c`, `Surface.schemeOver`; popup material uses `PopupStyle` through `Surface.clearGlass` |
| Scrolling | `ThinScrollBar`, `Filmstrip`: share drawing/drag mapping, including minimum thumb, zero travel and Flickable origin |
| Popups | `Overlay` arbitrates; `ShellOverlay`, `OverlayCard`, `OverlaySurface`, `Door` own placement, retention, hand-off and motion |
| Replaced collections | `ScriptModel` preserves object identities; count/index models suit positional chart series, never notifications or reorderable windows |
| Charts/tasks | `Chart`, `StatCard`, `EntityPane`, `ChartCard`, `RankedList`; share mapped points and preserve sampling/history |
| External reads | `Probe`, `Process`, `FileView.watchChanges`; `Probe` coalesces reads but does not reject stale replies |
| Apps | `Apps.byId/byAppId/search/launch/launchAction`; `Compositor.exec` preserves workspace launch tracking |
| Settings | `SettingsStore` declares keys; `SettingsFile` persists; `Settings.pick`, `Tuning`, `CompositorOptions.spec` own validation/ranges |
| Hyprland | `Compositor` owns actions/quoting; `CompositorOptions.assignment/encode/decode` owns typed options |
| Desktop theme | `DesktopScheme`, `DesktopAccent`, `IconThemes`; terminal colors come from `terminal/palette.conf` plus the state accent overlay |
| Tests | `Check`, `Until`, `FileWait`, `Settle`, `WindowDriver`, `ServiceFixtures.py`, `HyprlandIntegration.lua` |

- Keep stable subject keys; resolve live records for actions. Hold only the
  presentation needed for an exit (`DockMenu.currentItem/heldItem`). Never act
  on a window array captured when a menu opened.
- Services retain intent across backend/enable changes; views release requests
  when their lifetime ends (`Bt.setDiscovering`). Guard the actual backend
  object in change handlers; derived availability may still describe its predecessor.
- Async replies must match both subject/endpoint and generation. Cancel queued
  work and clear stale availability on removal; cancellation alone is insufficient.
  Validate at boundaries and reuse that decision only within the same event.
- Hidden items still evaluate bindings. Gate presentation work without stopping
  required history/watchers; build matchers once per query. Measure performance
  with identical results and inputs; line/delegate counts alone prove no speedup.
- Reserve capture outputs with `mktemp`, install cleanup before fallible setup,
  release freezes on every exit, remove only this operation's unfinished file,
  and announce only success.
- Preserve popup flights, self-renewal, fade retention and per-card hover keys.
  Simultaneous swaps belong in one surface: separate Wayland commits can blink.
  Use `t.popup*` for popup motion and lifetime bounds, `RoundedClip` for corners.
- Notifications use `NotificationStack/Entry/Exit` for stable slots and exits.
  Retain closing objects with `RetainableLock`; actions must check `Notifs.isOpen`.
- Administrator tasks execute root-owned command snapshots with argument-free,
  per-task sudoers grants. Command edits reauthorize; deletion/demotion revokes
  first; cancelled authorization leaves user units intact. Never grant execution
  of user-writable command files.

## Testing and verification

```sh
qs -c shell                              # ~/.config/quickshell/shell
qs -c shell ipc call shell <action>       # ShellIpc.actions / run whitelist
./tools/lint.sh
./tools/test.sh [NameTest ...]
python3 tools/genicons.py --check
./tools/build-overview-plugin.sh --if-stale
./tools/build-windows-plugin.sh --if-stale
./tools/build-native-module.sh --if-stale
```

**Always run `./tools/lint.sh` and inspect the runtime journal before claiming done.**
Use the wrapper: plain qmllint lacks Quickshell's `root:/` imports and generated
qmldirs. Known warnings concern C++-registered Quickshell types/enums and
`QObject*` properties; investigate anything else.

The live shell is `quickshell.service`, capped at 1.5 GB with no swap. After
runtime changes restart with `systemctl --user restart quickshell`, then read
`journalctl --user -u quickshell -o cat` from that start. Check beyond INFO and
known environmental tray/absent-Bluetooth warnings; lint misses some load errors.
New module directories require a restart; inode-replacing edits may miss hot reload.

Choose the smallest behavioral proof; add regression coverage for state/lifecycle
bugs. QML tests run as isolated `qs -p` shells, not qmltestrunner; `Check` prints
`TESTS DONE n failed`, and the runner terminates them (`Qt.quit/exit` do not).
Run compositor/window tests in **nested Hyprland**, with its
`HYPRLAND_INSTANCE_SIGNATURE`, `WAYLAND_DISPLAY` and scratch plugins.

- Keep fixture markers and isolation guards. Per-test commands go in `TEST_BIN`;
  stand-ins replace external boundaries, leaving production logic under test.
  Notification/media suites use private D-Bus sessions; terminate the whole group.
  Task tests use the real user manager only under private prefixes and clean up.
  Never reach real dconf, terminal signals, earlyoom or authorization from tests.
- Never start the whole shell in a nested session: `Fonts`, `Wallpaper` and the
  notification server can affect the real desktop. Use the test runner or a
  minimal shell containing only the surfaces under test.
- Hidden nested outputs need headless screens to render. Capture with
  `WAYLAND_DISPLAY=<nested> grim -o <headless>`; full-output captures can hang.
  Use `hyprctl layers` for mapped surfaces/input hazards, `clients -j` for geometry,
  and screenshots for appearance. Confirm workspace, focus and target before input.
- `movecursor` does not send Qt hover events. Use a persistent virtual-pointer
  connection on the nested socket; live `/dev/uinput` needs real relative motion.
  Virtual-keyboard input can also target the nested socket. Kill owned PIDs;
  `pkill -f` can kill its caller.
- Hyprland config changes: compare binds, effective options and `configerrors`
  around a nested reload. `--verify-config` cannot validate unloaded plugin options.
  `HyprlandIntegration.lua` records registrations without running startup callbacks.

## Desktop provisioning and state

- Packages/fonts/themes: `packages.txt` or `packages-aur.txt`, with their purpose.
  Application configs stay in their own directories and get installer links;
  scripts go in `bin/`, entries in `applications/`, units in `systemd/`.
  Enable services in `install.sh` or graphical startup in `20-autostart.lua`.
- Config links route through `~/.config/quickshell/shell`. Machine-owned Hyprland
  and kitty files include the project and keep local overrides afterwards.
  Never commit monitor/device tuning, personal apps, wallpapers or secrets.
  Inspect new configs for credentials; never save fish universal variables,
  NetworkManager profiles or an unrestricted dconf dump.
- Preserve installer backups and idempotence. Managed `/etc` defaults use the
  `# quickshell-desktop` marker; retain subsequent machine edits. Verify installer
  changes twice in an isolated HOME with external/system effects stubbed:
  **HOME alone does not isolate dconf**, services, package installs or signals.
- Save portable preferences with `tools/save-profile.sh`; commit `profile/`.
  State is copied/seeded, never linked or overwritten on reinstall. Keep its
  machine-state filtering and dconf allowlist. Wallpapers are saved by name.
- Negative numeric overrides and empty string seeds mean unset. Reset-all affects
  numeric overrides, not seeds/booleans. Migrate renamed preferences before live
  reload: removing a `SettingsStore` key drops it from the next write.
  User-visible text uses American English.

## QML and platform traps

- Use `pragma ComponentBehavior: Bound` and required delegate properties.
  Avoid module filenames matching services. Qualify imports that shadow our
  singletons (`QtCore as Core`, `Quickshell.Networking as QsNet`).
- Typed function parameters cannot have defaults. JS globals such as `escape`
  are illegal method names; Item anchor names (`top`, `left`, etc.) are final.
  Some failures appear only at runtime. Derived signal handlers also run the
  base handler; property assignments replace base bindings.
- `NumberAnimation.finished` never fires inside a `Behavior`; resource release
  needs a bound single-shot timer. Positioner transitions write both axes:
  slide with `Translate`, not the positioned item's `x/y`.
- Size from the visibility condition, never effective `visible` (false under a
  hidden popup). Avoid centering children on a parent sized from those children.
  Keep notification widths stable when scrollbars appear and size cards directly
  from contents; ListView transitions can lose height/opacity updates.
- `FileView` completion handlers must defer replacement reads/writes with
  `Qt.callLater`. Preserve `SettingsFile.blockWrites`, burst coalescing and readiness
  from loaded/saved signals; `FileView.loaded` can precede adapter data and remain
  false after a first write. Never persist defaults before reading existing state.
- `grabToImage` requires a mapped window; retain its result while using its URL.
  Cached `Canvas.loadImage` may emit no signal: check `isImageLoaded` immediately.
  Unload before requesting a new size; `createImageData` takes a string URL.
- Rounded gradient Rectangles can ignore parent opacity; use a square gradient
  with `RoundedClip`. Use `Shadow`/`RectangularShadow` rather than extending
  MultiEffect beyond its blur limit. `LevelAdjust` output alpha must span 0–1.
- Popups use on-demand keyboard focus, never Exclusive or `HyprlandFocusGrab`
  (both break outside clicks). Non-consuming Lua binds own dismissal; cards
  swallow Escape's duplicate key event. Auth holds `Overlay.authorizing` and
  sits above popups. Input masks do not clip rendering; `Region { item: null }`
  is click-through. Surfaces drawing their own fades need `no_anim`.
- Qt's text-input warning on popup close is suppressed by the unit's
  `--log-rules qt.qpa.wayland.textinput.warning=false`; a manual qs may show it.
  PipeWire readings are valid only when ready; Quickshell battery/Wi-Fi readings
  are fractions. Do not restore workarounds fixed in Quickshell 0.3.2.

## Icons and compositor plugins

- `components/Icons.qml` and `hypr/windows/HugeiconsGlyphs.hpp` are generated by
  `tools/genicons.py` from vendored SVGs/map. Preserve license, pin, semantic keys,
  stroke styles and arc normalization; regenerate, check both outputs and inspect
  visually. Conflux installation is owned by `tools/install-icon-theme.sh`;
  preserve XDG fallback and app-provided tray/media/notification artwork.
- Qt caches icon themes for the process; hot reload cannot refresh them.
  `IconThemeWatch` refreshes caches and provides generation-specific image URLs.
  Use `AppIcon.renderSource` for image/cache identity; reject obsolete Canvas
  loads. Never append query/fragment fields to Quickshell icon URLs. Keep the
  shared lock across QIcon writes, lookups and provider renders; release it before
  emitting revision signals.
- Hyprland config is Lua: `hypr/hyprland.lua → conf.d/*.lua`, with
  `90-quickshell.lua` loading root `hyprland.lua`. Use `hyprctl eval`, `hl.dsp.*`
  and guarded `hl.plugin.*`. Options repush on `configreloaded`; clearing overrides
  reloads defaults. Keep derived writes batched with the final guarded
  `windows.restyle()` so drawing, hit testing and reservations agree. Read back
  new options: an `ok` response is insufficient. Never add a second writer.
- Build scripts' `--if-stale` checks run at login/install. Plugins require matching
  Hyprland headers. Overview uses sandwichfarm/hyprexpo, pinned for 0.57 to
  `v0.57.1` / `00a44bf1296ee64c719aec7ae6c8d2fa08fef0dd`. Newer tags can break
  patches (`v0.57.2+1` did); revalidate all seven patches and nested runtime before
  advancing. `python3 tests/OverviewBuildTest.py` covers pin/rebuild behavior.
- Test plugin builds only in nested Hyprland, using scratch output paths declared
  in its Lua config, **overview before windows**. Runtime-only loads can disappear
  on reload; verify `hyprctl plugin list`. Never overwrite a mapped `.so`, or
  unload a working plugin after `/proc/<pid>/exe` becomes `(deleted)` from an
  upgrade. Logs: `journalctl --user -t hyprexpo` / `-t hypr-windows`.
- Window plugin unload must remove decorations from every tracked window,
  including closed/hidden windows retained by render passes, before `dlclose`.
  `ElasticDrag`/`WindowMotion` own native and overview drag presentation; see
  `docs/specs/elastic-drag.md`. Keep drawing and hit-testing hooks paired.
  Placement must honor explicit rules, exclude transient drag floats, and use
  `setTargetGeom` so restored geometry survives maximize/fullscreen. Keep the
  default float rule early: floating only after map loses the client's own size.
