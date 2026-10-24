-- Neovim config for C#, C and Go development.
-- Put this file into ~/.config/nvim/init.lua
--
-- Formatting and refactoring NEVER run on their own. Nothing is reformatted on
-- save or when leaving insert mode. Every rewrite of the buffer happens only
-- because you pressed a key. See the "Rider refactoring keymaps" section at the
-- bottom of this file for the full list.
--
-- The style those commands produce mirrors JetBrains Rider defaults. The rules
-- live in ~/.config/nvim/rider/ (clang-format.yaml, csharpier.json) and in the
-- rider_style table below, so nvim, clang-format and csharpier all agree.

vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.signcolumn = "yes"
vim.opt.termguicolors = true
vim.opt.cursorline = true
vim.opt.updatetime = 150
vim.opt.timeoutlen = 400
vim.opt.smartindent = true
vim.opt.wrap = false
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.undofile = true
vim.opt.completeopt = { "menu", "menuone", "noselect" }
vim.opt.clipboard = "unnamedplus"
vim.opt.showmode = false
vim.opt.laststatus = 3

-- Rider code style ----------------------------------------------------------
-- indent: spaces (or tab width) per level, exactly Rider's "Tab and Indents".
-- tabs:   Rider's "Use tab character".
-- margin: Rider's right-margin guide; the formatters wrap at the same column.
-- Rider never hard-wraps while you type, so 'textwidth' stays 0 everywhere.
local rider_style = {
  cs = { indent = 4, tabs = false, margin = 120 },
  c = { indent = 4, tabs = false, margin = 120 },
  cpp = { indent = 4, tabs = false, margin = 120 },
  go = { indent = 4, tabs = true, margin = 120 },
  gomod = { indent = 4, tabs = true, margin = 120 },
  gosum = { indent = 4, tabs = true, margin = 120 },
  gowork = { indent = 4, tabs = true, margin = 120 },
  json = { indent = 2, tabs = false, margin = 120 },
  jsonc = { indent = 2, tabs = false, margin = 120 },
  xml = { indent = 2, tabs = false, margin = 120 },
  yaml = { indent = 2, tabs = false, margin = 120 },
  lua = { indent = 2, tabs = false, margin = 120 },
  markdown = { indent = 2, tabs = false, margin = 0 },
}

-- Defaults for filetypes not listed above: Rider's generic 4-space indent.
vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.textwidth = 0

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("rider_code_style", { clear = true }),
  callback = function(args)
    local style = rider_style[vim.bo[args.buf].filetype]
    if not style then
      return
    end

    vim.bo[args.buf].expandtab = not style.tabs
    vim.bo[args.buf].shiftwidth = style.indent
    vim.bo[args.buf].tabstop = style.indent
    vim.bo[args.buf].softtabstop = style.indent
    vim.bo[args.buf].textwidth = 0
    vim.opt_local.colorcolumn = style.margin > 0 and tostring(style.margin) or ""
  end,
})

-- Where clang-format and csharpier read the Rider rules from.
local rider_style_dir = vim.fn.stdpath("config") .. "/rider"

local function trim_empty_lines(lines)
  local first = 1
  local last = #lines

  while first <= last and lines[first]:match("^%s*$") do
    first = first + 1
  end

  while last >= first and lines[last]:match("^%s*$") do
    last = last - 1
  end

  local trimmed = {}
  for i = first, last do
    trimmed[#trimmed + 1] = lines[i]
  end

  return trimmed
end

local function open_centered_hover(err, result, _, _)
  if err then
    vim.notify(err.message or tostring(err), vim.log.levels.WARN)
    return
  end

  if not result or not result.contents then
    vim.notify("No documentation available", vim.log.levels.INFO)
    return
  end

  local ok, lines = pcall(vim.lsp.util.convert_input_to_markdown_lines, result.contents)
  if not ok or not lines then
    lines = {}
  end

  lines = trim_empty_lines(lines)
  if vim.tbl_isempty(lines) then
    vim.notify("No documentation available", vim.log.levels.INFO)
    return
  end

  local columns = vim.o.columns
  local rows = vim.o.lines - vim.o.cmdheight
  local max_width = math.max(48, math.floor(columns * 0.72))
  local max_height = math.max(8, math.floor(rows * 0.55))
  local width = 0

  for _, line in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(line))
  end

  width = math.min(math.max(width, 48), max_width)
  local height = math.min(#lines, max_height)

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].filetype = "text"

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].modifiable = false

  local winid = vim.api.nvim_open_win(bufnr, true, {
    relative = "editor",
    row = math.floor((rows - height) / 2),
    col = math.floor((columns - width) / 2),
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = " Docs ",
    title_pos = "center",
  })

  vim.wo[winid].wrap = true
  vim.wo[winid].linebreak = true
  vim.wo[winid].conceallevel = 0
  vim.wo[winid].winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder"

  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = bufnr, silent = true })
  vim.keymap.set("n", "<Esc>", "<cmd>close<cr>", { buffer = bufnr, silent = true })
