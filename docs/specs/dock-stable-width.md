# Stable dock footprint during magnification

## Goal

The user's before/after screenshots clarify that the visible icon row itself
must keep its resting width, including when the background is transparent.
The previous background-only fix was insufficient. This correction supersedes
allowing the icon row to expand past the glass.

## Plan and contract

1. Keep the icon row and its outer artwork bounds fixed during center/edge
   hover and exit. Reclaim magnification growth from the existing gaps;
   maintain a small clear artwork gap, the original cursor-distance inputs,
   bottom alignment, 120% cap, timing/settings, and component identities.
   Short rows limit effective growth to what fits without overlap. Actual
   application arrivals/departures and icon/chrome settings can still resize
   the dock. Keep the launcher divider centered in the remaining artwork gap.
   Files: `modules/dock/DockRow.qml`, `DockSlot.qml`, `DockButton.qml`, and
   `DockPanel.qml`.
2. Before implementation, update the earlier row-growth/overflow assertions
   to the corrected requirement and add `tests/DockFootprintTest.qml` for
   center/edge/exit, artwork bounds, separation, and one/zero application
   rows. Run these red for the width error, commit, and keep them unchanged
   during implementation.
3. Run regression/full-suite/lint checks and background-only visual/input
   checks on opaque/transparent docks. Compare the first/last icon bounds
   as well as the glass; verify click, drag, auto-hide, and real list changes.
   Use the established hidden nested compositor and wallpaper fixture. Do
   not switch the user's workspace/focus or restart their live shell.

The geometry is one coupled subtask on `forge/dock-stable-width`; no parallel
workers/worktrees are needed. Leave this branch unmerged and unpushed.

## Verification

The corrected footprint test reproduces 18 width/right-artwork-bound failures
on the previous implementation. The revised existing tests also reproduce
row expansion. Final verification is pending.
