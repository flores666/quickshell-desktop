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

The corrected footprint test reproduced 18 width/right-artwork-bound failures
on the previous implementation. Revised existing tests also reproduced row
expansion. Their committed contract was unchanged during implementation.

Magnification now spends the existing gap space instead of adding width to
the row. The fit calculation reads raw animated scales and presence only,
then provides bounded scales and gap reduction, keeping layout out of the
pointer-distance calculation. The divider follows the actual artwork gap.

Verification completed:

- Full suite: 34 suites, 897 checks passed, zero failed, in hidden nested
  Hyprland with the established repository window configuration and wallpaper
  fixture. Test files matched the checkout byte for byte; the persistence
  case ran last. No tests were edited after the corrected contract commit.
- The footprint regression covers center/edge hover and exit with nine,
  one, and zero application icons. It checks row width, first/last transformed
  artwork bounds, clear gaps, scale caps, and retained components. Existing
  response-time, settings/persistence, geometry, and input checks pass too.
- Transparent-dock rest/hover/exit captures had identical visible pixel
  bounds, x=152 through x=1121. The row width stayed 982 logical pixels, with
  transformed artwork bounds x=151 through x=1129 in all three states.
- Background-only pointer checks covered opaque/transparent docks, 28/48 px
  icons, the broadest wave, edge context-menu/launcher clicks, drag reordering,
  and auto-hide/reveal. All passed, with no overlap or footprint growth.
- `./tools/lint.sh` reported only established Quickshell type warnings;
  `git diff --check` passed. Isolated runtime and live automatic-reload logs
  had no dock errors. No workspace/focus switches or live-shell restart were
  used. Temporary compositor instances and runtime rules were removed.

No requested behavior or verification remains incomplete. The branch stays
unmerged and unpushed.
