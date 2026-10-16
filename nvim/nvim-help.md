# Neovim Quick Help

## Search Words

Use `/word` in this help. Useful words:

`oil`, `file`, `create`, `rename`, `delete`, `search`, `format`, `refactor`, `rider`, `error`, `gd`, `back`, `lsp`, `buffer`, `quit`.

## Core

| Key | Action |
|---|---|
| `Esc` | normal mode |
| `i` | insert before cursor |
| `a` | insert after cursor |
| `o` | new line below |
| `O` | new line above |
| `u` | undo |
| `Ctrl-r` | redo |
| `yy` | copy line |
| `dd` | cut line |
| `p` | paste after |
| `P` | paste before |
| `:w` | save |
| `:q` | quit |
| `:wq` | save and quit |
| `:q!` | quit without saving |

## Clipboard

Nvim uses the same clipboard as the system.

Required on Wayland/Hyprland:

```fish
sudo pacman -S --needed wl-clipboard
```

| Key / Command | Action |
|---|---|
| `yy` | copy line to system clipboard |
| visual `y` | copy selection to system clipboard |
| `p` | paste from system clipboard |
| `"+y` | explicit copy to system clipboard |
| `"+p` | explicit paste from system clipboard |

## Movement

| Key | Action |
|---|---|
| `h` `j` `k` `l` | left, down, up, right |
| `w` | next word |
| `b` | previous word |
| `0` | start of line |
| `^` | first non-space char |
| `$` | end of line |
| `gg` | start of file |
| `G` | end of file |
| `Ctrl-d` | half page down |
| `Ctrl-u` | half page up |

## Oil File Manager

Open:

| Key | Action |
|---|---|
| `Space e` | open Oil file manager |
| `-` | open parent directory |
| `Enter` | open file or directory |
| `q` | close Oil |
| `:w` | apply filesystem changes |

Create:

1. Press `Space e`.
2. Add a new line with file name: `internal/user/service.go`.
3. Save with `:w`.

Create directory:

1. Press `Space e`.
2. Add a new line ending with `/`: `internal/user/`.
3. Save with `:w`.

Rename:

1. Press `Space e`.
2. Edit file or directory name directly.
3. Save with `:w`.

Delete:

1. Press `Space e`.
2. Delete the line with `dd`.
3. Save with `:w`.

Cancel Oil changes:

| Key | Action |
|---|---|
| `u` | undo edit in Oil buffer |
| `:q!` | close without applying changes |

## Files And Search

| Key | Action |
|---|---|
| `Space ff` | find files |
| `Space fg` | search text in project |
| `Space fb` | show open buffers |
| `Space fh` | search help tags |
| `Esc` | close Telescope |
| `Enter` | open selected result |

Project search tips:

| Pattern | Meaning |
|---|---|
| `func main` | find text |
| `UserService` | find symbol text |
| `TODO` | find notes |

## Statusline

Bottom line shows:

| Place | Meaning |
|---|---|
| left | current mode: `NORM`, `INS`, `VIS`, `CMD` |
| left-center | git branch and diagnostics |
| center | current file path |
| right | current working directory, filetype, position |

Useful checks:

| Command | Action |
|---|---|
| `:pwd` | show current working directory |
| `:e %:p` | show full path of current file in command line |

## Buffers

| Command | Action |
|---|---|
| `:ls` | list open buffers |
| `:b 2` | switch to buffer 2 |
| `:bn` | next buffer |
| `:bp` | previous buffer |
| `:bd` | close current buffer |

## Windows

| Command / Key | Action |
|---|---|
| `:split` | horizontal split |
| `:vsplit` | vertical split |
| `Ctrl-w h` | move to left split |
| `Ctrl-w j` | move to bottom split |
| `Ctrl-w k` | move to top split |
| `Ctrl-w l` | move to right split |
| `Ctrl-w q` | close split |
| `Ctrl-w =` | equalize split sizes |

## LSP Code Navigation

| Key | Action |
|---|---|
| `gd` | go to definition |
| `gr` or `Alt-F7` | find references / find usages |
| `K` | hover docs |
| `Space d` | show error under cursor |

Renaming and code actions are listed under Refactoring below.

After `gd`:

| Key | Action |
|---|---|
| `Ctrl-o` | go back |
| `Ctrl-i` | go forward again |

After `gr`:

| Command / Key | Action |
|---|---|
| `Enter` | open selected reference |
| `q` or `Esc` | close popup/list if shown |
| `:cclose` | close quickfix list |
| `:cnext` | next quickfix result |
| `:cprev` | previous quickfix result |
| `Ctrl-o` | go back after opening result |

Hover docs:

| Key | Action |
|---|---|
| `K` | show docs |
| `q` or `Esc` | close docs popup |

## Diagnostics And Errors

| Key | Action |
|---|---|
| `]d` | next error/warning |
| `[d` | previous error/warning |
| `Space d` | show full diagnostic in floating window |
| `Space ca` | show fixes/actions |

Long diagnostics are not shown inline. This keeps code readable. Use `Space d` to see the full message with line wrapping.

Diagnostic signs:

| Sign | Meaning |
|---|---|
| red/error | code will likely not compile |
| warning | suspicious code |
| hint/info | suggestion |

## Formatting And Refactoring

Nothing is reformatted automatically. `:w` saves the file as it is, and leaving
insert mode changes nothing. Code is only rewritten when you press one of these.

