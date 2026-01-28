-- Multilinea plugin autoload file
-- This file is automatically sourced by Neovim

-- Prevent loading twice
if vim.g.loaded_multilinea then
  return
end
vim.g.loaded_multilinea = true

-- Check Neovim version
if vim.fn.has('nvim-0.7') == 0 then
  vim.notify('Multilinea requires Neovim 0.7 or later', vim.log.levels.ERROR)
  return
end

-- Plugin is loaded, but setup() must be called explicitly by the user
-- This allows for lazy loading and configuration

-- Optional: Auto-setup with defaults if user hasn't configured via LazyVim
-- Uncomment the following to enable automatic setup:
-- vim.defer_fn(function()
--   if not vim.g.multilinea_setup_called then
--     require('multilinea').setup()
--   end
-- end, 100)
