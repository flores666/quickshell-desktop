-- Hyprland 0.57 uses Lua. require tracks every sourced file for reloads.
-- The machine's ~/.config/hypr/hyprland.lua requires this, then applies its
-- own monitor/device settings and application overrides.
require(os.getenv("HOME") .. "/.config/quickshell/shell/hypr/conf.d/*.lua")
