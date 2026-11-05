# Window launch and close

Windows whose application already has a dock icon open with the existing
restore Genie. Closing a window with a current dock target uses the minimize
Genie. Without a target, windows fade in and out at their final geometry, on
the shell's fade timing and curve. Launch source means an icon present before
the window maps; an unpinned application's first launch therefore fades.

DockRow publishes application identities as well as live window addresses
through Compositor's existing atomic target snapshots. The window plugin
chooses a target once at map/unmap, on that window's monitor. Address targets
take precedence; application identities cover pins without windows and new
windows of an already running application. No launch dispatch changes.

Reuse CGenie for presentation only. A closing transition detaches its image
from the dead client and keeps its captured privacy policy, monitor and
workspace until completion. Close during opening/minimize reverses or
continues the existing image without showing the native fade underneath.
Capture launch on its first render, after the surface tree has mapped, using
its focused appearance. A pure fade must finish the native map-end callbacks
even without geometry motion, so later resizing still uses windowsMove.
Missing snapshots, hidden workspaces, removed monitors, disabled animations,
no-animation window rules, config reload and plugin unload release images
without delaying or changing the real action.

Verification: DockTargetsTest covers pre-map identities, resting geometry,
reorder and removal. WindowAnimationTest checks effective fade styles/tokens.
WindowLifecycleTest captures opening/closing Genie, full-size fallback fades,
close during opening, reduced motion and detached-image cleanup in nested
Hyprland. Existing Genie, blur and window-mode suites guard their behavior.

Verification: 11 focused suites passed, including dock lifecycle, presence and
menu coverage. The final release binary passed WindowLifecycleTest and
WindowGenieTest again. Sixteen additional native checks passed for atomic
target validation, address precedence, no-animation rules, and cancellation
on reduced motion, reload, unload and monitor removal. The official plugin
build and tools/lint.sh pass (only the documented Quickshell type warnings).
The tested binary is enabled in the session; its fades read back as 180 ms
on windowsStandard, Genie as 373 ms with 22 ms exposure, and the restarted
shell has no unexpected runtime messages or compositor configuration errors.
