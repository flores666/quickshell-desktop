-- Shell — Hyprland integration
--
--   require(os.getenv("HOME") .. "/.config/quickshell/shell/hyprland.lua")
--
-- from the desktop's Hyprland config, hypr/conf.d/90-quickshell.lua. Everything
-- below assumes the shell is reachable as the named config "shell", which
-- install.sh sets up: ~/.config/quickshell/shell links to this checkout.

-- The shell runs as its own user unit rather than as a child of the compositor.
-- Capped, so a shell that runs away is killed and restarted instead of dragging
-- the whole machine into swap — it once grew at ~85 MB/s until the power button
-- was the only way out. Logged to the journal (`journalctl --user -u
-- quickshell`), which survives that reboot where /run/user does not. The
-- variables Hyprland sets are passed through by name, so the unit never sees
-- the user manager's copy from before this session. The log rule silences Qt
-- warning, on every popup close, that it is disabling text input for a surface
-- the compositor never gave text input; see AGENTS.md. QML_IMPORT_PATH is where
-- the shell's native module is (tools/build-native-module.sh), rebuilt by the
-- second line after a Qt update; a shell without it still runs.
hl.on("hyprland.start", function()
    hl.exec_cmd("systemd-run --user --unit=quickshell --collect -p PartOf=graphical-session.target -p Restart=on-failure -p RestartSec=1 -p MemoryMax=1536M -p MemorySwapMax=0 -E WAYLAND_DISPLAY -E HYPRLAND_INSTANCE_SIGNATURE -E XCURSOR_SIZE -E HYPRCURSOR_SIZE -E QML_IMPORT_PATH=$HOME/.local/share/quickshell-desktop/qml qs -c shell --log-rules qt.qpa.wayland.textinput.warning=false")
end)
hl.on("hyprland.start", function()
    hl.exec_cmd("systemd-cat -t quickshell-native ~/.config/quickshell/shell/tools/build-native-module.sh --if-stale")
end)

-- ------------------------------------------------------------------ plugins
-- Load only a build stamped for the running release. The login checks rebuild
-- after a Hyprland update or a change to the sources/overview patches.
local data = os.getenv("XDG_DATA_HOME") or (os.getenv("HOME") .. "/.local/share")
local function loadPlugin(directory, binary)
    local stamp = io.open(data .. "/" .. directory .. "/built-for", "r")
    if not stamp then return end
    local version = (stamp:read("*l") or ""):match("^(%S+)")
    stamp:close()
    if version == hl.version():gsub("^v", "") then
        hl.plugin.load(data .. "/" .. directory .. "/" .. binary)
    end
end
-- The overview owns input first, then the window decorations.
loadPlugin("hyprexpo", "hyprexpo.so")
loadPlugin("hypr-windows", "windows.so")
hl.on("hyprland.start", function()
    hl.exec_cmd("systemd-cat -t hyprexpo ~/.config/quickshell/shell/tools/build-overview-plugin.sh --if-stale; systemd-cat -t hypr-windows ~/.config/quickshell/shell/tools/build-windows-plugin.sh --if-stale")
end)

if hl.plugin.hyprexpo then
    hl.config({ plugin = { hyprexpo = {
        columns = 3,
        gaps_in = 10,
        gaps_out = 24,
        skip_empty = 0,
        dynamic_grid = 1,
        workspace_method = "center current",
        show_workspace_numbers = 1,
        show_cursor = 1,
        wallpaper_bg = 1,
        gesture_fingers = 3,
        gesture_direction = "up",
    } } })
end
-- Colors, rounding and title-bar timings come from CompositorTheme.qml.

-- --------------------------------------------------------------------- keys
--
-- The shell registers these over the hyprland-global-shortcuts protocol, so the
-- binds below cost nothing at press time — no process is spawned.

hl.bind("SUPER + R", hl.dsp.global("shell:launcher"))
-- Straight to the compositor: works even when the shell is not running.
hl.bind("SUPER + Tab", function() if hl.plugin.hyprexpo then hl.plugin.hyprexpo.expo("toggle") end end)

