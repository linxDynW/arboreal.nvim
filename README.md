# arboreal.nvim

Edit directory trees in Markdown and other documents like a drawing tool.

Writing fake directory trees (`├──`, `└──`, `│`) by hand is tedious and easy to get
wrong. arboreal.nvim turns plain indented lines into a rendered tree and keeps the
tree valid while you edit it.

## Features

- Convert an indented selection into a directory tree (`:Arb c`)
- Live tree editing with automatic connectors, level adjustment, safe deletion
- Tree-aware visual mode, operators, and paste protection
- Root lines and plain text stay completely native
- Pure-Lua implementation with no runtime dependencies
- Test suite, StyLua formatting, Luacheck, and CI for Neovim 0.9+

## Requirements

- Neovim >= 0.9

## Installation

With lazy.nvim / LazyVim:

```lua
{
  "linxDynW/arboreal.nvim",
  cmd = { "Arb", "ArborealConvert" },
  keys = {
    { "<leader>at", mode = "x", desc = "Convert selection to tree" },
  },
  event = "VeryLazy",
  opts = {},
}
```

`cmd` makes `:Arb` and `:ArborealConvert` available before the plugin is
loaded, `keys` keeps the default visual mapping lazy, and `event = "VeryLazy"`
registers live-editing autocmds and mappings after startup without blocking it.

**Startup behavior:** live editing only exists after the plugin has been loaded.
`:Arb on` is a lazy-loader command stub, so if a tree buffer does not activate
live editing (for example, the tree starts after the detection window below),
run `:Arb on`. The same applies when a plugin manager does not load arboreal
automatically: `:Arb on` always loads and enables it.

To load even later, replace `event = "VeryLazy"` with content detection. The
plugin is then loaded the first time a buffer starts with tree connectors
(`├`, `└`, or `│`), or when a command/key triggers it:

```lua
{
  "linxDynW/arboreal.nvim",
  name = "arboreal.nvim",
  cmd = { "Arb", "ArborealConvert" },
  keys = {
    { "<leader>at", mode = "x", desc = "Convert selection to tree" },
  },
  init = function()
    vim.api.nvim_create_autocmd("BufReadPost", {
      group = vim.api.nvim_create_augroup("ArborealLazyLoad", { clear = true }),
      callback = function()
        if pcall(require, "arboreal") then
          return
        end
        local lines = vim.api.nvim_buf_get_lines(0, 0, 200, false)
        for _, line in ipairs(lines) do
          if line:match("^%s*[├└│]") then
            require("lazy").load({ plugins = { "arboreal.nvim" } })
            break
          end
        end
      end,
    })
  end,
  opts = {},
}
```

## Usage

Select plain indented lines and press `<leader>at` (or run `:Arb c`):

```text
src
    main.rs
    lib.rs
    tests
        a.rs
```

becomes:

```text
src
├── main.rs
├── lib.rs
└── tests
    └── a.rs
```

## Commands

| Command | Description |
|---|---|
| `:Arb c` | Convert the visual selection, or use a range: `:1,4Arb c` |
| `:Arb i` | Mark the current line as a tree entry; the line above becomes the root |
| `:Arb on` | Enable live tree editing |
| `:Arb off` | Disable live tree editing and treat trees as plain text |

## Live editing

Live editing is enabled by default. Inside a well-formed tree:

| Key | Behavior |
|---|---|
| `o` / `Enter` | New sibling after the current node's subtree |
| `Tab` / `Shift-Tab` | Move the node one level deeper/shallower within the at-most-one-level rule |
| `Backspace` | Delete the character before the cursor; empty leaves delete the whole line, empty directories are protected |
| `dd` | Delete a node; directory children are merged into the parent. Count deletes that many physical lines |
| `>>` / `<<` | Structurally shift `[count]` lines; plain text falls back to native indenting |
| `J` / `gJ` | Join the next node's name into the current one |
| `d` / `c` operators | Tree-aware inside trees and native elsewhere |
| `x` / `r` / `s` / `C` / `S` / `D` / `R` | Blocked on connectors (notifications suggest `:Arb off`), native on names |

Malformed trees are left to normal editing. The root line is plain text: indent,
delete, or edit it freely; the tree body stays valid.

## Configuration

```lua
require("arboreal").setup({
  branch = "├──",              -- non-last-child connector
  leaf = "└──",                -- last-child connector
  pipe = "│",                  -- vertical pipe
  indent = 4,                  -- output indent width (fallback when undetectable)
  convert_key = "<leader>at",  -- false to disable
  insert_key = false,          -- e.g. "<leader>ai" to map :Arb i
  toggle_key = false,          -- e.g. "<leader>ut" to map :Arb on/off
  notify_on_limit = true,
  confirm_directory_delete = true,
  subtree_indent = false,      -- reserved
})
```

## Development

Run all tests:

```bash
./tests/run_all.sh
```

Check formatting and lint:

```bash
stylua --check lua plugin tests
luacheck -r lua plugin tests
```

## License

MIT
