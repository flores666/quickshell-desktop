# Delayed dock hover effects

## Goal

Keep dock magnification immediate, while requiring the pointer to rest on
the same icon for 300 ms before showing the hand cursor, hover background,
and application-name tooltip. Apply the same interaction to the Applications
button, with clicks and drag reordering available immediately.

## Traced behaviour

`Clickable` owns hover, press, selected, disabled, and focus states. Its hover
state currently follows the pointer immediately; the dock's two uncommitted
arrow-cursor overrides come from the preceding user request and are carried
into this branch. The new behaviour will keep that arrow before the delay
and show the hand after it.

`DockPanel` tracks raw icon entry/exit for tooltip subjects and window
previews. `Tooltip` currently waits the general 450 ms dwell. Magnification
uses the panel's independent pointer tracking, so it can keep responding
immediately. Window previews also use raw entry/exit for their safe triangle,
450 ms initial dwell, and 300 ms switch between applications.

## Plan

1. Add delayed hover through the existing interaction owner and dock wiring.
   - Given entry onto an application icon or the Applications button, before
     300 ms the cursor is an arrow, the hover wash is absent, and the name
     tooltip is hidden. At 300 ms the hand appears and the wash and tooltip
     begin their existing fade animations together, with no additional dwell.
   - Given movement within the same icon, the original dwell continues. Given
     departure before 300 ms, nothing activates later. Given movement to
     another icon or re-entry after leaving, that icon gets a fresh 300 ms.
     Leaving an activated icon clears its hand and hover state immediately;
     existing fade-out animations remain in use.
   - Given an icon becomes disabled or unavailable during the dwell, no stale
     hover effect activates. Press, click, keyboard activation, and drag start
     remain immediate. Persistent selection/active-application indications
     remain independent of the hover delay.
   - Given pointer entry and movement, magnification retains its current
     immediate response and settings. Dock width, icon centres, and artwork
     baselines retain their existing fixed geometry.
   - Given a window preview is available, raw entry/exit still reaches its
     existing dwell and safe-triangle logic immediately, preserving its
     current total timing and click-to-open behaviour. Other shell widgets
     retain immediate hover and their existing tooltip timing.
   - Ownership: add an opt-in delay to `Clickable`, with its default preserving
     current behaviour. Put the fixed 300 ms dock duration in `config/Motion.qml`.
     Reuse `Tooltip`'s existing delay, and keep raw pointer tracking distinct
     from delayed hover effects. All timers remain single-shot.
   - Files: `components/Clickable.qml`, `config/Motion.qml`,
     `modules/dock/DockItem.qml`, `DockButton.qml`, and `DockPanel.qml`;
     `components/Tooltip.qml`, `modules/dock/DockSlot.qml`, and `DockRow.qml`
     only if the traced wiring requires it; regression checks in
     `tests/DockHoverDelayTest.qml` and existing dock tests as required.
   - Write and run the regression checks before implementation, confirm that
     failures describe missing delay/cursor/tooltip behaviour, and commit the
     spec and tests. Keep the committed test contract unchanged afterward.

2. Verify timing, interaction, and desktop regressions in the background.
   - In an isolated nested Hyprland session, verify quick crossings, resting
     for 300 ms, movement within an icon, switching icons, leaving/re-entering,
     immediate clicks and drag reordering, and immediate magnification.
     Include application icons and the Applications button, transparent and
     visible dock chrome, and the supported icon-size extremes.
   - Install the hidden-workspace and no-initial-focus rules for the actual
     nested window class (`aquamarine`) before creating any test outputs.
     Verify every test window is on that hidden workspace before sending any
     input. Never switch the user's workspace or send input to the live shell.
   - Run the focused hover and existing dock checks, the full test suite,
     `./tools/lint.sh`, and `git diff --check`. Inspect isolated and live
     runtime logs without restarting the user's shell. Record environmental
     failures separately, then remove all task-created windows, processes,
     and temporary compositor rules.
   - Files: this spec records verification results.

## Execution

The interaction primitive and dock integration form one dependent behaviour
change. Use one subtask directly on `forge/dock-hover-delay`, with no parallel
workers or worktrees. Preserve the preceding uncommitted cursor changes until
their dock bindings are replaced by the approved delayed-cursor behaviour.
Leave this branch unmerged and unpushed for review.

## Verification results

- Completed both plan items. `Clickable` now owns an optional hover delay,
  with immediate hover as its default and immediate raw pointer state for
  callers that need it. The dock opts into the 300 ms motion token for its
  hand cursor and wash; its tooltip uses the same duration. A new subject
  starts a fresh dwell, and the fading tooltip retains its previous label
  until the new one is ready. Ordinary visible tooltip text still updates
  immediately, and other controls retain their existing timing.
- The regression test was run before implementation and committed with 14
  expected behaviour failures. The test contract remained unchanged during
  implementation. Afterward all five dock suites passed, followed by the
  full suite: 34 suites, 1,099 checks passed, zero failed. The scratch full
  suite supplied a generated wallpaper in its profile; every code and test
  file matched the checkout byte for byte.
- Rendered checks confirmed the arrow, no hover wash or name at 40/200 ms,
  immediate magnification, and the hand, wash, and name together at 336 ms
  (300 ms plus observation time). Moving within an icon did not reset the
  dwell. First/middle/last applications and Applications were checked at
  28 px and 48 px with transparent and visible chrome; width stayed fixed.
- Immediate launcher clicks, dragging before 300 ms, drag reordering, and
  keyboard activation while hover was pending passed. Two real kitty test
  windows verified that previews still receive raw entry immediately, open
  after their original 450 ms total dwell, and open immediately on click.
- `./tools/lint.sh` reported the existing Qt/Quickshell type warnings and
  `git diff --check` passed. The isolated log had only the documented Qt
  Wayland text-input warnings from manual `qs`; the live reload log was
  clean and the live shell stayed active without a restart.
- Both nested output windows were confirmed on the hidden test workspace
  before input and after verification. No foreground output windows were
  created, and no input or workspace switch targeted the user's desktop.
  Test windows/processes and temporary compositor rules were removed, and
  the frame-rate override was restored.
