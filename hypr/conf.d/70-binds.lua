-- Applications, focus, workspaces and window dragging.
hl.bind("SUPER + W", hl.dsp.exec_cmd("kitty"))
hl.bind("SUPER + Q", hl.dsp.window.close())
hl.bind("SUPER + E", hl.dsp.exec_cmd("nautilus"))
hl.bind("SUPER + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind("SUPER + J", hl.dsp.layout("togglesplit"))
hl.bind("SUPER + H", hl.dsp.exec_cmd('bash -lc "$HOME/.local/bin/nvim-help"'))
hl.bind("SUPER + B", hl.dsp.exec_cmd("zen-browser"))

for _, direction in ipairs({ "left", "right", "up", "down" }) do
    hl.bind("SUPER + " .. direction, hl.dsp.focus({ direction = direction }))
end
for workspace = 1, 10 do
    local key = workspace % 10
    hl.bind("SUPER + " .. key, hl.dsp.focus({ workspace = workspace }))
    hl.bind("SUPER + SHIFT + " .. key, hl.dsp.window.move({ workspace = workspace }))
end
hl.bind("SUPER + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind("SUPER + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })
-- Screenshots, media keys and the OSD belong to the shell (90-quickshell.lua).
