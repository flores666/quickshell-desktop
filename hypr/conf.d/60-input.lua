--############
--## INPUT ###
--############

hl.config({
    input = {
        kb_layout = "us,ru",
        kb_variant = "",
        kb_model = "",
        -- Alt+Shift and Super+Space both cycle the layout.
        kb_options = "grp:alt_shift_toggle,grp:win_space_toggle",
        kb_rules = "",

        follow_mouse = 1,

        sensitivity = 0,
        accel_profile = "flat",

        touchpad = {
            natural_scroll = true,
            tap_to_click = true,
            tap_and_drag = true,
            disable_while_typing = true,
        },
    }
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- Hyprland's defaults (300px of travel, a flick at 30 forces the switch) jump a
-- workspace on the slightest swipe.
hl.config({
    gestures = {
        workspace_swipe_distance = 700,
        workspace_swipe_min_speed_to_force = 60,
    }
})

-- The global flat profile keeps the mouse precise but would make a touchpad
-- crawl: the shell finds the touchpad and gives it adaptive acceleration
-- (services/CompositorOptions.qml), with the speed from its settings panel.
-- Tuning for one machine's own mouse or touchpad is that machine's: a device
-- block in its own ~/.config/hypr/hyprland.lua.
