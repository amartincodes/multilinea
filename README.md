# Multilinea.nvim

A powerful multi-cursor editing plugin for Neovim, inspired by VSCode's multi-cursor functionality. Built with LazyVim compatibility in mind.

## Features

- 🎯 **VSCode-style cursor addition** - Press `<C-n>` to add cursors at matches
- ⬆️⬇️ **Directional cursors** - Add cursors above/below current position
- 🔍 **Literal matching** - Match the char under the cursor or a visual selection anywhere
- ✏️ **Simultaneous editing** - Type once, edit everywhere
- 🎨 **Visual feedback** - Clear cursor indicators using Neovim's extmarks
- ⚡ **Lightweight** - Pure Lua implementation with minimal dependencies
- 🔧 **Fully customizable** - Configure keybindings, highlights, and behavior

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim) (recommended)

```lua
-- In ~/.config/nvim/lua/plugins/multilinea.lua
return {
  "amartincodes/multilinea.nvim",
  event = "BufReadPost",
  opts = {
    -- Your configuration here (optional)
  },
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "amartincodes/multilinea.nvim",
  config = function()
    require("multilinea").setup()
  end
}
```

### Using [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'amartincodes/multilinea.nvim'

" In your init.vim
lua << EOF
  require("multilinea").setup()
EOF
```

## Usage

### Basic Operations

1. **Add cursor at next match** (VSCode-style)
   - Place cursor on a character, or visually select text
   - Press `<C-n>` to add cursor at the next occurrence
   - Keep pressing `<C-n>` to add more cursors
   - Press `<Esc>` to clear all cursors

2. **Add cursors vertically**
   - Press `<C-j>` to add cursor below
   - Press `<C-k>` to add cursor above
   - Great for editing aligned columns

3. **Add all matches**
   - Place cursor on a character, or visually select text
   - Press `<leader>ma` to add cursors at all occurrences

4. **Manual cursor placement**
   - Press `<leader>mc` to add a cursor at current position
   - Move around and add more cursors where needed

### Editing with Multiple Cursors

Once you have multiple cursors:

- **Insert mode**: Press `i`, `a`, `I`, `A`, `o`, or `O` to start editing at all cursors
- **Normal mode**: Most motions and operators work at all cursors:
  - `w`, `b`, `e` - word motions
  - `0`, `^`, `$` - line motions
  - `dd`, `D`, `x` - delete operations
  - `r{char}` - replace character at all cursors
  - `y`, `p` - yank and paste
- **Clear cursors**: Press `<Esc>` to exit multi-cursor mode

### Example Workflow

```lua
-- Rename all occurrences of a variable
1. Place cursor on variable name
2. Press <C-n> multiple times (or <leader>ma for all)
3. Press 'ciw' to change inner word
4. Type the new name
5. Press <Esc> to apply to all cursors
```

## Configuration

### Default Configuration

```lua
require("multilinea").setup({
  -- Keybindings (all customizable)
  keymaps = {
    add_cursor_next = "<C-n>",      -- Add cursor at next match
    add_cursor_below = "<C-j>",      -- Add cursor below
    add_cursor_above = "<C-k>",      -- Add cursor above
    add_all_matches = "<leader>ma",  -- Add all matches
    remove_cursor = "<M-x>",         -- Remove current cursor
    clear_cursors = "<Esc>",         -- Clear all cursors
    skip_match = "<leader>ms",       -- Skip current match
    add_cursor_here = "<leader>mc",  -- Add cursor at position
  },

  -- Visual appearance
  highlights = {
    primary = "CursorLine",
    secondary = "Visual",
  },

  -- Behavior
  show_cursor_numbers = false,     -- Show cursor index numbers
  case_sensitive_search = false,   -- Case sensitivity for matching
})
```

### Custom Keybindings

```lua
require("multilinea").setup({
  keymaps = {
    add_cursor_next = "<C-d>",      -- Use Ctrl-d like Sublime Text
    add_all_matches = "<C-M-l>",    -- Custom binding
    clear_cursors = "<leader>mc",   -- Use leader instead of Esc
  },
})
```

### Custom Highlights

```lua
require("multilinea").setup({
  highlights = {
    primary = "Search",             -- Use Search highlight for primary cursor
    secondary = "IncSearch",        -- Use IncSearch for secondary cursors
  },
})
```

## Commands

Multilinea provides the following user commands:

- `:MultilineaAddCursor` - Add cursor at current position
- `:MultilineaAddNext` - Add cursor at next match
- `:MultilineaAddAll` - Add cursors at all matches
- `:MultilineaClear` - Clear all cursors
- `:MultilineaAddBelow` - Add cursor below
- `:MultilineaAddAbove` - Add cursor above

## API

Multilinea exposes a public API for integration with other plugins:

```lua
local multilinea = require("multilinea")

-- Add cursor programmatically
multilinea.api.add_cursor(row, col, is_primary)

-- Remove cursor
multilinea.api.remove_cursor(row, col)

-- Clear all cursors
multilinea.api.clear_all()

-- Get cursor positions
local cursors = multilinea.api.get_cursors()

-- Check if active
if multilinea.api.is_active() then
  print("Multi-cursor mode active")
end

-- Get cursor count
local count = multilinea.api.get_count()
```

## Health Check

Run `:checkhealth multilinea` to verify your installation.

## Comparison with Other Plugins

| Feature | Multilinea | vim-visual-multi | multiple-cursors.nvim |
|---------|-----------|------------------|----------------------|
| Pure Lua | ✅ | ❌ | ✅ |
| Extmarks API | ✅ | ❌ | ✅ |
| VSCode-style `<C-n>` | ✅ | ✅ | ✅ |
| LazyVim ready | ✅ | ⚠️ | ⚠️ |
| Lightweight | ✅ | ❌ | ✅ |
| Visual mode | 🚧 | ✅ | ✅ |

## Roadmap

- [x] Basic multi-cursor operations
- [x] VSCode-style literal matching
- [x] Directional cursor addition
- [x] Insert mode editing
- [x] Normal mode operations
- [ ] Full visual mode support
- [ ] Macro recording per cursor
- [ ] Advanced selection refinement
- [ ] Pattern-based cursor placement
- [ ] Split/join cursor operations

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### Development Setup

```bash
# Clone the repository
git clone https://github.com/amartincodes/multilinea.nvim.git
cd multilinea.nvim

# Test in Neovim
nvim --cmd "set rtp+=."
```

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Acknowledgments

Inspired by:
- [vim-visual-multi](https://github.com/mg979/vim-visual-multi)
- [multiple-cursors.nvim](https://github.com/brenton-leighton/multiple-cursors.nvim)
- [multicursor.nvim](https://github.com/jake-stewart/multicursor.nvim)
- VSCode's multi-cursor functionality

## Support

If you encounter issues or have questions:

1. Check the [documentation](doc/multilinea.txt)
2. Search [existing issues](https://github.com/amartincodes/multilinea.nvim/issues)
3. Create a new issue with:
   - Neovim version (`:version`)
   - Configuration
   - Steps to reproduce
   - Expected vs actual behavior

---

Made with ❤️ for the Neovim community
