-- Keybinding setup for Multilinea

local M = {}
local operations = require('multilinea.operations')
local modes = require('multilinea.modes')

-- Store keymap IDs for cleanup
local keymap_ids = {}
local multicursor_keymap_ids = {}

--- Clear all keymaps
function M.clear()
  for _, id in ipairs(keymap_ids) do
    pcall(vim.keymap.del, id.mode, id.lhs, { buffer = id.buffer })
  end
  keymap_ids = {}
end

--- Setup a keymap and track it
---@param mode string|table Mode(s)
---@param lhs string Left-hand side (key combination)
---@param rhs string|function Right-hand side (command or function)
---@param opts table|nil Options
---@param is_multicursor boolean|nil If true, track as multicursor-specific keymap
local function setup_keymap(mode, lhs, rhs, opts, is_multicursor)
  opts = opts or {}
  opts.silent = opts.silent ~= false
  opts.noremap = opts.noremap ~= false

  vim.keymap.set(mode, lhs, rhs, opts)

  -- Track for cleanup
  local modes_list = type(mode) == 'table' and mode or { mode }
  for _, m in ipairs(modes_list) do
    local keymap_entry = {
      mode = m,
      lhs = lhs,
      buffer = opts.buffer,
    }

    if is_multicursor then
      table.insert(multicursor_keymap_ids, keymap_entry)
    else
      table.insert(keymap_ids, keymap_entry)
    end
  end
end

--- Setup default keymaps
---@param config table Plugin configuration
function M.setup(config)
  local keymaps = config.keymaps or {}

  -- Add cursor at next match (VSCode Ctrl-N style)
  if keymaps.add_cursor_next then
    setup_keymap({ 'n', 'x' }, keymaps.add_cursor_next, function()
      operations.add_cursor_next()
    end, { desc = 'Add cursor at next match' })
  end

  -- Add cursor below
  if keymaps.add_cursor_below then
    setup_keymap('n', keymaps.add_cursor_below, function()
      operations.add_cursor_below()
    end, { desc = 'Add cursor below' })
  end

  -- Add cursor above
  if keymaps.add_cursor_above then
    setup_keymap('n', keymaps.add_cursor_above, function()
      operations.add_cursor_above()
    end, { desc = 'Add cursor above' })
  end

  -- Add cursors at all matches
  if keymaps.add_all_matches then
    setup_keymap({ 'n', 'x' }, keymaps.add_all_matches, function()
      operations.add_all_matches()
    end, { desc = 'Add cursors at all matches' })
  end

  -- Remove cursor at current position
  if keymaps.remove_cursor then
    setup_keymap('n', keymaps.remove_cursor, function()
      operations.remove_cursor_at_pos()
    end, { desc = 'Remove cursor at position' })
  end

  -- Clear all cursors
  if keymaps.clear_cursors then
    setup_keymap('n', keymaps.clear_cursors, function()
      operations.clear_all()
    end, { desc = 'Clear all cursors' })
  end

  -- Skip current match and find next
  if keymaps.skip_match then
    setup_keymap('n', keymaps.skip_match, function()
      operations.skip_match()
    end, { desc = 'Skip current match' })
  end

  -- Add cursor at current position (manual)
  if keymaps.add_cursor_here then
    setup_keymap('n', keymaps.add_cursor_here, function()
      operations.add_cursor_at_pos()
    end, { desc = 'Add cursor at position' })
  end

  -- Motion keymaps when multi-cursor is active
  M.setup_motion_keymaps()
end

--- Setup motion keymaps for multi-cursor mode
function M.setup_motion_keymaps()
  -- These are set up as buffer-local mappings that only work when multi-cursor is active
  -- They intercept common motions and apply them to all cursors

  local motions = {
    -- Word motions
    'w', 'W', 'b', 'B', 'e', 'E',
    -- Line motions
    '0', '^', '$', 'g_',
    -- Character motions
    'h', 'j', 'k', 'l',
    -- Search motions
    'f', 'F', 't', 'T',
    -- Paragraph motions
    '{', '}',
    -- Other
    'gg', 'G',
  }

  -- Note: These should be dynamically enabled/disabled based on multi-cursor state
  -- For now, they're defined as commands that check state before executing