end

vim.lsp.handlers["textDocument/hover"] = open_centered_hover

local function request_centered_hover()
  local clients = vim.lsp.get_clients({
    bufnr = 0,
    method = "textDocument/hover",
  })

  if vim.tbl_isempty(clients) then
    vim.notify("No LSP hover provider attached", vim.log.levels.INFO)
    return
  end

  local offset_encoding = clients[1].offset_encoding or "utf-16"
  local params = vim.lsp.util.make_position_params(0, offset_encoding)
  vim.lsp.buf_request(0, "textDocument/hover", params, open_centered_hover)
end

vim.api.nvim_create_user_command("LspHoverCentered", request_centered_hover, {})



-- Stable signature-help popup. It shows exactly one overload at a time and
-- avoids Markdown/Tree-sitter buffers used by lsp_signature.nvim.
local signature_state = {
  source_buf = nil,
  popup_buf = nil,
  popup_win = nil,
  signatures = {},
  index = 1,
  active_parameter = nil,
  request_id = 0,
}

local signature_namespace = vim.api.nvim_create_namespace("signature_help_popup")

local function close_signature_help()
  if signature_state.popup_win and vim.api.nvim_win_is_valid(signature_state.popup_win) then
    pcall(vim.api.nvim_win_close, signature_state.popup_win, true)
  end

  signature_state.popup_win = nil
end

