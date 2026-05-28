-- Cursor operations for Multilinea
-- Handles adding, removing, and manipulating cursors

local M = {}
local state = require('multilinea.state')
local render = require('multilinea.render')

--- Detect whether current mode is visual/select mode.
---@return boolean
local function is_visual_mode()
  return vim.fn.mode():match('^[vV\22sS\19]') ~= nil
end

--- Get visual selection context for matching.
--- Supports single-line characterwise visual selections.
---@return table|nil { token: string, row: number, col: number }
local function get_visual_search_context()
  local mode = vim.fn.mode()
  if not mode:match('^[vVsSV]') then
    vim.cmd('normal! \27')
    vim.notify('Unsupported visual mode for matching', vim.log.levels.WARN)
    return nil
  end

  local anchor_pos = vim.fn.getpos('v')
  local cursor_pos = vim.fn.getpos('.')
  local start_row, start_col = anchor_pos[2], anchor_pos[3]
  local end_row, end_col = cursor_pos[2], cursor_pos[3]

  if start_row > end_row or (start_row == end_row and start_col > end_col) then
    start_row, end_row = end_row, start_row
    start_col, end_col = end_col, start_col
  end

  -- Linewise visual mode: use full selected lines with no trailing newline.
  if mode:match('^V') then
    local lines = vim.api.nvim_buf_get_lines(0, start_row - 1, end_row, false)
    vim.cmd('normal! \27')

    if #lines == 0 then
      return nil
    end

    return {
      token = table.concat(lines, '\n'),
      row = start_row,
      col = 0,
    }
  end

  if start_row ~= end_row then
    vim.cmd('normal! \27')
    vim.notify('Multi-line visual matching is not supported yet', vim.log.levels.WARN)
    return nil
  end

  if vim.o.selection == 'exclusive' and end_col > start_col then
    end_col = end_col - 1
  end

  if end_col < start_col then
    vim.cmd('normal! \27')
    vim.notify('No visual selection', vim.log.levels.WARN)
    return nil
  end

  local line = vim.api.nvim_buf_get_lines(0, start_row - 1, start_row, false)[1] or ''
  local text = line:sub(start_col, end_col)

  vim.cmd('normal! \27')

  if not text or text == '' then
    return nil
  end

  return {
    token = text,
    row = start_row,
    col = start_col - 1,
  }
end

---@param lines string[]
---@return integer[]
local function build_line_offsets(lines)
  local offsets = {}
  local offset = 1

  for i, line in ipairs(lines) do
    offsets[i] = offset
    offset = offset + #line
    if i < #lines then
      offset = offset + 1
    end
  end

  return offsets
end

---@param abs_col integer 1-based absolute column in joined buffer text
---@param lines string[]
---@param line_offsets integer[]
---@return integer, integer row (1-based), col (0-based)
local function absolute_to_row_col(abs_col, lines, line_offsets)
  local row = 1
  for i = #line_offsets, 1, -1 do
    if abs_col >= line_offsets[i] then
      row = i
      break
    end
  end

  local col = abs_col - line_offsets[row]
  if col < 0 then
    col = 0
  end

  return row, col
end

---@param row integer 1-based row
---@param col integer 0-based col
---@param line_offsets integer[]
---@return integer
local function row_col_to_absolute(row, col, line_offsets)
  return line_offsets[row] + col
end

---@param pattern string
---@param lines string[]
---@param case_sensitive boolean
---@return table[]
local function find_all_matches_multiline(pattern, lines, case_sensitive)
  local matches = {}
  local joined_text = table.concat(lines, '\n')
  local search_text = case_sensitive and joined_text or joined_text:lower()
  local search_pattern = case_sensitive and pattern or pattern:lower()
  local line_offsets = build_line_offsets(lines)

  local pos = 1
  while pos <= #search_text do
    local match_start = string.find(search_text, search_pattern, pos, true)
    if not match_start then
      break
    end

    local row, col = absolute_to_row_col(match_start, lines, line_offsets)
    table.insert(matches, { row = row, col = col })
    pos = match_start + 1
  end

  return matches
