# Fixed dock width during magnification

## Goal

Keep the dock at exactly its resting width when the pointer enters, moves
across it, shows a tooltip, or leaves. Retain the existing configurable icon
magnification, while keeping the dock centred and each icon at its resting
horizontal centre.

## Traced behaviour

`DockSlot.width` includes the application's animated magnification growth,
and `DockButton.implicitWidth` includes the launcher's growth. `DockRow` lays
out those changing widths; `DockPanel` sizes the glass and reveal strip from
that row. The tooltip is outside the row and does not contribute to its size.
The existing magnification test explicitly expects row growth, so that old
expectation must be replaced before implementation.

## Plan

1. Separate magnified artwork from the horizontal layout footprint.
   - Given an unchanged application list and icon-size setting, entering,
     moving across, and leaving the dock keeps the row width, dock glass
     width, and reveal-strip width equal to their resting values throughout
     the animation. Showing an application tooltip changes none of them.
   - Given a pointer over the first, middle, or last application, or the
     launcher, application centres and the launcher centre stay at their
     resting horizontal positions. Magnification keeps its current wave,
     configured duration, strict 120% maximum, and fixed artwork baseline.
   - Given supported icon sizes and maximum magnification, neighbouring
     artwork remains separated. Both application icons and the launcher
     remain usable, including their magnified upper edge; tooltips and
     previews remain anchored to the corresponding icon centre.
   - Given magnification disabled or zoom set to zero, icons retain their
     resting geometry. Adding or removing an application still changes the
     dock's width through its existing presence animation; changing icon
     size still updates its width. Drag reordering keeps its existing stride.
   - Files: `modules/dock/DockSlot.qml`, `DockItem.qml`, `DockButton.qml`,
     `DockRow.qml`, and `DockPanel.qml` as needed; `tests/DockMagnificationTest.qml`
     and a focused `tests/DockFixedWidthTest.qml`. Reuse the existing design
     tokens and magnification animator; introduce no new settings or polling.
   - Before implementation, replace the obsolete growth expectation and add
     regression checks. Run them red for width/position failures, then commit
     this spec and the tests. Keep that test contract unchanged afterward.

2. Verify the rendered dock and desktop regressions.
   - In an isolated nested Hyprland session, verify hover and tooltip entry,
     horizontal movement, exit, launcher activation, and drag reordering.
     Check transparent and visible chrome and the smallest and largest
     supported icon sizes without disturbing the user's desktop.
   - Run the dock regression tests, the full existing test suite,
     `./tools/lint.sh`, and `git diff --check`. Inspect the runtime log before
     claiming completion; record any environmental failures separately.
   - Files: this spec records verification results; no independent code files.

## Execution

Both items follow the same dock layout change and are sequential. Use one
subtask directly on `forge/dock-fixed-width`; no workers or worktrees are
needed. Leave the branch unmerged and unpushed.

## Verification results

- Completed both plan items. Application slots and the launcher keep their
  resting horizontal footprint. Their clickable areas still extend upward
  with the magnified artwork; centres, dots, and the artwork baseline stay
  fixed. The existing animator, wave settings, and presence animation remain
  responsible for their existing behaviour.
- Before implementation, the committed tests reported 199 expected failures:
  row/glass/reveal widths, horizontal centres, and tooltip/launcher anchors.
  Magnification, artwork spacing, bottom baselines, upper-edge input, and
  application removal/arrival passed. The committed tests were unchanged
  during implementation.
- All four dock suites passed after implementation. The final full run
  passed all 33 suites and 1,044 checks, with zero failures. It ran in nested
  Hyprland with the branch's window plugin and two working Wayland outputs.
  A scratch copy supplied a generated wallpaper in its profile for the
  backdrop test; all code and test files matched the checkout byte for byte.
- The initial nested headless outputs could not allocate NVIDIA buffers.
  An initial full run had three hand-off failures in `CardFlightTest` while
  rendering was stalled. After replacing those outputs, the entire suite,
  including that test, passed without modifying tests or popup code.
- Rendered checks covered entry, tooltip dwell, travel in both directions,
  exit, 28 px and 48 px icons, and transparent and visible chrome. The row
  stayed at 487 px, and the glass and reveal strip at 503 px, through the
  full hover sequence. First/middle/last applications and the launcher
  reached 120%; launcher activation and a drag from slot 2 to slot 4 worked.
- `./tools/lint.sh` completed with the existing Qt/Quickshell type warnings;
  `git diff --check` passed. The isolated runtime log was clean with the
  native module loaded, and the live service's latest reload log was clean.
  The live service stayed active and was not restarted.
- Additional nested output windows initially appeared on the user's desktop.
  They were moved to the hidden test workspace immediately when reported;
  subsequent checks confirmed both outputs stayed there. All task-created
  compositor/preview/capture processes and windows were removed at the end,
  and temporary compositor rules and the frame-rate override were cleared.
