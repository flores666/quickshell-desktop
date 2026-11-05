# Window launch and close

Windows whose application already has a dock icon open with the existing
restore Genie. Closing a window uses the minimize Genie only when its
application is pinned in the dock. An unpinned application fades out at its
final geometry, even while its temporary running icon is present. Without a
launch target, windows fade in at their final geometry, on the shell's fade
timing and curve. Launch source means an icon present before the window maps;
an unpinned application's first launch therefore fades.

DockRow publishes application identities as well as live window addresses
and pinned membership through Compositor's existing atomic target snapshots.
The window plugin chooses a target once at map/unmap, on that window's monitor.
Address targets take precedence; application identities cover pins without windows and new
windows of an already running application. Minimize/restore use both pinned
and temporary icons. Close rechecks current pin membership, including during
an existing Genie, and a missing membership flag means unpinned. No launch
dispatch changes.

Reuse CGenie for presentation only. A closing transition detaches its image
from the dead client and keeps its captured privacy policy, monitor and
workspace until completion. While the application remains pinned, close
during opening/minimize reverses or continues the existing image without
showing the native fade underneath.
Capture launch on its first render, after the surface tree has mapped, using
its focused appearance, including the shadow at its final strength: finish
that window's native startup shadow fade before capture so the same shadow
deforms with the image throughout the animation and stays at hand-back.
A pure fade must finish the native map-end callbacks even without geometry
motion, so later resizing still uses windowsMove.
Missing snapshots, hidden workspaces, removed monitors, disabled animations,
no-animation window rules, config reload and plugin unload release images
without delaying or changing the real action.

Verification: DockTargetsTest covers pre-map identities, pinned membership,
resting geometry, reorder and removal. WindowAnimationTest checks effective
fade styles/tokens.
WindowLifecycleTest captures opening/closing Genie, full-size fallback fades,
close during opening, reduced motion and detached-image cleanup in nested
Hyprland, including unpinned close and visible shadows during launch/close.
WindowGenieTest checks shadows during minimize/restore as well. Existing blur
and window-mode suites guard their behavior.

Verification: 11 focused suites passed, including dock lifecycle, presence and
menu coverage. The final release binary passed WindowLifecycleTest and
WindowGenieTest again. Sixteen additional native checks passed for atomic
target validation, address precedence, no-animation rules, and cancellation
on reduced motion, reload, unload and monitor removal. The official plugin
build and tools/lint.sh pass (only the documented Quickshell type warnings).
The tested binary is enabled in the session; its fades read back as 180 ms
on windowsStandard, Genie as 373 ms with 22 ms exposure, and the restarted
shell has no unexpected runtime messages or compositor configuration errors.

Shadow/pin follow-up: the new frame checks reproduced a missing launch shadow
and an unpinned close incorrectly using Genie before the fix. Nine focused
suites now pass, including shadow coverage for launch, close, minimize and
restore, unpinned full-width fades, reversals, reduced motion, dock lifecycle
and window modes. The scratch build and lint pass; saved frames were checked
visually. The exact tested binary is active in the session, with no unexpected
runtime messages or config errors and no existing window geometry/mode changes.
