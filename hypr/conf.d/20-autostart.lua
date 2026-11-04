--################
--## AUTOSTART ###
--################

hl.on("hyprland.start", function()
    hl.exec_cmd("hyprpaper")
end)
-- The task manager's tasks "At login" (systemd/quickshell-login.target), with
-- the session's display in the user manager's environment first, so that a
-- task, or one on a timer later, can open a window.
hl.on("hyprland.start", function()
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE && systemctl --user restart quickshell-login.target")
end)
--exec-once = hyprctl keyword debug:vfr false
