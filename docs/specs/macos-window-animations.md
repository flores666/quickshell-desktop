# macOS-style window animations

## Goal

Animate the windows controlled by the existing title-bar buttons: close,
minimize, maximize/restore, and floating/tiled. Minimize and restore use the
classic macOS Genie effect into and out of the application's dock icon, as
chosen in the interview; the other actions use a short fade/shrink or smooth
geometry transition. Preserve each action's current result and window mode.

## Plan

### 1. Feed window motion and dock targets to the existing native owner

Keep design values in `config/`, pushed through `CompositorTheme` and
`CompositorOptions` to the window plugin's `Style`. Publish resting dock icon
rectangles for each window and monitor from the existing dock layout through
the compositor service; update on layout/model/display changes and config
reload, and remove targets with their owner. Do not poll or track hover frames.

Acceptance:

- Given the shell's theme bridge is running, native motion durations, curves
  and close scale read back as the corresponding design tokens.
- Given a dock application has multiple windows, each address targets that
  application's icon on its own monitor; reordered/resized icons update their
  targets and removed windows/screens leave no stale targets.
- Given the plugin is absent, dock layout and ordinary window actions work.
- Given no current dock target, minimize/restore still succeeds through the
  existing Hyprland path without a fabricated icon or blocking surface.

Files: `config/Motion.qml`, `config/Metrics.qml`,
`modules/common/CompositorTheme.qml`, `modules/dock/DockRow.qml`,
`modules/dock/DockPanel.qml`, `services/Compositor.qml`,
`hypr/windows/Style.{hpp,cpp}`, the native motion helper, and focused tests.

### 2. Animate the existing actions without changing their semantics

Use Hyprland's animation, snapshot and mesh-rendering facilities inside
`hypr/windows`; retain the existing native action dispatch and
`Compositor.focusWindow` restore path. Close fades/shrinks the compositor's
closing snapshot; maximize and layout changes animate the existing geometry.
Genie presentation is separate from the live layout and never resizes the
client through the dock icon. A failed snapshot falls back to the normal
action. Finish or cancel retained resources on close, reversal, monitor loss,
reduced motion and plugin unload.

Acceptance (inside a nested Hyprland, with the branch's scratch plugin):

- Given an ordinary floating window, minimize immediately puts it on
  `special:minimized`; intermediate rendered frames taper its image toward
  its dock icon and the final frame contains no old window image.
- Given that minimized window, the existing dock restore path draws the
  reverse Genie and returns to its floating box, then leaves no duplicate.
- Given a maximized, tiled or fullscreen window, minimize/restore preserves
  that mode and its final box (including the title bar's reserved space).
- Given close, the application receives the close normally and its retained
  image fades/shrinks away; no mapped input surface is added.
- Given maximize/restore or floating/tiled, intermediate geometry lies
  between the start and target boxes and the final box matches the existing
  `WindowModesTest`/`WindowMaximizeTest` contract.
- Given a restore during minimize, repeated minimize/restore, close during
  motion, or plugin unload, no stale snapshot, hidden live window, dangling
  callback or compositor crash remains.
- Given Animations is off, every action reaches its final state immediately,
  without a retained Genie image.

Files: `hypr/windows/main.cpp`, `hypr/windows/Style.{hpp,cpp}`, native motion
and Genie geometry helpers, and focused nested-compositor test fixtures.

### 3. Verify the complete desktop path

Exercise real button input and the dock restore path in an isolated nested
compositor; verify rendered intermediate and final frames, not only state.
Keep the existing window-mode tests as regression checks.

Acceptance:

- The new focused tests first fail for missing motion/target behavior, then
  pass with the implementation; spec and tests are committed before code.
- A scratch window-plugin build loads and unloads in nested Hyprland; virtual
  pointer presses exercise the title-bar actions and screenshots show the
  specified motion, including reverse and interrupted Genie transitions.
- `./tools/lint.sh` and the full `./tools/test.sh` suite pass (apart from the
  documented unavoidable lint warnings); runtime logs contain no new errors.
- Hyprland input layers and final client geometry show no input-blocking
  surface or change to the desktop's window-action semantics.

Files: `tests/WindowAnimationTest.qml`, focused test fixtures as needed,
this specification, and any existing window/dock regression fixtures that
need to exercise the real action path.

## Independence and execution

These items form one dependent subtask: targets and styling feed the same
native plugin that owns the effect, and lifecycle and visual tests exercise
that complete path. Implement on `forge/macos-window-animations` without
parallel worktrees. Leave the branch unmerged and unpushed.

## Non-goals

Do not change button count, button meanings, dock organization, fullscreen
workspace policy, application protocols, or unrelated workspace/overview
animations. Add no new settings, dependencies, polling, or input surfaces.
The effect is a macOS-style Genie, not a claim to reproduce Apple's renderer.

## Baseline

The acceptance tests were run against the unchanged window plugin in a private
Hyprland with two headless outputs. Dock target publication and native motion
tokens are absent. The real minimize button still moves the window to the
hidden workspace, but the intermediate image has already disappeared; restore
shows a full rectangle with no taper. Fixture input, capture, state, cleanup
and reduced-motion guards pass. These missing behaviors are the red baseline.
