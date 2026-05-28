-- State management for Multilinea
-- Maintains cursor positions and plugin state

local M = {}

-- Initialize state
M.state = {
  cursors = {},
  active = false,
  mode = 'normal',
  namespace = nil,
  primary_cursor_index = 1,
  insert_mode_input = {},
  search_token = nil,
  config = {},
}

--- Initialize the state module
---@param config table Plugin configuration
function M.setup(config)
  M.state.config = config or {}
  M.state.namespace = vim.api.nvim_create_namespace('multilinea')
end

--- Check if multi-cursor mode is active
---@return boolean
function M.is_active()
  return M.state.active and #M.state.cursors > 1
end

--- Get cursor count
---@return number
function M.get_cursor_count()
  return #M.state.cursors
end

--- Get all cursor positions
---@return table
function M.get_cursors()
  return M.state.cursors
end

--- Get primary cursor
---@return table|nil
function M.get_primary_cursor()
  if #M.state.cursors == 0 then
    return nil
  end
  return M.state.cursors[M.state.primary_cursor_index]
end

--- Add cursor at position
---@param row number 1-indexed row
---@param col number 0-indexed column
---@param is_primary boolean Whether this is the primary cursor
---@return boolean success
function M.add_cursor(row, col, is_primary)
  -- Check if cursor already exists at this position
  for _, cursor in ipairs(M.state.cursors) do
    if cursor.row == row and cursor.col == col then
      return false
    end
  end

  local cursor = {
    row = row,
    col = col,
    is_primary = is_primary or false,
    register = {},
  }

  table.insert(M.state.cursors, cursor)

  if is_primary then
    M.state.primary_cursor_index = #M.state.cursors
  end

  -- Activate multi-cursor mode if we have more than one cursor
  if #M.state.cursors > 1 then
    M.state.active = true
  end

  return true
end

--- Remove cursor at position
---@param row number 1-indexed row
---@param col number 0-indexed column
---@return boolean success
function M.remove_cursor(row, col)
  for i, cursor in ipairs(M.state.cursors) do
    if cursor.row == row and cursor.col == col then
      table.remove(M.state.cursors, i)

      -- Adjust primary cursor index if needed
      if i == M.state.primary_cursor_index then
        M.state.primary_cursor_index = math.min(1, #M.state.cursors)
      elseif i < M.state.primary_cursor_index then
        M.state.primary_cursor_index = M.state.primary_cursor_index - 1
      end

      -- Deactivate if only one cursor remains
      if #M.state.cursors <= 1 then
        M.state.active = false
      end

      return true
    end
  end
  return false
end

--- Clear all cursors and reset state
function M.clear_all()
  M.state.cursors = {}
  M.state.active = false
  M.state.primary_cursor_index = 1
  M.state.insert_mode_input = {}
  M.state.search_token = nil
end

--- Set current search token for iterative matching
---@param token string|nil
function M.set_search_token(token)
  M.state.search_token = token
end

--- Get current search token for iterative matching
---@return string|nil
function M.get_search_token()
  return M.state.search_token
end

--- Update cursor position
---@param index number Cursor index
---@param row number New row
---@param col number New column
function M.update_cursor(index, row, col)
  if M.state.cursors[index] then
    M.state.cursors[index].row = row
    M.state.cursors[index].col = col
  end
end

--- Set mode
---@param mode string Mode name ('normal', 'insert', 'visual')
function M.set_mode(mode)
  M.state.mode = mode
end

--- Get current mode
---@return string
function M.get_mode()
  return M.state.mode
end

--- Get namespace ID
---@return number
function M.get_namespace()
  return M.state.namespace
end

--- Sort cursors by position (top to bottom, left to right)
function M.sort_cursors()
  table.sort(M.state.cursors, function(a, b)
    if a.row == b.row then
      return a.col < b.col
    end
    return a.row < b.row
  end)
end

--- Find cursor at position
---@param row number
---@param col number
---@return number|nil index of cursor, or nil if not found
function M.find_cursor_at(row, col)
  for i, cursor in ipairs(M.state.cursors) do
    if cursor.row == row and cursor.col == col then
      return i
    end
  end
  return nil
end

--- Get state snapshot (for debugging/serialization)
---@return table
function M.get_snapshot()
  return vim.deepcopy(M.state)
end

--- Restore state from snapshot
---@param snapshot table
function M.restore_snapshot(snapshot)
  M.state = vim.deepcopy(snapshot)
end

return M
