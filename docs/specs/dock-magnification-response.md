# Prompt dock magnification

## Goal

Remove the delayed response when the pointer enters an icon or moves across
the dock. Entry, tracking, and exit should all respond faster, as requested
in the interview, while retaining the broad Gaussian wave, smooth motion,
stable bottom edge, and strict 120% limit.

## Plan

1. Fix pointer tracking and animation response as one dock change.
   - Given pointer movement over an icon's clickable artwork, a gap, or the
     magnified upper edge, the distance input follows the next delivered
     pointer event consistently; clicks and drag handling remain available.
   - Given entry or exit, magnification starts promptly and settles within
     120 ms, allowing one rendered frame for observation. There is no dwell
     before the animation begins.
   - Given a continuing sequence of horizontal pointer movements, the wave
     makes visible progress throughout the sequence instead of repeatedly
     restarting a slow ease-in. Reversing direction responds promptly too.
   - Given a stationary pointer over an original icon center, scales remain
     120%, 117–118% for immediate neighbors, and 110–112% for second neighbors.
     Animated values never exceed 120%; no spring or overshoot is introduced.
   - Given a magnifying row, icons retain their bottom baseline and clear
     neighbor spacing. Distances still use original positions, components
     retain their identities, and there is no periodic polling.
   - Files: `config/Motion.qml` if a new timing token is necessary;
     `modules/dock/DockPanel.qml`, `DockRow.qml`, `DockSlot.qml`, and
     `DockButton.qml` as required by the measured cause;
     `tests/DockResponseTest.qml` and the existing dock regression checks.
   - Write and run the new response regression tests before implementation;
     confirm failures describe delayed behavior, then commit this spec and
     those tests. Keep the committed tests unchanged during implementation.

2. Verify the response visually and check desktop regressions.
   - Given a rendered isolated dock, capture entry, horizontal travel in both
     directions, and exit over artwork and gaps. Check the animation starts
     promptly, remains fluid, and restores the resting geometry.
   - Verify a launcher click and a dock reorder with synthetic pointer events
     in the isolated compositor. Check transparent chrome and the smallest
     and largest supported icon sizes.
   - Run `./tools/lint.sh`, the dock regression tests, and the full existing
     test suite in nested Hyprland. Report environmental failures separately
     from regressions and do not weaken tests to hide them.
   - Restart the live `quickshell.service` and inspect its runtime log before
     claiming completion. Remove temporary compositor instances and rules.
   - Files: this spec records final verification results; no independent
     implementation files.

## Execution

Both items concern the same pointer-to-animation path and are sequential.
Use one subtask on `forge/dock-magnification-response`; no parallel workers or
worktrees are needed. The earlier magnification implementation is committed
on this branch as the baseline. Leave this branch unmerged and unpushed.

## Verification results

- Completed both plan items. Pointer coordinates already arrived promptly
  over artwork and gaps; the measured cause was the per-target 180 ms
  `InOutQuad` animation. Both application slots and the launcher now use the
  existing 120 ms `instant` timing and `OutCubic` movement curve, so every
  retarget starts making progress immediately without spring or overshoot.
- Before implementation, `DockResponseTest` completed with five expected
  response failures: early entry progress, entry deadline, continuous
  rightward movement, exit deadline, and launcher deadline. Pointer-delivery
  checks passed. The committed test contract was unchanged afterward.
- After implementation, all 10 response checks and all 31 existing
  magnification checks passed.
- Full suite: 31 suites, 676 checks passed, zero failed. The run used a hidden
  nested Hyprland with two outputs, the branch's window plugin built into a
  scratch directory, and the repository's look-and-feel/window rules. A copy
  of the checkout supplied a generated wallpaper in its test profile for
  `BackdropProbeTest`; implementation and test files matched the checkout
  byte for byte. The normal config directory remained in use so `TasksTest`
  could reach the user systemd manager with its own test-only unit prefix.
- Background captures covered entry, both horizontal directions, gaps, exit,
  28 px and 48 px icons, and transparent chrome. The peak remained 1.2,
  neighbors were 1.1728 and 1.1115, and exit restored every scale to 1.
  Synthetic input on the nested socket opened the launcher, reordered an
  application from slot 3 to slot 5, and hid/revealed the dock successfully.
- `./tools/lint.sh` reported only the existing Quickshell type warnings.
  `git diff --check` passed. Both the isolated runtime log and the live
  service's automatic-reload log were clean; the live service remained
  active. The user's subsequent instruction to keep tests in the background
  superseded the planned live-service restart: no restart or workspace/focus
  switch was used for final verification.
- Temporary compositor instances and runtime test rules were removed. No
  requested behavior remains unimplemented; no tests remain red.
