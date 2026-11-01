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

- Completed both plan items. Only `DockPanel.qml` required production changes:
  glass width now follows the original row plus frame padding; the centered
  input reach follows the live row, and the hover margin includes its overflow.
  Icon layout, animation settings, scaling, and pointer-distance inputs are
  unchanged. The reveal strip inherits the stable glass width.
- Before implementation, `DockWidthTest` completed with 24 expected failures
  for hover-driven background resizing/movement in opaque and transparent
  modes. Its committed test source remained unchanged afterward.
- After implementation, all 61 new width/overflow checks and the existing
  dock magnification/response checks passed. The test observes intermediate
  width/position changes as well as settled geometry and clicks the launcher
  beyond the background's edge at maximum icon size and wave width.
- Full suite: 33 suites, 801 checks passed, zero failed. The hidden nested
  compositor used repository window rules, the unchanged branch window-plugin
  build, and two outputs. A test-profile copy supplied a generated wallpaper;
  all implementation and test files matched the working tree byte for byte.
  The compositor-reset persistence test ran last, as in the previous work.
- Background screenshots at rest, center hover, both edges, and exit retained
  the same glass box (x 141, width 998 in the default-size fixture), while the
  live row grew from 982 to 1021.6 pixels. A pixel scanline near the glass's
  bottom edge was byte-identical across all five captures.
- Actual pointer input on the nested socket kept hover active beyond both
  edges and opened the outer application's context menu and the overflowed
  launcher. Checks passed with 28 px and 48 px icons, maximum wave width, and
  transparent chrome. Drag reordering, auto-hide held open over overflow,
  hiding/revealing, and resizing when an application was unpinned/re-pinned
  also passed.
- `./tools/lint.sh` reported only established Quickshell type warnings;
  `git diff --check` passed. The isolated runtime and live shell's automatic
  reload logged no dock errors. No live-shell restart or workspace/focus
  switch was used. Temporary compositor instances and runtime rules were
  removed; no requested behavior or verification remains incomplete.
- Left `forge/dock-stable-width` unmerged and unpushed.
