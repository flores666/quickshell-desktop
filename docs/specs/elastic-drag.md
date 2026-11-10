# Elastic window dragging

Ordinary native moves and hyprexpo tile transfers share one presentation in
`hypr/windows/ElasticDrag`. Hyprland still owns the drag device grab, layout,
window identity and actual drop. Hyprexpo owns tile selection and workspace
assignment. Neither path creates an input surface or delays pointer movement.

## Presentation

- Lift to 93% in 120 ms, scaling around the exact grab point, with an added
  soft shadow. The source size is retained before native tiled pickup changes
  the floating geometry.
  The title-bar owner applies the first pointer delta before native pickup,
  so a fast initial movement cannot change the point being held.
- Actual pointer velocity drives at most 2 degrees of rotation and 2.5%
  stretch. The affine mapping keeps straight edges and pins the grabbed point.
  The deformation reaches zero within 180 ms without requiring another move.
- Release interpolates to the layout's final box over 300 ms with one small
  spring overshoot. Native movement animation does not run a second landing.
- A one-shot 350 ms edge dwell switches to an adjacent numbered workspace.
  Its slide lasts 350 ms on the shell's standard curve. Workspace animation
  completion starts another dwell if the pointer still rests at the edge.
  A physical neighbouring monitor takes precedence. Other monitors' numbered
  workspaces and explicit workspace bindings are skipped.
- The live carried window is omitted from workspace drawing, then drawn once
  above the workspace scene. It retains its pointer anchor and deformation
  across the whole slide. Output origins and scales are handled by the native
  transformer API; a window can span outputs.

`config/WindowDrag.qml` contains the fixed presentation tokens;
`CompositorTheme` pushes them through the existing option pipeline. No new
preferences, dependencies, polling loops or independent window-movement
policy are introduced. Animation ticks stop after lift/deformation/landing
settle; damage covers the previous and current transformed bounds.

## Overview boundary

`hyprexpo-elastic-drag.patch`, applied after the six existing patches, replaces
the grid's drag proxy with the same live transformer when the windows plugin
is available. Tile hit-testing and drop positioning use the exact rendered
UV crop and tile box. Floating drops stay within the destination work area;
tiled drops remain the layout's responsibility.

The synchronous, typed `windows.elasticDrag` plugin event carries a phase,
weak window identity and four doubles for a global logical display box:
0 grab, 1 motion, 2 land, 3 cancel, 4 presentation finished, 5 preview capture
begin, 6 preview capture end. Capture scope cleanup runs on every return.
Only overview captures omit the subject; ordinary window snapshots retain
their existing renderer policy. Completion refreshes the workspace previews
after the live representation is removed. Event identity is checked when the
windows plugin is reloaded; losing that backend cancels an active grid drag. With animations off or the window's
`no_anim` rule, the overview keeps its existing reduced-motion behavior.

Close, monitor removal, config reload and plugin unload release native
transformers and callbacks. Escape ends a native drag with a valid landing;
an invalid overview drop lands back in its source workspace. Unload also
destroys retained title-bar render passes before the library is unmapped.
Session locking clears the carried presentation before drawing the lock
surface. A grab also supersedes an unfinished Genie launch/restore, so only
one representation owns the subject. Each render uses one animation time for
all mesh vertices and shadow geometry.

## Verification

Build both plugins into a scratch `XDG_DATA_HOME`; load those paths in a nested
Hyprland with its own state directory and a 1280x800 headless `ELASTIC-1`
output. Use the project's `float-by-default` rule for the existing window-mode
and native-style suites. Never replace a library mapped by a running instance.

Run `tools/test.sh WindowElasticTest WindowElasticEdgeTest
WindowElasticOverviewTest WindowElasticTiledTest WindowElasticNativeTest
WindowAnimationTest` with that compositor's
`HYPRLAND_INSTANCE_SIGNATURE`, `WAYLAND_DISPLAY` and `XDG_RUNTIME_DIR`.
The elastic fixtures use a persistent wlr virtual pointer, actual kitty
contents, compositor state and rendered frame measurements. They cover lift,
an off-center anchor, a large first move, tile pickup, direction reversal, bounded tilt, straightening while
held, landing, reduced motion, close during drag, edge dwell, continuous
visibility/position across multiple transfers, responsive movement during a
slide, overview transfer/cancellation and absence of input-taking surfaces.

Run `NativeStyleTest` and `WindowModesTest` separately with fresh runner caches;
kitty persists its maximized launch state in that cache. Also run
`tools/lint.sh`, inspect the compositor/shell logs and check plugin unload.

Installing rebuilt plugins changes the files for the next login. An existing
compositor retains its loaded versions until those plugins are reloaded or
the session is restarted.