end

--- Setup operator keymaps for multi-cursor mode
function M.setup_operator_keymaps()
  local operators = {
    'd', -- delete
    'c', -- change
    'y', -- yank
    'p', -- paste
    'P', -- paste before
  }

  -- These will need to be context-aware
end

--- Enable multi-cursor keymaps
function M.enable_multicursor_mode()
  -- Prevent double-enabling keymaps
  if #multicursor_keymap_ids > 0 then
    return
  end

  -- Character motions
  setup_keymap('n', 'h', function()
    operations.apply_to_all('h')
  end, { desc = 'Move left at all cursors' }, true)

  setup_keymap('n', 'j', function()
    operations.apply_to_all('j')
  end, { desc = 'Move down at all cursors' }, true)

  setup_keymap('n', 'k', function()
    operations.apply_to_all('k')
  end, { desc = 'Move up at all cursors' }, true)

  setup_keymap('n', 'l', function()
    operations.apply_to_all('l')
  end, { desc = 'Move right at all cursors' }, true)

  -- Word motions
  setup_keymap('n', 'w', function()
    operations.apply_to_all('w')
  end, { desc = 'Move to next word at all cursors' }, true)

  setup_keymap('n', 'W', function()
    operations.apply_to_all('W')
  end, { desc = 'Move to next WORD at all cursors' }, true)

  setup_keymap('n', 'b', function()
    operations.apply_to_all('b')
  end, { desc = 'Move to previous word at all cursors' }, true)

  setup_keymap('n', 'B', function()
    operations.apply_to_all('B')
  end, { desc = 'Move to previous WORD at all cursors' }, true)

  setup_keymap('n', 'e', function()
    operations.apply_to_all('e')
  end, { desc = 'Move to end of word at all cursors' }, true)

  setup_keymap('n', 'E', function()
    operations.apply_to_all('E')
  end, { desc = 'Move to end of WORD at all cursors' }, true)

  -- Line motions
  setup_keymap('n', '0', function()
    operations.apply_to_all('0')
  end, { desc = 'Move to line start at all cursors' }, true)

  setup_keymap('n', '^', function()
    operations.apply_to_all('^')
  end, { desc = 'Move to first non-blank at all cursors' }, true)

  setup_keymap('n', '$', function()
    operations.apply_to_all('$')
  end, { desc = 'Move to line end at all cursors' }, true)

  setup_keymap('n', 'g_', function()
    operations.apply_to_all('g_')
  end, { desc = 'Move to last non-blank at all cursors' }, true)

  -- Paragraph motions
  setup_keymap('n', '{', function()
    operations.apply_to_all('{')
  end, { desc = 'Move to previous paragraph at all cursors' }, true)

  setup_keymap('n', '}', function()
    operations.apply_to_all('}')
  end, { desc = 'Move to next paragraph at all cursors' }, true)

  -- File motions
  setup_keymap('n', 'gg', function()
    operations.apply_to_all('gg')
  end, { desc = 'Move to file start at all cursors' }, true)

  setup_keymap('n', 'G', function()
    operations.apply_to_all('G')
  end, { desc = 'Move to file end at all cursors' }, true)

  -- Insert mode entry
  setup_keymap('n', 'i', function()
    modes.enter_insert_mode('i')
  end, { desc = 'Enter insert mode at all cursors' }, true)

  setup_keymap('n', 'a', function()
    modes.enter_insert_mode('a')
  end, { desc = 'Append at all cursors' }, true)

  setup_keymap('n', 'I', function()
    operations.apply_to_all('^')
    modes.enter_insert_mode('i')
  end, { desc = 'Insert at line start' }, true)

  setup_keymap('n', 'A', function()
    operations.apply_to_all('$')
    modes.enter_insert_mode('a')  -- Use append mode after $ to insert at end
  end, { desc = 'Append at line end' }, true)

  setup_keymap('n', 'o', function()
    operations.apply_to_all('o')
    modes.enter_insert_mode('i')  -- New line, so insert mode is correct
  end, { desc = 'Open line below at all cursors' }, true)

  setup_keymap('n', 'O', function()
    operations.apply_to_all('O')
    modes.enter_insert_mode('i')  -- New line, so insert mode is correct
  end, { desc = 'Open line above at all cursors' }, true)

  -- Delete operations
  setup_keymap('n', 'x', function()
    operations.apply_to_all('x')
  end, { desc = 'Delete character at all cursors' }, true)

  setup_keymap('n', 'r', function()
    local ok, replace_char = pcall(vim.fn.getcharstr)
    if not ok or not replace_char or replace_char == '' or replace_char == '\27' then
      return
    end

    local escaped_char = vim.fn.escape(replace_char, '\\|')
    operations.apply_to_all('r' .. escaped_char)
  end, { desc = 'Replace character at all cursors' }, true)

  setup_keymap('n', 'dd', function()
    operations.apply_to_all('dd')
  end, { desc = 'Delete line at all cursors' }, true)

  setup_keymap('n', 'D', function()
    operations.apply_to_all('D')
  end, { desc = 'Delete to end of line' }, true)

  setup_keymap('n', 'dw', function()
    operations.apply_to_all('dw')
  end, { desc = 'Delete word at all cursors' }, true)

  setup_keymap('n', 'db', function()
    operations.apply_to_all('db')
  end, { desc = 'Delete back word at all cursors' }, true)

  -- Change operations (use delete + insert to avoid insert mode conflicts)
  setup_keymap('n', 'cc', function()
    operations.apply_to_all('dd')
    modes.enter_insert_mode('i')
  end, { desc = 'Change line at all cursors' }, true)

  setup_keymap('n', 'C', function()
    operations.apply_to_all('D')
    modes.enter_insert_mode('i')
  end, { desc = 'Change to end of line at all cursors' }, true)

  setup_keymap('n', 'cw', function()
    operations.apply_to_all('dw')
    modes.enter_insert_mode('i')
  end, { desc = 'Change word at all cursors' }, true)

  -- Yank operations
  setup_keymap('n', 'yy', function()
    operations.apply_to_all('yy')
  end, { desc = 'Yank line at all cursors' }, true)

  setup_keymap('n', 'Y', function()
    operations.apply_to_all('Y')
  end, { desc = 'Yank to end of line at all cursors' }, true)

  setup_keymap('n', 'yw', function()
    operations.apply_to_all('yw')
  end, { desc = 'Yank word at all cursors' }, true)

  -- Paste operations
  setup_keymap('n', 'p', function()
    operations.apply_to_all('p')
  end, { desc = 'Paste after at all cursors' }, true)

  setup_keymap('n', 'P', function()
    operations.apply_to_all('P')
  end, { desc = 'Paste before at all cursors' }, true)

  -- Additional delete operations
  setup_keymap('n', 'de', function()
    operations.apply_to_all('de')
  end, { desc = 'Delete to end of word at all cursors' }, true)

  setup_keymap('n', 'dE', function()
    operations.apply_to_all('dE')
  end, { desc = 'Delete to end of WORD at all cursors' }, true)

  setup_keymap('n', 'd0', function()
    operations.apply_to_all('d0')
  end, { desc = 'Delete to start of line at all cursors' }, true)

  setup_keymap('n', 'd^', function()
    operations.apply_to_all('d^')
  end, { desc = 'Delete to first non-blank at all cursors' }, true)

  setup_keymap('n', 'X', function()
    operations.apply_to_all('X')
  end, { desc = 'Delete character before cursor at all cursors' }, true)

  -- Additional change operations (use delete + insert to avoid insert mode conflicts)
  setup_keymap('n', 'ce', function()
    operations.apply_to_all('de')
    modes.enter_insert_mode('i')
  end, { desc = 'Change to end of word at all cursors' }, true)

  setup_keymap('n', 'cE', function()
    operations.apply_to_all('dE')
    modes.enter_insert_mode('i')
  end, { desc = 'Change to end of WORD at all cursors' }, true)

  setup_keymap('n', 'cb', function()
    operations.apply_to_all('db')
    modes.enter_insert_mode('i')
  end, { desc = 'Change back word at all cursors' }, true)

  setup_keymap('n', 'c0', function()
    operations.apply_to_all('d0')
    modes.enter_insert_mode('i')
  end, { desc = 'Change to start of line at all cursors' }, true)

  setup_keymap('n', 'c^', function()
    operations.apply_to_all('d^')
    modes.enter_insert_mode('i')
  end, { desc = 'Change to first non-blank at all cursors' }, true)

  -- Additional yank operations
  setup_keymap('n', 'ye', function()
    operations.apply_to_all('ye')
  end, { desc = 'Yank to end of word at all cursors' }, true)

  setup_keymap('n', 'yE', function()
    operations.apply_to_all('yE')
  end, { desc = 'Yank to end of WORD at all cursors' }, true)

  setup_keymap('n', 'yb', function()
    operations.apply_to_all('yb')
  end, { desc = 'Yank back word at all cursors' }, true)

  setup_keymap('n', 'y0', function()
    operations.apply_to_all('y0')
  end, { desc = 'Yank to start of line at all cursors' }, true)

  setup_keymap('n', 'y^', function()
    operations.apply_to_all('y^')
  end, { desc = 'Yank to first non-blank at all cursors' }, true)

  -- Indentation
  setup_keymap('n', '>>', function()
    operations.apply_to_all('>>')
  end, { desc = 'Indent line at all cursors' }, true)

  setup_keymap('n', '<<', function()
    operations.apply_to_all('<<')
  end, { desc = 'Unindent line at all cursors' }, true)

  -- Case toggle
  setup_keymap('n', '~', function()
    operations.apply_to_all('~')
  end, { desc = 'Toggle case at all cursors' }, true)
