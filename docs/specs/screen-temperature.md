# Screen temperature in quick settings

- Night Light sits below the color choices in Dark Style's Colors sub-page,
  with a labeled switch, current Kelvin value, and a warmth slider. Warmer is
  to the right (6500–2500 K, 100 K steps).
- The initial choice is off at 4500 K. Turning it off restores the identity
  color matrix and keeps the chosen warmth; both preferences survive restart.
- The service owns hyprsunset, with the project's empty config so a separate schedule
  cannot override the shell. Hyprsunset applies to every output, including
  monitors connected later. Its package is installed by the existing installer.
- A per-compositor file lock serializes backend lifetimes across shell
  reloads/restarts, waiting on the old process rather than racing CTM ownership.
  A kernel parent-death signal also releases the CTM when qs exits abruptly.
- Writes begin at the backend's socket-ready event and coalesce rapid changes.
  A lost backend clears availability, retains intent, rejects obsolete replies,
  and retries when quick settings next opens. Missing/failed backends hide
  the control, as with other unavailable controls outside the front page.
- Reuse Slider, MenuRow and ToggleSwitch for pointer and keyboard interaction.
  The wheel scrolls; it never changes temperature. No scheduling or gamma UI.

`NightLightTest` checks readiness, preference validation, drag coalescing,
toggle/identity behavior, persistence, backend loss and replacement, obsolete
replies, rejected commands and a missing executable with private command
fixtures. Check the actual control and CTM application in a nested Hyprland;
run the lint wrapper and inspect the live shell's startup log.
