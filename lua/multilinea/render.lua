-- Visual rendering for Multilinea using extmarks
-- Provides visual feedback for cursor positions

local M = {}
local state = require("multilinea.state")

-- Track extmark IDs for cleanup
local extmark_ids = {}

--- Setup highlight groups
function M.setup_highlights()
	-- Primary cursor highlight
	vim.api.nvim_set_hl(0, "MultilineaPrimary", {
		fg = "#ffffff",
		bg = "#5c6370",
		bold = true,
		default = true,
	})

	-- Secondary cursor highlight
	vim.api.nvim_set_hl(0, "MultilineaSecondary", {
		fg = "#61afef",
		bg = "#3e4451",
		default = true,
	})

	-- Cursor number highlight
	vim.api.nvim_set_hl(0, "MultilineaNumber", {
		fg = "#e5c07b",
		default = true,
	})

	-- Insert mode primary cursor highlight (underline style)
	vim.api.nvim_set_hl(0, "MultilineaInsertPrimary", {
		underline = true,
		sp = "#ffffff",
		bg = "#5c6370",
		default = true,
	})

	-- Insert mode secondary cursor highlight (underline style)
	vim.api.nvim_set_hl(0, "MultilineaInsertSecondary", {
		underline = true,
		sp = "#61afef",
		bg = "#3e4451",
		default = true,
	})
end

--- Clear all extmarks
---@param bufnr number|nil Buffer number (default: current buffer)
function M.clear(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local ns = state.get_namespace()

	if ns then
		vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
		extmark_ids = {}
	end
end

--- Render a single cursor
---@param bufnr number Buffer number
---@param cursor table Cursor data
---@param index number Cursor index
---@param show_numbers boolean Whether to show cursor numbers
local function render_cursor(bufnr, cursor, index, show_numbers)
	local ns = state.get_namespace()
	local row = cursor.row - 1 -- Convert to 0-indexed
	local col = cursor.col

	-- Validate position
	local line_count = vim.api.nvim_buf_line_count(bufnr)
	if row < 0 or row >= line_count then
		return
	end

	local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
	if col < 0 or col > #line then
		return
	end

	-- Determine highlight group
	local is_primary = cursor.is_primary
	local hl_group = is_primary and "MultilineaPrimary" or "MultilineaSecondary"

	-- Detect current mode
	local mode = vim.api.nvim_get_mode().mode
	local is_insert = mode:match("^i") or mode:match("^R")

	local ok, extmark_id

	if is_insert then
		-- Insert mode: highlight character with underline style
		local insert_hl = is_primary and "MultilineaInsertPrimary" or "MultilineaInsertSecondary"
		local at_eol = col >= #line

		if at_eol then
			-- At end of line: use virtual text with space
			local virt_text = { { " ", insert_hl } }
			if show_numbers then
				table.insert(virt_text, { tostring(index), "MultilineaNumber" })
			end
			ok, extmark_id = pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, row, col, {
				virt_text = virt_text,
				virt_text_pos = "overlay",
				hl_mode = "combine",
				priority = 1000,
			})
		else
			-- On a character: highlight it with insert-mode style
			ok, extmark_id = pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, row, col, {
				end_col = col + 1,
				hl_group = insert_hl,
				priority = 1000,
			})
			-- Add cursor number if enabled
			if ok and show_numbers then
				local num_ok, num_id = pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, row, col + 1, {
					virt_text = { { tostring(index), "MultilineaNumber" } },
					virt_text_pos = "inline",
					priority = 1000,
				})
				if num_ok then
					table.insert(extmark_ids, num_id)
				end
			end
		end
	else
		-- Normal mode: highlight the actual character under cursor
		local at_eol = col >= #line

		if at_eol then
			-- At end of line: use virtual text with space block
			local virt_text = { { " ", hl_group } }

			if show_numbers then
				table.insert(virt_text, { tostring(index), "MultilineaNumber" })
			end

			ok, extmark_id = pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, row, col, {
				virt_text = virt_text,
				virt_text_pos = "overlay",
				hl_mode = "combine",
				priority = 1000,
			})
		else
			-- On a character: highlight the character with hl_group
			local extmark_opts = {
				end_col = col + 1,
				hl_group = hl_group,
				priority = 1000,
			}

			ok, extmark_id = pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, row, col, extmark_opts)

			-- Add cursor number as separate extmark if enabled
			if ok and show_numbers then
				local num_ok, num_extmark_id = pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, row, col + 1, {
					virt_text = { { tostring(index), "MultilineaNumber" } },
					virt_text_pos = "inline",
					priority = 1000,
				})
				if num_ok then
					table.insert(extmark_ids, num_extmark_id)
				end
			end
		end
	end

	if ok then
		table.insert(extmark_ids, extmark_id)
	end
end

--- Update all cursor visualizations
---@param bufnr number|nil Buffer number (default: current buffer)
function M.update(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	-- Clear existing marks
	M.clear(bufnr)

	-- Don't render if not active
	if not state.is_active() then
		return
	end

	local cursors = state.get_cursors()
	local show_numbers = state.state.config.show_cursor_numbers or false

	-- Render each cursor
	for i, cursor in ipairs(cursors) do
		render_cursor(bufnr, cursor, i, show_numbers)
	end
end

--- Flash cursors for visual feedback
---@param bufnr number|nil Buffer number
function M.flash(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	-- Render cursors
	M.update(bufnr)

	-- Schedule a brief clear and re-render
	vim.defer_fn(function()
		M.clear(bufnr)
		vim.defer_fn(function()
			M.update(bufnr)
		end, 50)
	end, 100)
end

--- Setup auto-commands for rendering
function M.setup_autocmds()
	local group = vim.api.nvim_create_augroup("MultilineaRender", { clear = true })

	-- Update on cursor movement
	vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
		group = group,
		callback = function()
			if state.is_active() then
				M.update()
			end
		end,
	})

	-- Clear on buffer leave
	vim.api.nvim_create_autocmd("BufLeave", {
		group = group,
		callback = function(args)
			M.clear(args.buf)
		end,
	})

	-- Update on text changes
	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		group = group,
		callback = function()
			if state.is_active() then
				M.update()
			end
		end,
	})

	-- Clear when entering command-line mode
	vim.api.nvim_create_autocmd("CmdlineEnter", {
		group = group,
		callback = function()
			if state.is_active() then
				M.clear()
			end
		end,
	})

	-- Restore when leaving command-line mode
	vim.api.nvim_create_autocmd("CmdlineLeave", {
		group = group,
		callback = function()
			if state.is_active() then
				M.update()
			end
		end,
	})

	-- Update on mode change (to switch between block and line cursor styles)
	vim.api.nvim_create_autocmd("ModeChanged", {
		group = group,
		pattern = { "*:i*", "i*:*", "*:R*", "R*:*" },
		callback = function()
			if state.is_active() then
				M.update()
			end
		end,
	})
end

--- Initialize the render module
function M.setup()
	M.setup_highlights()
	M.setup_autocmds()
end

return M