end

---@param pattern string
---@param start_row integer
---@param start_col integer
---@param lines string[]
---@param case_sensitive boolean
---@return table|nil
local function find_next_match_multiline(pattern, start_row, start_col, lines, case_sensitive)
  local joined_text = table.concat(lines, '\n')
  local search_text = case_sensitive and joined_text or joined_text:lower()
  local search_pattern = case_sensitive and pattern or pattern:lower()
  local line_offsets = build_line_offsets(lines)
  local start_abs = row_col_to_absolute(start_row, start_col, line_offsets)

  local match_start = string.find(search_text, search_pattern, start_abs + 1, true)
  if match_start then
    local row, col = absolute_to_row_col(match_start, lines, line_offsets)
    return { row = row, col = col }
  end

  if start_abs > 1 then
    local wrapped_match = string.find(search_text, search_pattern, 1, true)
    if wrapped_match and wrapped_match < start_abs then
      local row, col = absolute_to_row_col(wrapped_match, lines, line_offsets)
      return { row = row, col = col }
    end
  end

  return nil
end

--- Get the literal search token.
--- In visual mode with an active selection, returns the full selected text
--- (single-line). Otherwise returns the single character under the cursor,
--- whether it is a word character or a symbol.
---@return string|nil
local function get_search_token()
  -- Visual / select mode: use the highlighted text
  if is_visual_mode() then
    local context = get_visual_search_context()
    return context and context.token or nil
  end

  -- Normal mode: single character under the cursor
  local pos = vim.api.nvim_win_get_cursor(0)
  local row, col = pos[1], pos[2]
  local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1] or ''
  local char = line:sub(col + 1, col + 1)
  if char and char ~= '' then
    return char
  end
  return nil
end

--- Find all literal matches of a pattern in buffer (matches anywhere)
---@param pattern string Search pattern
---@param bufnr number|nil Buffer number
---@param case_sensitive boolean Whether search is case sensitive
---@return table[] Array of {row, col} positions
local function find_all_matches(pattern, bufnr, case_sensitive)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local matches = {}

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  if pattern:find('\n', 1, true) then
    return find_all_matches_multiline(pattern, lines, case_sensitive)
  end

  for row, line in ipairs(lines) do
    local search_line = case_sensitive and line or line:lower()
    local search_pattern = case_sensitive and pattern or pattern:lower()
    local col = 1

    while col <= #search_line do
      local match_start = string.find(search_line, search_pattern, col, true)  -- plain text search
      if match_start then
        table.insert(matches, { row = row, col = match_start - 1 })  -- Convert to 0-indexed column
        col = match_start + 1
      else
        break
      end
    end
  end

  return matches
end

--- Find next literal match of token after current position (matches anywhere)
---@param word string Token to search for
---@param start_row number Starting row (1-indexed)
---@param start_col number Starting column (0-indexed)
---@param case_sensitive boolean Case sensitive search
---@return table|nil Position {row, col} or nil if not found
local function find_next_match(word, start_row, start_col, case_sensitive)
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local total_lines = #lines

  if word:find('\n', 1, true) then
    return find_next_match_multiline(word, start_row, start_col, lines, case_sensitive)
  end

  -- Build search pattern
  local pattern = word
  if not case_sensitive then
    pattern = pattern:lower()
  end

  -- Search from start position to end of buffer
  for row = start_row, total_lines do
    local line = lines[row]
    local search_line = case_sensitive and line or line:lower()
    local search_from = (row == start_row) and (start_col + 2) or 1  -- +2 to skip current position

    local match_start = string.find(search_line, pattern, search_from, true)  -- plain search
    if match_start then
      return { row = row, col = match_start - 1 }  -- Convert to 0-indexed col
    end
  end

  -- Wrap around: search from beginning to start position
  for row = 1, start_row - 1 do
    local line = lines[row]
    local search_line = case_sensitive and line or line:lower()

    local match_start = string.find(search_line, pattern, 1, true)
    if match_start then
      return { row = row, col = match_start - 1 }
    end
  end

  -- Also check from beginning of start_row up to start_col
  if start_row <= total_lines then
    local line = lines[start_row]
    local search_line = case_sensitive and line or line:lower()

    local match_start = string.find(search_line, pattern, 1, true)
    if match_start and match_start - 1 < start_col then
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