Each action has its Rider shortcut and a `Space` alias that does the same thing.

| Rider key | Space alias | Action |
|---|---|---|
| `Ctrl-Alt-L` | `Space cf` | reformat file, or the selection in visual mode |
| `Ctrl-Alt-Shift-L` | `Space cc` | code cleanup: reformat + optimize imports |
| `Ctrl-Alt-O` | `Space co` | optimize imports |
| `Ctrl-Alt-I` | `Space ci` | auto-indent lines (no formatter) |
| `Shift-F6` | `Space rn` | rename |
| `Ctrl-Alt-Shift-T` | `Space rr` | refactor this |
| `Ctrl-Alt-M` | `Space re` | extract method |
| `Ctrl-Alt-V` | `Space re` | introduce variable |
| `Ctrl-Alt-N` | `Space ri` | inline |
| `Ctrl-F6` | `Space rw` | change signature |
| `Alt-Enter` | `Space ca` | context actions and quick-fixes |
| `Alt-F7` | `gr` | find usages |

`Ctrl-Alt-M` and `Ctrl-Alt-V` open the same list: the language server decides
which extract refactorings it can offer for what you selected.

Style follows JetBrains Rider defaults: 4 spaces in C#/C/C++, tabs in Go,
braces on their own line, 120-column right margin (shown as a guide line).

| Language | Formatter | Rider rules in |
|---|---|---|
| Go | `goimports` + `gofumpt` | nothing to configure, gofmt is the Rider style |
| C/C++ | `clang-format` | `~/.config/nvim/rider/clang-format.yaml` |
| C# | `csharpier` | `~/.config/nvim/rider/csharpier.json` |

Indent width per language lives in the `rider_style` table in `init.lua`.

## Where The Rider Rules Live

Three files, all agreeing on 4 spaces, braces on their own line, 120 columns.
Change a rule in the file that owns it, not in two places.

| File | Owns |
|---|---|
| `~/.config/nvim/init.lua` | `rider_style` table: indent width, tabs vs spaces, margin guide, per language |
| `~/.config/nvim/rider/clang-format.yaml` | full C/C++ style (ReSharper C++ defaults) |
| `~/.config/nvim/rider/csharpier.json` | C# print width 120, 4 spaces, LF |
| `~/.config/nvim/init.lua.bak-20260921` | the previous config, before formatting became manual |

These files are read by nvim only. Rider's own settings are untouched.

Indent defaults per language:

| Language | Indent | Tabs |
|---|---|---|
| C#, C, C++ | 4 | no |
| Go | 4 | yes (gofmt) |
| JSON, XML, YAML, Lua, Markdown | 2 | no |
| anything else | 4 | no |

Notes:

- `Ctrl-Alt-M` and `Ctrl-Alt-V` open the same list. LSP has one extract kind, so
  the language server decides which extract refactorings it offers.
- `init_signature_wrapped.lua` is an old copy of `init.lua` and is never loaded.

Debug formatting:

| Command | Action |
|---|---|
| `:ConformInfo` | show selected formatter and errors |
| `:Mason` | check installed tools |

## Go

| Task | Command |
|---|---|
| run file | `:!go run %` |
| run tests | `:!go test ./...` |
| format | `Ctrl-Alt-L` or `Space cf` |
| organize imports | `Ctrl-Alt-O` or `Space co` |

## C

| Task | Command |
|---|---|
| compile current file | `:!gcc % -o /tmp/a.out` |
| run compiled file | `:!/tmp/a.out` |
| format | `Ctrl-Alt-L` or `Space cf` |
| style file | `~/.config/nvim/rider/clang-format.yaml` |

## C#

| Task | Command |
|---|---|
| run project | `:!dotnet run` |
| build | `:!dotnet build` |
| test | `:!dotnet test` |
| format | `Ctrl-Alt-L` or `Space cf` |
| style file | `~/.config/nvim/rider/csharpier.json` |

## Terminal Commands From Nvim

| Command | Action |
|---|---|
| `:!cmd` | run shell command |
| `:!pwd` | show current directory |
| `:!ls` | list files |
| `:!mkdir -p path` | create directory |

## Help Popup

This file is what you are reading. To open it:

| How | Action |
|---|---|
| `Super + H` | open or close this help from anywhere |
| `nvim-help` | same thing from a shell |
| `:e ~/.config/nvim/nvim-help.md` | open it as a normal file inside nvim |

Inside the help:

| Key | Action |
|---|---|
| `/word` | search inside help |
| `n` | next search match |
| `N` | previous search match |
| `q` | close help |

If help dependencies are missing, the script opens the same floating console and asks before installing packages.

## Troubleshooting

| Problem | Check |
|---|---|
| `Space ff` does nothing | run `:Lazy sync`, restart nvim |
| format does nothing | run `:ConformInfo` |
| nothing formats on save | expected, press `Ctrl-Alt-L` or `Space cf` |
| `Ctrl-Alt-...` does nothing | terminal cannot send the chord, use the `Space` alias |
| LSP does nothing | run `:checkhealth vim.lsp` |
| tool missing | run `:Mason` |
| wrong filetype | run `:set filetype?` |
| help does not open | run `bash -x ~/.local/bin/nvim-help` |
| `gd` moved too far | press `Ctrl-o` |
| popup/list stuck | press `q`, `Esc`, or run `:cclose` |
