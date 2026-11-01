# Dock hover follows the magnification mode

## Goal

When the dock's Magnification toggle is on, retain the 300 ms delay for the
hand cursor and app-name tooltip and remove every icon's circular background,
including hover, press, and active/selected fills. When it is off, remove that
hover delay and restore those backgrounds, for applications and Applications
alike.

## Traced behaviour

The preceding hover-delay implementation already supplies `Clickable.hoverDelay`,
an immediate raw pointer state, and the dock's shared 300 ms motion token.
`Clickable.showStateLayer` already controls the complete hover/press/selected
fill without changing interaction state. The dock currently always requests
the delay and always draws that fill; its tooltip also always waits 300 ms.

The existing Magnification toggle is `Settings.dockMagnificationEnabled`.
Use that preference consistently, rather than a particular icon's animated
scale: an icon at rest still belongs to the enabled mode. The toggle continues
to select the enabled mode even if its zoom amount is set to zero.

## Plan

1. Bind dock hover timing and filled backgrounds to the magnification toggle.
   - Given Magnification on, an application icon or Applications keeps an
     arrow cursor and no name before 300 ms on the same icon; at 300 ms the
     hand activates and the name starts its existing fade. Magnification
     itself stays immediate. No hover, press, or selected circular fill is
     drawn at any point, including for an active application or open launcher.
   - Given Magnification off, the hand and hover state activate on entry and
     the name begins fading on the next delivered frame, with no 300 ms
     dwell. Hover, press, and selected backgrounds use their existing fades
     and colours. Icons retain their resting size.
   - Given the setting changes while the pointer is already over an icon,
     switching off enables hover/fills immediately and releases any pending
     name without an old delay. Switching on hides all fills immediately and
     begins a fresh 300 ms dwell for the hand and name; it never reuses stale
     activation or a timeout from the previous mode. Check both an early
     switch during a dwell and a switch after hover has activated.
   - Given movement between icons, re-entry, disabling an icon, clicks,
     keyboard activation, or drag reordering, preserve the previous hover
     cancellation and immediate-input behaviour. Window previews keep their
     existing raw tracking, 450 ms initial dwell, and immediate click action.
     Dock width, icon centres, and baselines remain fixed.
   - Given the enabled toggle with zero zoom, use the same delayed/no-fill
     mode; this rule follows the toggle consistently. Other shell controls
     and tooltip timing remain unchanged.
   - Reuse existing owners and properties; introduce no setting, duplicated
     hover logic, periodic timer, or new service.
   - Files: `modules/dock/DockItem.qml`, `DockButton.qml`, and `DockPanel.qml`;
     `components/Tooltip.qml` only if switching its delay while pending or
     visible requires a fix; `config/Motion.qml` only if its timing comment
     needs updating; `tests/DockHoverModeTest.qml` and the preceding
     `tests/DockHoverDelayTest.qml` for its superseded wash expectations.
   - Write tests first, run them red for the missing mode-dependent behaviour,
     and commit this spec and the tests. Keep that test contract unchanged
     during implementation.

2. Verify both modes and live setting changes in the background.
   - In nested Hyprland, check applications, Applications, an active app,
     press/selection, and setting changes during a dwell and after activation.
     Include visible/transparent chrome and supported icon-size extremes.
   - Before creating outputs, install hidden-workspace and no-initial-focus
     rules for `aquamarine`. Confirm every nested output remains hidden before
     input; never send input to the user's desktop or switch its workspace.
   - Run the focused mode/hover and existing dock checks, full suite,
     `./tools/lint.sh`, and `git diff --check`; inspect runtime logs without
     restarting the user's shell. Remove task-created processes, windows,
     and temporary compositor rules, recording any environmental limitations.
   - Files: this spec records verification results.

## Execution

Use one dependent subtask directly on `forge/dock-hover-magnification-mode`;
no parallel workers or worktrees are needed. This branch starts from the
completed, unmerged `forge/dock-hover-delay` work. Leave it unmerged and
unpushed for review.

## Verification results

- Completed both plan items using the existing controls: dock hover delay and
  state-layer visibility now follow the Magnification toggle, as does its
  tooltip delay. `Tooltip` restarts an already-shown or pending subject when
  its delay changes, so stationary-pointer switches apply consistently.
  No setting, service, or timer was added.
- Tests were committed before implementation with 46 expected failures:
  44 mode/transition failures and two superseded background checks. That
  committed test contract was unchanged during implementation.
- All six dock suites passed, followed by the full suite: 35 suites and
  1,213 checks passed, zero failed. The scratch profile supplied a generated
  wallpaper for the backdrop test; its code and test files matched the
  checkout byte for byte.
- Rendered checks passed for applications and Applications at 28 px and
  48 px, with transparent and visible chrome. Enabled mode retained the
  delayed hand/name and immediate magnification, with no fill drawn; disabled
  mode gave immediate hand/name and normal fills without magnification.
  Widths and centres stayed fixed.
- A real active kitty verified the active/selected fill, and real presses
  and an open launcher verified press and selection in both modes. Switching
  during a dwell and after activation worked without moving the pointer.
  Enabled zero-zoom mode, keyboard activation, and drag reordering before
  the dwell completed also passed.
- `./tools/lint.sh` reported only the existing Qt/Quickshell type warnings;
  `git diff --check` passed. The isolated runtime log and live reload log
  were clean. The live shell remained active and was not restarted.
- Both nested output windows stayed on the hidden workspace throughout;
  no foreground test window or desktop input was used. Test windows,
  processes, and temporary compositor rules were removed, and the frame-rate
  override was restored.
