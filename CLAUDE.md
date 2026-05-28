# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Multilinea.nvim is a multi-cursor editing plugin for Neovim (0.7+) written in pure Lua. It provides VSCode-style multi-cursor functionality with support for literal token matching, vertical cursor addition, and simultaneous editing.

## Development Commands

### Testing in Neovim
```bash
# Test plugin with local development path
nvim --cmd "set rtp+=."

# Run health check inside Neovim
:checkhealth multilinea
```

### Local Development Setup
Create `~/.config/nvim/lua/plugins/multilinea.lua`:
```lua
return {
  dir = "/home/cubanmercury/Documents/projects/multilinea",
  event = "BufReadPost",
  opts = {},
}
```

## Architecture

### Module Structure (`lua/multilinea/`)

- **init.lua** - Entry point, setup function, config merging, public API, autocmds
- **state.lua** - Cursor state management, position tracking, namespace creation
- **operations.lua** - Core cursor operations (add/remove/find matches, token detection)
- **render.lua** - Visual rendering using Neovim's extmarks API
- **keymaps.lua** - Keybinding setup, user command definitions
- **modes.lua** - Mode-specific handling (normal, insert, visual modes)

### Key Concepts

- **Extmarks**: Visual cursor indicators use Neovim's extmarks API for rendering
- **Namespace**: Each buffer gets a namespace for cursor management (`state.get_namespace()`)
- **Primary vs Secondary Cursors**: Primary cursor follows real cursor, secondary cursors are virtual
- **Config Merging**: User config deep-merged with defaults in `merge_config()`

### Public API (`require("multilinea").api`)

```lua
add_cursor(row, col, is_primary)
remove_cursor(row, col)
clear_all()
get_cursors()
is_active()
get_count()
```

### User Commands

`:MultilineaAddCursor`, `:MultilineaAddNext`, `:MultilineaAddAll`, `:MultilineaClear`, `:MultilineaAddBelow`, `:MultilineaAddAbove`

## Default Keybindings

| Key | Action |
|-----|--------|
| `<C-n>` | Add cursor at next match (single char under cursor, or full visual selection) |
| `<C-j>` / `<C-k>` | Add cursor below/above |
| `<leader>ma` | Add cursors at all matches |
| `<leader>mc` | Add cursor at current position |
| `<M-x>` | Remove current cursor |
| `<leader>ms` | Skip current match |
| `<Esc>` | Clear all cursors |

`<C-n>` and `<leader>ma` also work in visual mode: with a multi-character
selection they match the full selected text. Linewise visual mode (`V`) is
also supported and matches selected lines as an exact block (without a trailing
newline). Matching is a literal substring search anywhere in the buffer,
honoring the `case_sensitive_search` option.

## Code Style

- Pure Lua (no Vimscript except plugin/ loader)
- LuaDoc annotations for function parameters (`---@param`)
- snake_case naming convention
- 2-space indentation
- Modular design with clear separation of concerns
