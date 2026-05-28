# Multilinea Quick Start Guide

## Installation Test

### Step 1: Install with LazyVim

Create or edit `~/.config/nvim/lua/plugins/multilinea.lua`:

```lua
return {
  dir = "/home/cubanmercury/Documents/projects/multilinea",  -- Local development path
  event = "BufReadPost",
  opts = {},
  config = function(_, opts)
    require("multilinea").setup(opts)
  end,
}
```

### Step 2: Restart Neovim

```bash
nvim
```

### Step 3: Verify Installation

Run the health check:
```vim
:checkhealth multilinea
```

You should see:
- ✓ Neovim version >= 0.7
- ✓ Plugin modules loaded
- ✓ Configuration loaded
- Namespace created

### Step 4: Test Basic Functionality

Create a test file:

```bash
nvim test_multilinea.txt
```

Add this content:
```
hello world
hello friends
hello there
goodbye world
hello universe
```

Now test the multi-cursor features:

1. **Test next match addition:**
   - Place cursor on first "hello"
   - Press `<C-n>` - should add cursor at second "hello"
   - Press `<C-n>` again - should add cursor at third "hello"
   - Press `<Esc>` - should clear all cursors

2. **Test all matches:**
   - Place cursor on "hello"
   - Press `<leader>ma` (usually `\ma` or space+m+a)
   - Should add cursors at all 4 "hello" occurrences
   - Press `ciw` and type "hi"
   - Press `<Esc>` - all "hello" should become "hi"
   - Press `u` to undo

3. **Test vertical cursors:**
   - Go to first line, column 0
   - Press `<C-j>` three times (Ctrl+j)
   - Should add cursors on lines below
   - Press `I` and type ">> "
   - Press `<Esc>` - should add ">> " to start of each line

4. **Test edit operations:**
   - Create cursors at multiple "world" occurrences using `<C-n>`
   - Press `ciw` and type "everyone"
   - Press `<Esc>` - all instances should change

### Step 5: Check Available Commands

```vim
:MultilineaAddCursor
:MultilineaAddNext
:MultilineaAddAll
:MultilineaClear
:MultilineaAddBelow
:MultilineaAddAbove
```

## Common Issues

### Cursors not appearing
- Check `:checkhealth multilinea`
- Verify setup() was called
- Check Neovim version >= 0.7

### Keybindings not working
- Check for conflicts with other plugins
- Verify your leader key (`:echo mapleader`)
- Try using commands instead of keybindings

### Visual artifacts
- Your terminal must support Unicode characters
- Check colorscheme compatibility
- Try customizing highlight groups

## Configuration Examples

### Minimal Setup
```lua
require("multilinea").setup()
```

### Custom Keybindings
```lua
require("multilinea").setup({
  keymaps = {
    add_cursor_next = "<C-d>",     -- Like Sublime Text
    clear_cursors = "<leader>mc",  -- Custom clear binding
  },
})
```

### Show Cursor Numbers
```lua
require("multilinea").setup({
  show_cursor_numbers = true,
})
```

### Case-Sensitive Matching
```lua
require("multilinea").setup({
  case_sensitive_search = true,
})
```

## Next Steps

1. Read the full documentation: `:help multilinea`
2. Customize keybindings to your preference
3. Try it in your real workflow
4. Report any issues on GitHub

## Getting Help

- `:help multilinea` - Full documentation
- `:checkhealth multilinea` - Diagnostic info
- GitHub Issues: https://github.com/cubanmercury/multilinea.nvim/issues

Happy multi-cursor editing! 🎉
