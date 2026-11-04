-- Neovim help popup
-- Works only when the active window has nvim in its process tree.

hl.window_rule({ match = { title = "^nvim-help$" }, float = true })
hl.window_rule({ match = { title = "^nvim-help$" }, size = "1100 760" })
hl.window_rule({ match = { title = "^nvim-help$" }, center = true })
