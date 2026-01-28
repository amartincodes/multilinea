-- Cursor operations for Multilinea
-- Handles adding, removing, and manipulating cursors

local M = {}
local state = require('multilinea.state')
local render = require('multilinea.render')

--- Get word under cursor
---@return string|nil
local function get_word_under_cursor()
  local word = vim.fn.expand('<cword>')
  if word and word ~= '' then
    return word
  end
  return nil
end

--- Find all matches of a pattern in buffer
---@param pattern string Search pattern
---@param bufnr number|nil Buffer number
---@param whole_word boolean Whether to match whole words only
---@param case_sensitive boolean Whether search is case sensitive
---@return table[] Array of {row, col} positions
local function find_all_matches(pattern, bufnr, whole_word, case_sensitive)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local matches = {}

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  -- Helper function to check if match is whole word
  local function is_whole_word_match(line, match_start, match_end)
    if not whole_word then
      return true
    end
    local before = match_start == 1 or line:sub(match_start - 1, match_start - 1):match('%W')
    local after = match_end >= #line or line:sub(match_end + 1, match_end + 1):match('%W')
    return before and after
  end

  for row, line in ipairs(lines) do
    local search_line = case_sensitive and line or line:lower()
    local search_pattern = case_sensitive and pattern or pattern:lower()
    local col = 1

    while col <= #search_line do
      local match_start, match_end = string.find(search_line, search_pattern, col, true)  -- plain text search
      if match_start then
        if is_whole_word_match(line, match_start, match_end) then
          table.insert(matches, { row = row, col = match_start - 1 })  -- Convert to 0-indexed column
        end
        col = match_start + 1
      else
        break
      end
    end
  end

  return matches
end

--- Find next match of word after current position
---@param word string Word to search for
---@param start_row number Starting row (1-indexed)
---@param start_col number Starting column (0-indexed)
---@param whole_word boolean Match whole words only
---@param case_sensitive boolean Case sensitive search
---@return table|nil Position {row, col} or nil if not found
local function find_next_match(word, start_row, start_col, whole_word, case_sensitive)
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local total_lines = #lines

  -- Build search pattern
  local pattern = word
  if not case_sensitive then
    pattern = pattern:lower()
  end

  -- Helper function to check if match is whole word
  local function is_whole_word_match(line, match_start, match_end)
    if not whole_word then
      return true
    end

    local before = match_start == 1 or line:sub(match_start - 1, match_start - 1):match('%W')
    local after = match_end >= #line or line:sub(match_end + 1, match_end + 1):match('%W')
    return before and after
  end

  -- Search from start position to end of buffer
  for row = start_row, total_lines do
    local line = lines[row]
    local search_line = case_sensitive and line or line:lower()
    local search_from = (row == start_row) and (start_col + 2) or 1  -- +2 to skip current position

    while search_from <= #search_line do
      local match_start, match_end = string.find(search_line, pattern, search_from, true)  -- plain search

      if match_start then
        if is_whole_word_match(line, match_start, match_end) then
          return { row = row, col = match_start - 1 }  -- Convert to 0-indexed col
        end
        search_from = match_start + 1  -- Try next position in line
      else
        break  -- No more matches in this line
      end
    end
  end

  -- Wrap around: search from beginning to start position
  for row = 1, start_row - 1 do
    local line = lines[row]
    local search_line = case_sensitive and line or line:lower()

    local match_start, match_end = string.find(search_line, pattern, 1, true)
    if match_start and is_whole_word_match(line, match_start, match_end) then
      return { row = row, col = match_start - 1 }
    end
  end

  -- Also check from beginning of start_row up to start_col
  if start_row <= total_lines then
    local line = lines[start_row]
    local search_line = case_sensitive and line or line:lower()

    local match_start, match_end = string.find(search_line, pattern, 1, true)
    if match_start and match_start - 1 < start_col and is_whole_word_match(line, match_start, match_end) then
      return { row = start_row, col = match_start - 1 }
    end
  end

  return nil  -- No match found
end