--- Add cursor at next match (VSCode Ctrl-N behavior).
--- Matches the single character under the cursor, or the full selection in
--- visual mode, as a literal substring anywhere in the buffer.
function M.add_cursor_next()
  local config = state.state.config
  local case_sensitive = config.case_sensitive_search or false
  local use_new_token = state.get_cursor_count() == 0 or is_visual_mode()
  local token = state.get_search_token()

  if use_new_token then
    token = get_search_token()
    if not token or token == '' then
      vim.notify('No character under cursor', vim.log.levels.WARN)
      return false
    end
    state.set_search_token(token)
  elseif not token or token == '' then
    token = get_search_token()
    if not token or token == '' then
      vim.notify('No character under cursor', vim.log.levels.WARN)
      return false
    end
    state.set_search_token(token)
  end

  -- First invocation should add the primary cursor after token capture.
  if state.get_cursor_count() == 0 then
    M.add_cursor_at_pos()
  end

  -- Find last cursor position to search from
  local cursors = state.get_cursors()
  state.sort_cursors()

  local last_cursor = cursors[#cursors]
  local next_pos = find_next_match(
    token,
    last_cursor.row,
    last_cursor.col,
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

--- Add cursor at next match from visual selection.
--- Uses the selected text as token and anchors the primary cursor at
--- selection start.
function M.add_cursor_next_visual()
  local config = state.state.config
  local case_sensitive = config.case_sensitive_search or false
  local context = get_visual_search_context()

  if not context or not context.token or context.token == '' then
    vim.notify('No character under cursor', vim.log.levels.WARN)
    return false
  end

  state.set_search_token(context.token)

  if state.get_cursor_count() == 0 then
    vim.api.nvim_win_set_cursor(0, { context.row, context.col })
    M.add_cursor_at_pos()
  end

  local cursors = state.get_cursors()
  state.sort_cursors()

  local last_cursor = cursors[#cursors]
  local next_pos = find_next_match(
    context.token,
    last_cursor.row,
    last_cursor.col,
    case_sensitive
  )

  if next_pos then
    local was_active = state.is_active()
    if state.add_cursor(next_pos.row, next_pos.col, false) then
      if not was_active and state.is_active() then
        local keymaps = require('multilinea.keymaps')
        keymaps.enable_multicursor_mode()
      end
      render.update()
      return true
    end
    vim.notify('Cursor already exists at this position', vim.log.levels.INFO)
    return false
  end

  vim.notify('No more matches found', vim.log.levels.INFO)
  return false
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

--- Add cursors at all matches of current token.
--- Matches the single character under the cursor, or the full selection in
--- visual mode, as a literal substring anywhere in the buffer.
function M.add_all_matches()
  local config = state.state.config
  local case_sensitive = config.case_sensitive_search or false

  local token = get_search_token()
  if not token or token == '' then
    vim.notify('No character under cursor', vim.log.levels.WARN)
    return false
  end

  -- Clear existing cursors
  state.clear_all()
  state.set_search_token(token)

  -- Find all matches
  local matches = find_all_matches(token, nil, case_sensitive)

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

--- Add cursors at all matches from visual selection.
function M.add_all_matches_visual()
  local config = state.state.config
  local case_sensitive = config.case_sensitive_search or false
  local context = get_visual_search_context()

  if not context or not context.token or context.token == '' then
    vim.notify('No character under cursor', vim.log.levels.WARN)
    return false
  end

  state.clear_all()
  state.set_search_token(context.token)

  local matches = find_all_matches(context.token, nil, case_sensitive)

  if #matches == 0 then
    vim.notify('No matches found', vim.log.levels.INFO)
    return false
  end

  for i, match in ipairs(matches) do
    state.add_cursor(match.row, match.col, i == 1)
  end

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

  state.set_search_token(nil)
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