local function text_offset_to_position(text, offset)
  offset = math.max(0, math.min(offset, #text))
  local before = text:sub(1, offset)
  local row = select(2, before:gsub("\n", ""))
  local last_newline = before:match(".*()\n") or 0
  return row, #before - last_newline
end

local function active_parameter_range(signature, parameter_index)
  if type(parameter_index) ~= "number" or type(signature.parameters) ~= "table" then
    return nil
  end

  local parameter = signature.parameters[parameter_index + 1]
  if not parameter then
    return nil
  end

  local label = signature.label or ""
  local parameter_label = parameter.label
  local start_offset
  local end_offset

  if type(parameter_label) == "string" then
    local first, last = label:find(parameter_label, 1, true)
    if first then
      start_offset = first - 1
      end_offset = last
    end
  elseif type(parameter_label) == "table"
    and type(parameter_label[1]) == "number"
    and type(parameter_label[2]) == "number"
  then
    start_offset = parameter_label[1]
    end_offset = parameter_label[2]
  end

  if not start_offset or not end_offset or end_offset <= start_offset then
    return nil
  end

  local start_row, start_col = text_offset_to_position(label, start_offset)
  local end_row, end_col = text_offset_to_position(label, end_offset)
  return start_row, start_col, end_row, end_col
end

local function render_signature_help()
  local signature = signature_state.signatures[signature_state.index]
  if not signature then
    close_signature_help()
    return
  end

  close_signature_help()

  local label = signature.label or "No signature available"
  local lines = vim.split(label, "\n", { plain = true })
  if vim.tbl_isempty(lines) then
    lines = { "No signature available" }
  end

  local current_width = vim.api.nvim_win_get_width(0)
  local max_allowed_width = math.max(30, math.floor(current_width * 0.90))
  local width = 1
  for _, line in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(line))
  end
  width = math.min(width, max_allowed_width)

  -- A signature usually arrives as one very long line. Neovim wraps that
  -- line visually, but the floating-window height must include the wrapped
  -- screen rows explicitly; otherwise only the first row is visible.
  local wrapped_height = 0
  for _, line in ipairs(lines) do
    local display_width = math.max(1, vim.fn.strdisplaywidth(line))
    wrapped_height = wrapped_height + math.max(1, math.ceil(display_width / width))
  end

  local available_height = math.max(2, vim.o.lines - vim.o.cmdheight - 4)
  local height = math.min(math.max(1, wrapped_height + 1), math.min(12, available_height))

  local popup_buf = signature_state.popup_buf
  if not popup_buf or not vim.api.nvim_buf_is_valid(popup_buf) then
    popup_buf = vim.api.nvim_create_buf(false, true)
    signature_state.popup_buf = popup_buf
  end

  vim.bo[popup_buf].buftype = "nofile"
  vim.bo[popup_buf].bufhidden = "hide"
  vim.bo[popup_buf].swapfile = false
  vim.bo[popup_buf].filetype = "text"
  vim.bo[popup_buf].modifiable = true
  vim.api.nvim_buf_set_lines(popup_buf, 0, -1, false, lines)
  vim.bo[popup_buf].modifiable = false

  vim.api.nvim_buf_clear_namespace(popup_buf, signature_namespace, 0, -1)

  local active_parameter = signature.activeParameter
  if type(active_parameter) ~= "number" then
    active_parameter = signature_state.active_parameter
  end

  local start_row, start_col, end_row, end_col =
    active_parameter_range(signature, active_parameter)

  if start_row then
    pcall(vim.api.nvim_buf_set_extmark, popup_buf, signature_namespace, start_row, start_col, {
      end_row = end_row,
      end_col = end_col,
      hl_group = "LspSignatureActiveParameter",
    })
  end

  local total = #signature_state.signatures
  signature_state.popup_win = vim.api.nvim_open_win(popup_buf, false, {
    relative = "cursor",
    row = 1,
    col = 0,
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = string.format(" Signature %d/%d ", signature_state.index, total),
    title_pos = "center",
    focusable = false,
    noautocmd = true,
    zindex = 90,
  })

  vim.wo[signature_state.popup_win].wrap = true
  vim.wo[signature_state.popup_win].linebreak = true
  vim.wo[signature_state.popup_win].conceallevel = 0
  vim.wo[signature_state.popup_win].winhighlight =
    "Normal:NormalFloat,FloatBorder:FloatBorder"
end

local function request_signature_help()
  local bufnr = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({
    bufnr = bufnr,
    method = "textDocument/signatureHelp",
  })

  if vim.tbl_isempty(clients) then
    vim.notify("No signature-help provider attached", vim.log.levels.INFO)
    return
  end

  local client = clients[1]
  local params = vim.lsp.util.make_position_params(0, client.offset_encoding or "utf-16")

  signature_state.request_id = signature_state.request_id + 1
  local current_request = signature_state.request_id

  client:request("textDocument/signatureHelp", params, function(err, result)
    vim.schedule(function()
      if current_request ~= signature_state.request_id then
        return
      end

      if err then
        vim.notify(err.message or tostring(err), vim.log.levels.WARN)
        return
      end

      if not result or type(result.signatures) ~= "table" or #result.signatures == 0 then
        close_signature_help()
        return
      end

      local active_signature = tonumber(result.activeSignature) or 0
      if active_signature < 0 or active_signature >= #result.signatures then
        active_signature = 0
      end

      signature_state.source_buf = bufnr
      signature_state.signatures = result.signatures
      signature_state.index = active_signature + 1
      signature_state.active_parameter = result.activeParameter
      render_signature_help()
    end)
  end, bufnr)
end

_G.toggle_signature_help = function()
  if signature_state.popup_win and vim.api.nvim_win_is_valid(signature_state.popup_win) then
    close_signature_help()
    return
  end

  request_signature_help()
end

_G.cycle_signature_help = function()
  if signature_state.source_buf ~= vim.api.nvim_get_current_buf()
    or vim.tbl_isempty(signature_state.signatures)
  then
    request_signature_help()
    return
  end

  signature_state.index = (signature_state.index % #signature_state.signatures) + 1
  render_signature_help()
end

local signature_popup_group =
  vim.api.nvim_create_augroup("signature_help_popup_events", { clear = true })

vim.api.nvim_create_autocmd({ "InsertLeave", "BufLeave" }, {
  group = signature_popup_group,
  callback = close_signature_help,
})

vim.api.nvim_create_autocmd("InsertCharPre", {
  group = signature_popup_group,
  callback = function(args)
    local char = vim.v.char

    if char == "(" or char == "," then
      vim.defer_fn(function()
        if vim.api.nvim_get_current_buf() == args.buf and vim.fn.mode() == "i" then
          request_signature_help()
        end
      end, 40)
    elseif char == ")" then
      vim.schedule(close_signature_help)
    end
  end,
})

_G.show_diagnostic_float = function()
  vim.diagnostic.open_float(nil, {
    focusable = true,
    scope = "cursor",
    border = "rounded",
    source = true,
    header = "",
    prefix = "",
    max_width = math.floor(vim.o.columns * 0.85),
    wrap = true,
    close_events = { "BufLeave", "CursorMoved", "InsertEnter", "FocusLost" },
  })
end

vim.diagnostic.config({
  virtual_text = false,
  signs = true,
  underline = true,
  update_in_insert = true,
  severity_sort = true,
  float = {
    border = "rounded",
    source = true,
    max_width = math.floor(vim.o.columns * 0.85),
    wrap = true,
  },
})

-- Rider refactoring actions -------------------------------------------------
-- Nothing in here is wired to an autocmd. Each function runs only because a
-- keymap at the bottom of this file called it.

local rider_refactor = {}

-- Rider: Reformat Code. conform reads the current visual selection on its own,
-- so the same function reformats the file in normal mode and the selection in
-- visual mode, exactly like Ctrl+Alt+L does in Rider.
function rider_refactor.reformat()
  require("conform").format({
    async = false,
    timeout_ms = 3000,
    lsp_format = "fallback",
  })
end

-- Rider: Optimize Imports.
function rider_refactor.organize_imports()
  local bufnr = vim.api.nvim_get_current_buf()

  -- gopls exposes no source.organizeImports action here; goimports is Go's
  -- optimize-imports and is the same tool Rider runs for Go files.
  if vim.bo[bufnr].filetype == "go" then
    require("conform").format({
      bufnr = bufnr,
      formatters = { "goimports" },
      async = false,
      timeout_ms = 3000,
    })
    return
  end

  vim.lsp.buf.code_action({
    context = { only = { "source.organizeImports" }, diagnostics = {} },
    apply = true,
  })
end

-- Rider: Code Cleanup. Reformat first (synchronously), then fix up the import
-- block. Organizing imports only rewrites whole using/import lines, so doing it
-- second cannot leave the file unformatted.
function rider_refactor.cleanup()
  rider_refactor.reformat()

  -- goimports already ran as part of the Go formatter chain.
  if vim.bo.filetype ~= "go" then
    rider_refactor.organize_imports()
  end
end

-- Rider's refactoring entries are LSP code-action kinds; the language server
-- decides which concrete refactorings sit behind each kind. Passing no kind
-- reproduces Alt+Enter, which offers quick-fixes as well.
function rider_refactor.code_action(kinds)
  return function()
    vim.lsp.buf.code_action({
      context = kinds and { only = kinds, diagnostics = {} } or nil,
    })
  end
end

-- Rider: Auto-Indent Lines. Re-indents using the rider_style settings without
-- running a formatter, so it also works in buffers that have no formatter.
function rider_refactor.auto_indent()
  local mode = vim.api.nvim_get_mode().mode
  if mode == "v" or mode == "V" or mode == "\22" then
    vim.cmd("normal! =gv")
  else
    vim.cmd("normal! ==")
  end
end

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
local uv = vim.uv or vim.loop
if not uv.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- The terminal's palette, Soft Surface, read from terminal/palette.conf in the
-- desktop project (this config is linked from it), so that neovim is the same
-- surface as the kitty window it runs in rather than a black panel inside it;
-- then this machine's state file over it, as kitty-colors.py does (the shell's
-- accent, while it follows the wallpaper). Nil when palette.conf is not
-- there; the theme then stays lackluster's own.
local soft = (function()
  local here = vim.fn.resolve(vim.fn.stdpath("config"))
  local file = io.open(here .. "/../terminal/palette.conf")
  if not file then
    return nil
  end
  local state = os.getenv("XDG_STATE_HOME")
  if not state or state == "" then
    state = vim.fn.expand("~/.local/state")
  end
  local palette = {}
  for _, f in ipairs({ file, io.open(state .. "/quickshell-desktop/palette.conf") }) do
    for line in f:lines() do
      local name, hex = line:match("^([%w_]+)%s+(#%x%x%x%x%x%x)%s*$")
      if name then
        palette[name] = hex
      end
    end
    f:close()
  end
  return palette
end)()

-- The shade <t> of the way from <a> to <b>, for the steps between the
-- palette's own that lackluster's ramp has.
local function mix(a, b, t)
  local function channel(hex, i)
    return tonumber(hex:sub(i, i + 1), 16)
  end
  local out = "#"
  for i = 2, 6, 2 do
    out = out .. string.format("%02x", math.floor(channel(a, i) + (channel(b, i) - channel(a, i)) * t + 0.5))
  end
  return out
end

require("lazy").setup({
  {
    "slugbyte/lackluster.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      -- lackluster draws everything from one gray ramp, a few accents, and a
      -- handful of fixed in-between shades (comments, keywords, the statusline,
      -- menus) that setup() has no option for; it reads them from this table
      -- when it builds the theme, and lazy-lock.json pins the version. Each
      -- becomes the terminal's cool equivalent at lackluster's own step.
      local has_special, special = pcall(require, "lackluster.color-special")
      if soft and has_special then
        special.main_background = soft.bg
        special.menu_background = soft.surface
        special.popup_background = soft.surface
        special.statusline = soft.surface
        special.whitespace = soft.surface
        special.comment = soft.muted
        special.exception = mix(soft.muted, soft.dim, 0.2)
        special.keyword = mix(soft.muted, soft.dim, 0.6)
        special.param = mix(soft.dim, soft.fg, 0.3)
      end

      local ok, lackluster = pcall(require, "lackluster")
      if soft and ok and lackluster.setup then
        lackluster.setup({
          tweak_color = {
            black = soft.bg,
            gray1 = soft.bg_alt,
            gray2 = soft.surface,
            gray3 = soft.raised,
            gray4 = mix(soft.raised, soft.muted, 0.5),
            gray5 = mix(soft.muted, soft.dim, 0.4),
            gray6 = soft.dim,
            gray7 = mix(soft.dim, soft.fg, 0.5),
            gray8 = soft.fg,
            gray9 = soft.bright,
            luster = soft.bright,
            lack = soft.accent,
            blue = soft.accent_bright,
            green = soft.green,
            yellow = soft.yellow,
            orange = soft.orange,
            red = soft.red,
          },
          tweak_background = {
            normal = "none", -- the terminal's own, padding and all
            telescope = "none",
          },
        })
      end

      vim.cmd.colorscheme("lackluster")
      if not soft then
        return
      end

      local function hl(group, opts)
        vim.api.nvim_set_hl(0, group, opts)
      end

      hl("CursorLine", { bg = soft.bg_alt })
      hl("LineNr", { fg = soft.muted })
      hl("CursorLineNr", { fg = soft.fg, bold = true })
      hl("Visual", { bg = soft.selection })
      hl("NormalFloat", { fg = soft.fg, bg = soft.surface })
      hl("FloatBorder", { fg = soft.raised, bg = soft.surface })
      hl("Pmenu", { fg = soft.fg, bg = soft.surface })
      hl("PmenuSel", { fg = soft.bright, bg = soft.selection })
      hl("TelescopeBorder", { fg = soft.raised })
      hl("TelescopeSelection", { fg = soft.bright, bg = soft.selection })
      hl("OilDir", { fg = soft.accent, bold = true })
      hl("OilFile", { fg = soft.fg })
      hl("LspSignatureActiveParameter", { fg = soft.bright, bg = soft.selection, bold = true })
    end,
  },

  {
    "nvim-lualine/lualine.nvim",
    config = function()
      local function cwd()
        local path = vim.fn.fnamemodify(vim.fn.getcwd(), ":~")
        return path
      end

      local function mode_name(mode)
        local names = {
          NORMAL = "NORM",
          INSERT = "INS",
          VISUAL = "VIS",
          ["V-LINE"] = "V-LINE",
          ["V-BLOCK"] = "V-BLOCK",
          REPLACE = "REP",
          COMMAND = "CMD",
          TERMINAL = "TERM",
        }
        return names[mode] or mode
      end

      require("lualine").setup({
        options = {
          -- The mode in a pill of its own colour, the branch and diagnostics on
          -- the surface, the rest on the terminal's background; lualine's own
          -- guess without the palette.
          theme = not soft and "auto" or (function()
            local function mode(color, fg)
              return {
                a = { fg = fg or soft.bg, bg = color, gui = "bold" },
                b = { fg = soft.fg, bg = soft.surface },
                c = { fg = soft.dim, bg = soft.bg },
              }
            end
            return {
              normal = mode(soft.selection, soft.bright),
              insert = mode(soft.green),
              visual = mode(soft.yellow),
              replace = mode(soft.red),
              command = mode(soft.accent),
              inactive = {
                a = { fg = soft.muted, bg = soft.bg },
                b = { fg = soft.muted, bg = soft.bg },
                c = { fg = soft.muted, bg = soft.bg },
              },
            }
          end)(),
          component_separators = "",
          section_separators = "",
          globalstatus = true,
          icons_enabled = false,
        },
        sections = {
          lualine_a = { { "mode", fmt = mode_name } },
          lualine_b = { "branch", "diagnostics" },
          lualine_c = {
            {
              "filename",
              path = 1,
              symbols = {
                modified = " [+]",
                readonly = " [ro]",
                unnamed = "[no name]",
              },
            },
          },
          lualine_x = { cwd, "filetype" },
          lualine_y = { "progress" },
          lualine_z = { "location" },
        },
        inactive_sections = {
          lualine_a = {},
          lualine_b = {},
          lualine_c = { { "filename", path = 1 } },
          lualine_x = { "location" },
          lualine_y = {},
          lualine_z = {},
        },
      })
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter",
    branch = "master",
    build = ":TSUpdate",
    opts = {
      ensure_installed = {
        "c",
        "cpp",
        "c_sharp",
        "go",
        "gomod",
        "gosum",
        "gowork",
        "lua",
        "vim",
        "vimdoc",
      },
      highlight = {
        enable = true,
        disable = { "markdown", "markdown_inline" },
      },
      indent = {
        enable = true,
        disable = { "markdown", "markdown_inline" },
      },
      auto_install = true,
    },
    config = function(_, opts)
      require("nvim-treesitter.configs").setup(opts)

      local markdown_ts_group =
        vim.api.nvim_create_augroup("stop_markdown_treesitter", { clear = true })

      vim.api.nvim_create_autocmd({ "FileType", "BufWinEnter" }, {
        group = markdown_ts_group,
        pattern = "*",
        callback = function(args)
          if not vim.api.nvim_buf_is_valid(args.buf) then
            return
          end

          local filetype = vim.bo[args.buf].filetype
          if filetype == "markdown"
            or filetype == "markdown_inline"
            or filetype:match("^markdown%.")
          then
            pcall(vim.treesitter.stop, args.buf)
          end
        end,
      })
    end,
  },

  { "williamboman/mason.nvim", opts = {} },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = { "williamboman/mason.nvim" },
    opts = {
      ensure_installed = {
        "goimports",
        "gofumpt",
        "clang-format",
        "csharpier",
      },
      auto_update = false,
      run_on_start = true,
    },
  },
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "williamboman/mason.nvim" },
    opts = {
      ensure_installed = {
        "gopls",
        "clangd",
        "omnisharp",
      },
      automatic_enable = false,
    },
  },
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
      "hrsh7th/cmp-nvim-lsp",
    },
    config = function()
      local capabilities = require("cmp_nvim_lsp").default_capabilities()

      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("lsp_keymaps", { clear = true }),
        callback = function(event)
          local map = function(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, { buffer = event.buf, silent = true, desc = desc })
          end

          -- Navigation and docs.
          map("n", "gd", vim.lsp.buf.definition, "Go to definition")
          map("n", "gr", vim.lsp.buf.references, "Find references")
          map("n", "<M-F7>", vim.lsp.buf.references, "Rider: find usages (Alt+F7)")
          map("n", "K", request_centered_hover, "Hover docs")
          map({ "n", "i" }, "<C-k>", _G.toggle_signature_help, "Toggle signature help")
          map({ "n", "i" }, "<C-s>", _G.cycle_signature_help, "Next method overload")
          map({ "n", "i" }, "<M-n>", _G.cycle_signature_help, "Next method overload")
          map("n", "<leader>d", _G.show_diagnostic_float, "Line diagnostics")

          -- Rider refactorings, mapped per buffer because they need a server.
          -- Each one is listed with its Rider chord and a <leader> alias.
          local extract = rider_refactor.code_action({ "refactor.extract" })
          local inline = rider_refactor.code_action({ "refactor.inline" })
          local rewrite = rider_refactor.code_action({ "refactor.rewrite" })
          -- "refactor" matches every refactor.* kind, so this is Refactor This.
          local refactor_this = rider_refactor.code_action({ "refactor" })
          local context_actions = rider_refactor.code_action()

          map("n", "<S-F6>", vim.lsp.buf.rename, "Rider: rename (Shift+F6)")
          map("n", "<leader>rn", vim.lsp.buf.rename, "Rider: rename")

          map({ "n", "v" }, "<M-CR>", context_actions, "Rider: context actions (Alt+Enter)")
          map({ "n", "v" }, "<leader>ca", context_actions, "Rider: context actions")

          map({ "n", "v" }, "<C-A-S-t>", refactor_this, "Rider: refactor this (Ctrl+Alt+Shift+T)")
          map({ "n", "v" }, "<leader>rr", refactor_this, "Rider: refactor this")

          -- Extract Method and Introduce Variable are the same LSP kind; the
          -- server lists whichever it can offer for the current selection.
          map({ "n", "v" }, "<C-A-m>", extract, "Rider: extract method (Ctrl+Alt+M)")
          map({ "n", "v" }, "<C-A-v>", extract, "Rider: introduce variable (Ctrl+Alt+V)")
          map({ "n", "v" }, "<leader>re", extract, "Rider: extract / introduce")

          map({ "n", "v" }, "<C-A-n>", inline, "Rider: inline (Ctrl+Alt+N)")
          map({ "n", "v" }, "<leader>ri", inline, "Rider: inline")

          map({ "n", "v" }, "<C-F6>", rewrite, "Rider: change signature (Ctrl+F6)")
          map({ "n", "v" }, "<leader>rw", rewrite, "Rider: change signature")
        end,
      })

      local servers = {
        gopls = {
          capabilities = capabilities,
          settings = {
            gopls = {
              gofumpt = true,
              analyses = {
                unusedparams = true,
                unusedwrite = true,
                shadow = true,
              },
              staticcheck = true,
            },
          },
        },
        clangd = {
          capabilities = capabilities,
        },
        omnisharp = {
          capabilities = capabilities,
          enable_roslyn_analyzers = true,
          organize_imports_on_format = true,
          enable_import_completion = true,
        },
      }

      for name, config in pairs(servers) do
        vim.lsp.config(name, config)
        vim.lsp.enable(name)
      end
    end,
  },


  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
    },
    config = function()
      local cmp = require("cmp")
      cmp.setup({
        snippet = {
          expand = function(args)
            require("luasnip").lsp_expand(args.body)
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
          ["<Tab>"] = cmp.mapping.select_next_item(),
          ["<S-Tab>"] = cmp.mapping.select_prev_item(),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "luasnip" },
          { name = "path" },
          { name = "buffer" },
        }),
      })
    end,
  },

  {
    "stevearc/dressing.nvim",
    opts = {
      input = {
        border = "rounded",
      },
      select = {
        backend = { "telescope", "builtin" },
        builtin = {
          border = "rounded",
        },
      },
    },
  },

  {
    "stevearc/oil.nvim",
    lazy = false,
    opts = {
      default_file_explorer = true,
      skip_confirm_for_simple_edits = true,
      view_options = {
        show_hidden = true,
      },
      keymaps = {
        ["<C-s>"] = false,
        ["<C-h>"] = false,
        ["<C-l>"] = false,
      },
    },
    config = function(_, opts)
      require("oil").setup(opts)

      vim.keymap.set("n", "<leader>e", "<cmd>Oil<cr>", { silent = true, desc = "Open file manager" })
      vim.keymap.set("n", "-", "<cmd>Oil<cr>", { silent = true, desc = "Open parent directory" })
    end,
  },

  {
    "nvim-telescope/telescope.nvim",
    branch = "0.1.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    config = function()
      local telescope = require("telescope")
      local builtin = require("telescope.builtin")

      telescope.setup({
        defaults = {
          prompt_prefix = "Search: ",
          selection_caret = "> ",
          path_display = { "smart" },
          mappings = {
            i = {
              ["<Esc>"] = require("telescope.actions").close,
            },
          },
        },
      })

      vim.keymap.set("n", "<leader>ff", builtin.find_files, { silent = true, desc = "Find files" })
      vim.keymap.set("n", "<leader>fg", builtin.live_grep, { silent = true, desc = "Search text" })
      vim.keymap.set("n", "<leader>fb", builtin.buffers, { silent = true, desc = "Find buffers" })
      vim.keymap.set("n", "<leader>fh", builtin.help_tags, { silent = true, desc = "Find help" })
    end,
  },

  {
    "stevearc/conform.nvim",
    opts = {
      -- conform is never called from an autocmd in this config. The only
      -- callers are rider_refactor.reformat / cleanup / organize_imports.
      default_format_opts = {
        lsp_format = "fallback",
        timeout_ms = 3000,
      },
      formatters_by_ft = {
        c = { "clang-format" },
        cpp = { "clang-format" },
        cs = { "csharpier" },
        go = { "goimports", "gofumpt" },
      },
      formatters = {
        -- goimports and gofumpt have no options: gofmt output is what Rider
        -- produces for Go too. C# and C/C++ need the Rider rules passed in.
        ["clang-format"] = {
          prepend_args = { "--style=file:" .. rider_style_dir .. "/clang-format.yaml" },
        },
        csharpier = {
          command = "csharpier",
          stdin = true,
          args = function(_, ctx)
            local args = { "format", "--config-path", rider_style_dir .. "/csharpier.json" }

            -- csharpier crashes on a --stdin-path without a directory part,
            -- and an unnamed buffer has no path at all.
            if ctx.filename and ctx.filename ~= "" then
              vim.list_extend(args, { "--stdin-path", vim.fn.fnamemodify(ctx.filename, ":p") })
            end

            return args
          end,
        },
      },
    },
  },
})