end

--- Disable multi-cursor keymaps
function M.disable_multicursor_mode()
  -- Remove only multicursor-specific keymaps
  for _, id in ipairs(multicursor_keymap_ids) do
    pcall(vim.keymap.del, id.mode, id.lhs, { buffer = id.buffer })
  end
  multicursor_keymap_ids = {}
end

--- Setup user commands
function M.setup_commands()
  -- Command to add cursor
  vim.api.nvim_create_user_command('MultilineaAddCursor', function()
    operations.add_cursor_at_pos()
  end, { desc = 'Add cursor at current position' })

  -- Command to add cursor at next match
  vim.api.nvim_create_user_command('MultilineaAddNext', function()
    operations.add_cursor_next()
  end, { desc = 'Add cursor at next match' })

  -- Command to add all matches
  vim.api.nvim_create_user_command('MultilineaAddAll', function()
    operations.add_all_matches()
  end, { desc = 'Add cursors at all matches' })

  -- Command to clear cursors
  vim.api.nvim_create_user_command('MultilineaClear', function()
    operations.clear_all()
  end, { desc = 'Clear all cursors' })

  -- Command to add cursor below
  vim.api.nvim_create_user_command('MultilineaAddBelow', function()
    operations.add_cursor_below()
  end, { desc = 'Add cursor below' })

  -- Command to add cursor above
  vim.api.nvim_create_user_command('MultilineaAddAbove', function()
    operations.add_cursor_above()
  end, { desc = 'Add cursor above' })
end

return M
