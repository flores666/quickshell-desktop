-- The shell's own integration; installed as the named config "shell".
require(os.getenv("HOME") .. "/.config/quickshell/shell/hyprland.lua")

-- Super+S remains the scratchpad; quick settings is on the bar.
hl.unbind("SUPER + S")
hl.bind("SUPER + S", hl.dsp.workspace.toggle_special("magic"))