-- Alt+Tab goes round the windows of the workspace, as Command-Tab does on
-- macOS (services/Switcher.qml): the shell keeps the order and draws it,
-- Hyprland holds the keys. Alt+Tab steps and enters the `switcher` submap,
-- where Tab, Alt+` and the arrows step and Escape cancels — only while it is
-- open; not Alt+Shift+Tab, since Alt+Shift switches the keyboard layout
-- (60-input.lua). Letting go of Alt commits. A key's release is matched in the submap it
-- was pressed in, and Alt went down before Tab, so those binds are the main
-- map's: they fire on every Alt release, and the shell ignores the ones that
-- end nothing. They are transparent (t): once another key goes down with Alt
-- (Tab), Hyprland shadows every other bind on Alt's own key — how a
-- `bindr = SUPER, SUPER_L` stays out of Super+key — and the submap was never
-- left. Each pair runs the global first: Hyprland stops collecting a key's
-- binds at the one that changes submap.
hl.bind("ALT + Tab", hl.dsp.global("shell:switcherNext"))
hl.bind("ALT + Tab", hl.dsp.submap("switcher"))
hl.bind("ALT + ALT_L", hl.dsp.global("shell:switcherCommit"), { release = true, transparent = true })
hl.bind("ALT + ALT_L", hl.dsp.submap("reset"), { release = true, transparent = true })
hl.bind("ALT + ALT_R", hl.dsp.global("shell:switcherCommit"), { release = true, transparent = true })
hl.bind("ALT + ALT_R", hl.dsp.submap("reset"), { release = true, transparent = true })

hl.define_submap("switcher", function()
hl.bind("ALT + Tab", hl.dsp.global("shell:switcherNext"))
hl.bind("ALT + right", hl.dsp.global("shell:switcherNext"))
hl.bind("ALT + grave", hl.dsp.global("shell:switcherBack"))
hl.bind("ALT + left", hl.dsp.global("shell:switcherBack"))
hl.bind("ALT + Escape", hl.dsp.global("shell:switcherCancel"))
hl.bind("ALT + Escape", hl.dsp.submap("reset"))
end)

hl.bind("SUPER + S", hl.dsp.global("shell:quickSettings"))
hl.bind("SUPER + N", hl.dsp.global("shell:dateMenu"))
hl.bind("SUPER + comma", hl.dsp.global("shell:settings"))
hl.bind("CTRL + SHIFT + Escape", hl.dsp.global("shell:taskManager"))
hl.bind("SUPER + L", hl.dsp.global("shell:lock"))
hl.bind("SUPER + SHIFT + T", hl.dsp.global("shell:toggleTheme"))
hl.bind("SUPER + SHIFT + N", hl.dsp.global("shell:toggleDnd"))

-- Popups close on a click outside them. `bindn` is non-consuming, so the click
-- still reaches whatever is under it and the desktop stays fully interactive
-- while a popup is open — the shell only listens, it never captures the pointer.
hl.bind("mouse:272", hl.dsp.global("shell:dismiss"), { non_consuming = true })
hl.bind("mouse:273", hl.dsp.global("shell:dismiss"), { non_consuming = true })
hl.bind("ESCAPE", hl.dsp.global("shell:escapeKey"), { non_consuming = true })

-- Print is what Fn+P sends on a keyboard without a dedicated key.
hl.bind("Print", hl.dsp.global("shell:screenshotRegion"))
hl.bind("SHIFT + Print", hl.dsp.global("shell:screenshot"))

-- bindl keeps these working while the session is locked.
hl.bind("XF86AudioRaiseVolume", hl.dsp.global("shell:volumeUp"), { locked = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.global("shell:volumeDown"), { locked = true })
hl.bind("XF86AudioMute", hl.dsp.global("shell:volumeMute"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.global("shell:micMute"), { locked = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.global("shell:brightnessUp"), { locked = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.global("shell:brightnessDown"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.global("shell:playPause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.global("shell:next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.global("shell:previous"), { locked = true })

-- ------------------------------------------------------------------- layout
--
-- The bar and the dock reserve their own space through layer-shell exclusive
-- zones, so no manual gaps are needed. These only affect the shell's own
-- surfaces; they are named "shell-<surface>".

-- Every layer rule explicitly matches its full namespace.

-- Glass. Every shell surface is blurred behind wherever it is more than half
-- opaque. The panels are drawn at the theme's glass opacity, well above that, and
-- the shadows around them well below it, so the frost stops at a panel's edge —
-- a popup's surface is mostly empty, and none of the empty part is blurred. The
-- bar and the dock lay down a share of that glass the user sets; below about
-- 57% of it they are clear, unblurred (Appearance.barOpacity).
hl.layer_rule({
    name = "shell-glass",
    match = { namespace = "shell-.*" },
    blur = true,
    ignore_alpha = 0.5,
})

-- Popups draw their own coming and going, all in the one surface
-- (modules/common/OverlaySurface), and one opened over another flies in from
-- where that one was (OverlayCard). Hyprland would fade the surface in as it
-- maps (fadeLayersIn), over the card's own fade.
hl.layer_rule({
    name = "shell-popups",
    match = { namespace = "shell-popups" },
    no_anim = true,
})

-- The polkit agent's password prompt (modules/polkit/AuthWindow) comes up over
-- the popup that asked for it, the task manager applying earlyoom's options,
-- and draws its own fade. A layer is drawn above every one of a higher order,
-- and the popups' surface is 0; it maps afresh each time a popup opens, and
-- among equals the newer surface would be on top.
hl.layer_rule({
    name = "shell-auth",
    match = { namespace = "shell-auth" },
    no_anim = true,
    order = -1,
})

-- The window switcher's card fades and slides as a popup's does
-- (modules/switcher/SwitcherWindow).
hl.layer_rule({
    name = "shell-switcher",
    match = { namespace = "shell-switcher" },
    no_anim = true,
})

hl.layer_rule({
    name = "shell-osd",
    match = { namespace = "shell-osd" },
    animation = "none",
})

-- Screenshots. A region shot freezes the screen under hyprpicker, its lens off,
-- drags the rectangle out with slurp ("selection") over that, and has grim take
-- the frozen frame; see services/Screenshot.qml. Neither fades: the selection's
-- fade-out was still on screen when grim took the shot and framed every region
-- in its border. A layer is drawn beneath every one of a lower order, so a toast
-- or the OSD that opens meanwhile stays under the frozen screen, out of the shot.
hl.layer_rule({
    name = "screenshot-freeze",
    match = { namespace = "hyprpicker" },
    no_anim = true,
    order = -1,
})

hl.layer_rule({
    name = "screenshot-selection",
    match = { namespace = "selection" },
    no_anim = true,
    order = -2,
})