--- Add cursor at current position
function M.add_cursor_at_pos()
  local pos = vim.api.nvim_win_get_cursor(0)
  local row, col = pos[1], pos[2]

  -- If this is the first cursor, add it as primary
  local is_primary = state.get_cursor_count() == 0
  local was_active = state.is_active()

  if state.add_cursor(row, col, is_primary) then
    -- Enable multicursor keymaps when mode becomes active (2+ cursors)
    if not was_active and state.is_active() then
      local keymaps = require('multilinea.keymaps')
      keymaps.enable_multicursor_mode()
    end
    render.update()
    return true
  end

  return false
end

--- Add cursor at next word match (VSCode Ctrl-N behavior)
function M.add_cursor_next()
  local config = state.state.config
  local whole_word = config.whole_word_match ~= false
  local case_sensitive = config.case_sensitive_search or false

  -- Get word under cursor or at primary cursor
  local word
  if state.get_cursor_count() == 0 then
    -- First invocation - add cursor at current position and get word
    M.add_cursor_at_pos()
    word = get_word_under_cursor()
  else
    -- Get word from primary cursor
    local primary = state.get_primary_cursor()
    if primary then
      vim.api.nvim_win_set_cursor(0, { primary.row, primary.col })
      word = get_word_under_cursor()
    end
  end

  if not word or word == '' then
    vim.notify('No word under cursor', vim.log.levels.WARN)
    return false
  end

  -- Find last cursor position to search from
  local cursors = state.get_cursors()
  state.sort_cursors()

  local last_cursor = cursors[#cursors]
  local next_pos = find_next_match(
    word,
    last_cursor.row,
    last_cursor.col,
    whole_word,
    case_sensitive
  )

  if next_pos then
    local was_active = state.is_active()
    if state.add_cursor(next_pos.row, next_pos.col, false) then
      -- Enable multicursor keymaps when mode becomes active (2+ cursors)
      if not was_active and state.is_active() then
        local keymaps = require('multilinea.keymaps')
        keymaps.enable_multicursor_mode()
      end
      render.update()
      return true
    else
      vim.notify('Cursor already exists at this position', vim.log.levels.INFO)
      return false
    end
  else
    vim.notify('No more matches found', vim.log.levels.INFO)
    return false
  end
end

--- Add cursor below current position
function M.add_cursor_below()
  local pos = vim.api.nvim_win_get_cursor(0)
  local row, col = pos[1], pos[2]

  -- Add current position if no cursors exist
  if state.get_cursor_count() == 0 then
    M.add_cursor_at_pos()
  end

  -- Find the bottommost cursor to add below it
  local cursors = state.get_cursors()
  local bottom_row = row
  for _, cursor in ipairs(cursors) do
    if cursor.row > bottom_row then
      bottom_row = cursor.row
    end
  end

  -- Add cursor on next line after bottommost cursor
  local new_row = bottom_row + 1
  local line_count = vim.api.nvim_buf_line_count(0)

  if new_row > line_count then
    vim.notify('Already at last line', vim.log.levels.INFO)
    return false
  end

  -- Adjust column if line is shorter
  local line = vim.api.nvim_buf_get_lines(0, new_row - 1, new_row, false)[1] or ''
  local new_col = math.min(col, #line)

  local was_active = state.is_active()
  if state.add_cursor(new_row, new_col, false) then
    -- Enable multicursor keymaps when mode becomes active (2+ cursors)
    if not was_active and state.is_active() then
      local keymaps = require('multilinea.keymaps')
      keymaps.enable_multicursor_mode()
    end
    render.update()
    return true
  end

  return false
end

--- Add cursor above current position
function M.add_cursor_above()
  local pos = vim.api.nvim_win_get_cursor(0)
  local row, col = pos[1], pos[2]

  -- Add current position if no cursors exist
  if state.get_cursor_count() == 0 then
    M.add_cursor_at_pos()
  end

  -- Find the topmost cursor to add above it
  local cursors = state.get_cursors()
  local top_row = row
  for _, cursor in ipairs(cursors) do
    if cursor.row < top_row then
      top_row = cursor.row
    end
  end

  -- Add cursor on previous line before topmost cursor
  local new_row = top_row - 1

  if new_row < 1 then
    vim.notify('Already at first line', vim.log.levels.INFO)
    return false
  end

  -- Adjust column if line is shorter
  local line = vim.api.nvim_buf_get_lines(0, new_row - 1, new_row, false)[1] or ''
  local new_col = math.min(col, #line)

  local was_active = state.is_active()
  if state.add_cursor(new_row, new_col, false) then
    -- Enable multicursor keymaps when mode becomes active (2+ cursors)
    if not was_active and state.is_active() then
      local keymaps = require('multilinea.keymaps')
      keymaps.enable_multicursor_mode()
    end
    render.update()
    return true
  end

  return false
end

--- Add cursors at all matches of current word
function M.add_all_matches()
  local config = state.state.config
  local whole_word = config.whole_word_match ~= false
  local case_sensitive = config.case_sensitive_search or false

  local word = get_word_under_cursor()
  if not word or word == '' then
    vim.notify('No word under cursor', vim.log.levels.WARN)
    return false
  end

  -- Clear existing cursors
  state.clear_all()

  -- Find all matches
  local matches = find_all_matches(word, nil, whole_word, case_sensitive)

  if #matches == 0 then
    vim.notify('No matches found', vim.log.levels.INFO)
    return false
  end

  -- Add cursor at each match (first one is primary)
  for i, match in ipairs(matches) do
    state.add_cursor(match.row, match.col, i == 1)
  end

  -- Enable multicursor keymaps if we have multiple cursors
  if state.is_active() then
    local keymaps = require('multilinea.keymaps')
    keymaps.enable_multicursor_mode()
  end

  render.update()
  vim.notify(string.format('Added %d cursors', #matches), vim.log.levels.INFO)
  return true
end

--- Remove cursor at current position
function M.remove_cursor_at_pos()
  local pos = vim.api.nvim_win_get_cursor(0)
  local row, col = pos[1], pos[2]

  if state.remove_cursor(row, col) then
    render.update()
    return true
  end

  vim.notify('No cursor at current position', vim.log.levels.WARN)
  return false
end

--- Clear all cursors
function M.clear_all()
  -- Disable multicursor keymaps when cursors are cleared
  local keymaps = require('multilinea.keymaps')
  keymaps.disable_multicursor_mode()

  state.clear_all()
  render.clear()
end

--- Apply a command to all cursors
---@param command string Normal mode command
function M.apply_to_all(command)
  if not state.is_active() then
    return
  end

  local cursors = state.get_cursors()
  local bufnr = vim.api.nvim_get_current_buf()

  -- Save current position
  local saved_pos = vim.api.nvim_win_get_cursor(0)

  -- Apply command to each cursor
  for i, cursor in ipairs(cursors) do
    vim.api.nvim_win_set_cursor(0, { cursor.row, cursor.col })

    -- Execute command
    local ok, err = pcall(vim.cmd, 'normal! ' .. command)
    if not ok then
      vim.notify('Error executing command: ' .. tostring(err), vim.log.levels.ERROR)
    end

    -- Update cursor position
    local new_pos = vim.api.nvim_win_get_cursor(0)
    state.update_cursor(i, new_pos[1], new_pos[2])
  end

  -- Restore to primary cursor position
  local primary = state.get_primary_cursor()
  if primary then
    vim.api.nvim_win_set_cursor(0, { primary.row, primary.col })
  else
    vim.api.nvim_win_set_cursor(0, saved_pos)
  end

  render.update()
end

--- Skip current match and find next (for iterative matching)
function M.skip_match()
  if state.get_cursor_count() == 0 then
    vim.notify('No cursors active', vim.log.levels.WARN)
    return false
  end

  -- Remove last added cursor and find next match
  local cursors = state.get_cursors()
  local last = cursors[#cursors]

  if last then
    state.remove_cursor(last.row, last.col)
    M.add_cursor_next()
    return true
  end

  return false
end

return M
