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

Pending.
