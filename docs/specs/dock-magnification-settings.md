# Dock magnification settings

## Goal

Add all four requested controls to Settings → Dock: magnification on/off,
zoom amount, response time, and wave width. Preserve the current appearance
and response as the defaults, retain the strict 120% scale ceiling, and keep
all testing and visual inspection in the background.

## Plan

1. Implement persisted controls and connect them to the dock.
   - Add a Magnification group in the existing Dock section, using the
     existing toggle, numeric setting rows, and per-row reset controls.
   - Defaults reproduce the current enabled effect: 20% zoom, 120 ms response,
     and 100% wave width (the existing Gaussian spread). Zoom offers 0–20%,
     response time 40–300 ms, and wave width 50–200% of the current width.
   - Given magnification disabled, the dock smoothly returns to its resting
     sizes and spacing; the three numeric controls are hidden. Re-enabling
     restores the chosen numeric values and resumes following the pointer.
   - Given a zoom, width, or response change, the dock applies it live without
     recreating icons. Application icons and the launcher share the selected
     response time; their maximum scale never exceeds 1.2.
   - Given zoom 0%, hovering leaves icons at their original size. Given a
     narrower/wider wave, neighbor magnification decreases/increases while
     the peak stays at the chosen zoom amount.
   - Given a value outside its supported range in settings.json, the same
     clamp that defines the slider bounds protects the runtime value.
   - Given save/reload, all four choices persist. Missing keys use today's
     defaults. A row reset restores its tuned number; Reset all restores all
     three numbers while preserving the on/off preference, matching the
     repository's existing reset policy.
   - Continue deriving distances from original icon positions, allocating
     space from animated growth, keeping the bottom baseline stable, and
     using event-driven updates without polling.
   - Files: `services/SettingsStore.qml`, `services/Settings.qml`,
     `services/Dock.qml`, `config/Tuning.qml`, `config/Metrics.qml`,
     `modules/dock/DockRow.qml`, `DockSlot.qml`, `DockButton.qml`,
     `modules/settings/DockSection.qml`, and `profile/settings.json` as needed.
     Layout limits belong to Tuning; response limits belong to Dock.
   - Add regression tests in `tests/DockMagnificationSettingsTest.qml` for
     defaults, clamping, persistence, reset policy, live wave behavior, and
     settings controls. Run them before implementation, confirm failures are
     due to missing behavior, and commit this spec plus the red tests.

2. Verify settings and dock behavior in the background.
   - In a hidden nested compositor, inspect screenshots of the Magnification
     group enabled/disabled and exercise its controls with synthetic input.
     Verify lower zoom, narrower/wider waves, and faster/slower response on
     the actual dock, including the launcher and transparent chrome.
   - Run the new regression tests, the existing dock tests, the full test
     suite, `./tools/lint.sh`, and `git diff --check`. Keep committed tests
     unchanged during implementation.
   - Use the established nested test setup with repository window rules, a
     scratch build of the window plugin, and a test wallpaper fixture where
     required. Do not open test windows on the user's workspace, change their
     focus, or restart their live shell. Inspect isolated runtime logs and
     the live shell's automatic-reload log.
   - Remove temporary compositor instances and runtime test rules, and
     record final verification here.

## Execution

State, controls, and dock behavior form one coupled implementation subtask.
Work on `forge/dock-magnification-settings` from the current response-fix
branch; no parallel workers or worktrees are needed. Leave the final branch
unmerged and unpushed.

## Verification results

Pending.