-- Rider refactoring keymaps -------------------------------------------------
-- These are the only things that reformat or rewrite a buffer. Each action has
-- the Rider chord (works in kitty and other terminals that speak the kitty
-- keyboard protocol) and a <leader> alias that works everywhere.
--
--   Ctrl+Alt+L          <leader>cf   Reformat code / selection
--   Ctrl+Alt+Shift+L    <leader>cc   Code cleanup (reformat + optimize imports)
--   Ctrl+Alt+O          <leader>co   Optimize imports
--   Ctrl+Alt+I          <leader>ci   Auto-indent lines
--   Shift+F6            <leader>rn   Rename
--   Ctrl+Alt+Shift+T    <leader>rr   Refactor this
--   Ctrl+Alt+M          <leader>re   Extract method
--   Ctrl+Alt+V          <leader>re   Introduce variable
--   Ctrl+Alt+N          <leader>ri   Inline
--   Ctrl+F6             <leader>rw   Change signature
--   Alt+Enter           <leader>ca   Context actions / quick-fixes
--   Alt+F7              gr           Find usages
--
-- The LSP-driven half of this list is mapped per buffer in the LspAttach
-- handler above; the formatter-driven half is global and mapped here.

local function rider_map(lhs, rhs, desc)
  vim.keymap.set({ "n", "v" }, lhs, rhs, { silent = true, desc = desc })
end

rider_map("<C-A-l>", rider_refactor.reformat, "Rider: reformat code")
rider_map("<leader>cf", rider_refactor.reformat, "Rider: reformat code")

rider_map("<C-A-S-l>", rider_refactor.cleanup, "Rider: code cleanup")
rider_map("<leader>cc", rider_refactor.cleanup, "Rider: code cleanup")

rider_map("<C-A-o>", rider_refactor.organize_imports, "Rider: optimize imports")
rider_map("<leader>co", rider_refactor.organize_imports, "Rider: optimize imports")

rider_map("<C-A-i>", rider_refactor.auto_indent, "Rider: auto-indent lines")
rider_map("<leader>ci", rider_refactor.auto_indent, "Rider: auto-indent lines")

vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { silent = true, desc = "Previous diagnostic" })
vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { silent = true, desc = "Next diagnostic" })
