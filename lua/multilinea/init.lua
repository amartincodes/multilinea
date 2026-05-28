-- Multilinea - Multi-Cursor Plugin for Neovim
-- Main entry point and setup

local M = {}

-- Default configuration
local default_config = {
  -- Keybindings
  keymaps = {
    add_cursor_next = '<C-n>', -- Add cursor at next match
    add_cursor_below = '<C-j>', -- Add cursor below
    add_cursor_above = '<C-k>', -- Add cursor above
    add_all_matches = '<leader>ma', -- Add all matches
    remove_cursor = '<M-x>', -- Remove current cursor
    clear_cursors = '<Esc>', -- Clear all cursors
    skip_match = '<leader>ms', -- Skip current match
    add_cursor_here = '<leader>mc', -- Add cursor at current position
  },

  -- Visual appearance
  highlights = {
    primary = 'CursorLine',
    secondary = 'Visual',
  },

  -- Behavior
  show_cursor_numbers = false, -- Show cursor index numbers
  case_sensitive_search = false, -- Case sensitivity for matching
}

-- Module references
local state = nil
local render = nil
local operations = nil
local modes = nil
local keymaps = nil

--- Merge user config with defaults
---@param user_config table|nil User configuration
---@return table
local function merge_config(user_config)
  user_config = user_config or {}

  local config = vim.deepcopy(default_config)

  -- Merge keymaps
  if user_config.keymaps then
    config.keymaps = vim.tbl_extend('force', config.keymaps, user_config.keymaps)
  end

  -- Merge highlights
  if user_config.highlights then
    config.highlights = vim.tbl_extend('force', config.highlights, user_config.highlights)
  end

  -- Merge behavior options
  if user_config.show_cursor_numbers ~= nil then
    config.show_cursor_numbers = user_config.show_cursor_numbers
  end
  if user_config.case_sensitive_search ~= nil then
    config.case_sensitive_search = user_config.case_sensitive_search
  end

  return config
end

--- Setup the plugin
---@param user_config table|nil User configuration
function M.setup(user_config)
  -- Merge configuration
  local config = merge_config(user_config)

  -- Lazy-load modules
  state = require('multilinea.state')
  render = require('multilinea.render')
  operations = require('multilinea.operations')
  modes = require('multilinea.modes')
  keymaps = require('multilinea.keymaps')

  -- Initialize modules
  state.setup(config)
  render.setup()
  modes.setup()
  keymaps.setup(config)
  keymaps.setup_commands()

  -- Store config globally for access by other modules
  M.config = config

  -- Set up plugin autocmds
  M.setup_autocmds()

  -- Notify user
  if vim.g.multilinea_debug then
    vim.notify('Multilinea loaded', vim.log.levels.INFO)
  end
end

--- Setup plugin auto-commands
function M.setup_autocmds()
  local group = vim.api.nvim_create_augroup('Multilinea', { clear = true })

  -- Clear cursors when switching buffers
  vim.api.nvim_create_autocmd('BufLeave', {
    group = group,
    callback = function()
      if state and state.is_active() then
        operations.clear_all()
      end
    end,
  })

  -- Update render on window resize
  vim.api.nvim_create_autocmd('VimResized', {
    group = group,
    callback = function()
      if state and state.is_active() then
        render.update()
      end
    end,
  })

  -- Handle mode changes
  vim.api.nvim_create_autocmd('ModeChanged', {
    group = group,
    callback = function(args)
      if not state or not state.is_active() then
        return
      end

      local mode = vim.fn.mode()

      -- Clear cursors when entering command-line mode
      if mode:match('^c') then
        operations.clear_all()
      end
    end,
  })
end

--- Check if plugin is active
---@return boolean
function M.is_active()
  if not state then
    return false
  end
  return state.is_active()
end

--- Get cursor count
---@return number
function M.get_cursor_count()
  if not state then
    return 0
  end
  return state.get_cursor_count()
end

--- Public API for other plugins
M.api = {
  --- Add cursor at position
  add_cursor = function(row, col, is_primary)
    if not operations then
      return false
    end
    return state.add_cursor(row, col, is_primary)
  end,

  --- Remove cursor at position
  remove_cursor = function(row, col)
    if not operations then
      return false
    end
    return state.remove_cursor(row, col)
  end,

  --- Clear all cursors
  clear_all = function()
    if not operations then
      return
    end
    operations.clear_all()
  end,

  --- Get all cursor positions
  get_cursors = function()
    if not state then
      return {}
    end
    return state.get_cursors()
  end,

  --- Check if active
  is_active = M.is_active,

  --- Get cursor count
  get_count = M.get_cursor_count,
}

--- Health check for :checkhealth
function M.check()
  vim.health.start('Multilinea')

  -- Check Neovim version
  local version = vim.version()
  if version.major >= 0 and version.minor >= 7 then
    vim.health.ok('Neovim version >= 0.7')
  else
    vim.health.error('Neovim version < 0.7', {
      'Multilinea requires Neovim 0.7 or later',
      'Please upgrade Neovim',
    })
  end

  -- Check if plugin is loaded
  if state then
    vim.health.ok('Plugin modules loaded')
  else
    vim.health.warn('Plugin not initialized', {
      'Call require("multilinea").setup() to initialize',
    })
  end

  -- Check configuration
  if M.config then
    vim.health.ok('Configuration loaded')

    -- Check keymaps
    local keymap_count = 0
    for k, v in pairs(M.config.keymaps) do
      if v and v ~= '' then
        keymap_count = keymap_count + 1
      end
    end
    vim.health.info(string.format('%d keymaps configured', keymap_count))
  end

  -- Check namespace
  if state and state.get_namespace() then
    vim.health.ok('Namespace created: ' .. state.get_namespace())
  end
end

return M
