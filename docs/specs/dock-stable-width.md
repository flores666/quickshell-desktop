# Stable dock background during magnification

## Goal

Keep the dock's glass background at its normal resting width when the pointer
enters, moves across, and leaves the dock. As selected in the interview,
magnified icons may extend beyond that background while retaining the
existing wave, spacing, response controls, and strict 120% scale ceiling.

## Plan

1. Separate background width from magnified icon geometry.
   - Given an unchanged application list, icon size, and chrome settings,
     hovering any icon or gap leaves the background's width and horizontal
     center unchanged throughout entry, movement, and exit.
   - The background follows the existing unscaled row measurement and frame
     padding. Actual application arrivals/departures and icon/chrome setting
     changes may still resize it, preserving existing behavior.
   - The live icon row still expands and stays centered, so neighboring icons
     move apart without overlap. Its enlarged first/last icons may extend
     past the background's edges; they are drawn and remain interactive.
   - The input mask and hover handler cover that overflow, including with
     transparent chrome, the largest icon size, and the widest wave. Moving
     from the background onto an overflowed icon does not drop hover or start
     auto-hide. Keep input bounded to dock/preview/reveal regions.
   - The reveal strip uses the stable background width. Magnification still
     samples original icon centers; no layout feedback, component recreation,
     polling, or additional surfaces are introduced.
   - Files: `modules/dock/DockPanel.qml` and existing dock geometry helpers
     only if needed; regression tests in `tests/DockWidthTest.qml`.
   - Add tests first, run them against current behavior, and confirm failures
     describe background width following the wave or missing overflow input.
     Commit this spec and the red tests before implementation; keep the test
     contract unchanged afterward. Existing row-growth tests remain valid.

2. Verify fixed background and overflow interactions in the background.
   - Capture rest, center/edge hover, horizontal travel, and exit in a hidden
     nested compositor. Compare the glass's left/right edges across captures;
     check the upward growth, clear spacing, and original bottom baseline.
   - Exercise an outer icon beyond the background, launcher click, drag
     reordering, auto-hide/reveal, transparent chrome, minimum/maximum icon
     sizes, and the broadest wave using input on the nested socket only.
   - Run the new test, existing dock tests, full suite, `./tools/lint.sh`, and
     `git diff --check`. Use the established nested setup and wallpaper
     fixture; run the compositor-reset persistence test last where needed.
   - Inspect isolated runtime logs and the live shell's automatic-reload log.
     Keep the user's workspace/focus unchanged and do not restart their shell.
     Remove temporary compositor instances and runtime rules, and record the
     final verification here.

## Execution

Background sizing and overflow input are one coupled dock-geometry subtask.
Work on `forge/dock-stable-width` from the current settings branch, with no
parallel workers or worktrees. Leave the final branch unmerged and unpushed.

## Verification results

Pending.
