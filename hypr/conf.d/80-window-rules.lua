--#############################
--## WINDOWS AND WORKSPACES ###
--#############################

-- Windows open floating. The window plugin (hypr/windows, Placement) gives
-- each application the size it was last left at, or tiles it if it was last
-- tiled, and finds this rule by its name. It comes first so that any later
-- rule — float, tile, size, move, center — is the one that speaks; a window
-- such a rule matches is left to it and not remembered.
hl.window_rule({
    name = "float-by-default",
    match = {
        class = ".*",
    },

    float = true,
})

hl.window_rule({
    name = "suppress-maximize-events",
    match = {
        class = ".*",
    },

    suppress_event = "maximize",
})

hl.window_rule({
    name = "fix-xwayland-drags",
    match = {
        class = "^$",
        title = "^$",
        xwayland = true,
        float = true,
        fullscreen = false,
        pin = false,
    },

    no_focus = true,
})

hl.window_rule({
    name = "move-hyprland-run",

    match = {
        class = "hyprland-run",
    },

    move = "20 monitor_h-120",
    float = true,
})
