-- Mode handlers for Multilinea
-- Manages behavior in different Vim modes

local M = {}
local state = require("multilinea.state")
local render = require("multilinea.render")

-- Insert mode state
local insert_state = {
	active = false,
	insert_type = "i", -- 'i' for insert, 'a' for append
	primary_cursor_row = nil,
	primary_cursor_col = nil,
	last_line_content = nil, -- Track last known line content
	last_line_number = nil, -- Track which line we're watching
}

--- Handle normal mode operations
---@param command string Normal mode command to execute
function M.handle_normal_mode(command)
	if not state.is_active() then
		return
	end

	local cursors = state.get_cursors()
	-- local bufnr = vim.api.nvim_get_current_buf()

	-- Save undo state
	vim.cmd("undojoin")

	-- Execute command at each cursor
	for i, cursor in ipairs(cursors) do
		-- Move to cursor position
		vim.api.nvim_win_set_cursor(0, { cursor.row, cursor.col })

		-- Execute the command
		pcall(function()
			vim.cmd("normal! " .. command)
		end)

		-- Update cursor position after command
		local new_pos = vim.api.nvim_win_get_cursor(0)
		state.update_cursor(i, new_pos[1], new_pos[2])
	end

	-- Move to primary cursor
	local primary = state.get_primary_cursor()
	if primary then
		vim.api.nvim_win_set_cursor(0, { primary.row, primary.col })
	end

	render.update()
end

--- Enter insert mode at all cursors
---@param insert_type string|nil 'i' for insert (before cursor), 'a' for append (after cursor)
function M.enter_insert_mode(insert_type)
	insert_type = insert_type or "i"

	if not state.is_active() then
		return
	end

	state.set_mode("insert")
	insert_state.active = true
	insert_state.insert_type = insert_type

	-- Get primary cursor position
	local primary = state.get_primary_cursor()
	if not primary then
		return
	end

	insert_state.primary_cursor_row = primary.row
	insert_state.primary_cursor_col = primary.col

	-- Store current line content for diff detection
	local line = vim.api.nvim_buf_get_lines(0, primary.row - 1, primary.row, false)[1] or ""
	insert_state.last_line_content = line
	insert_state.last_line_number = primary.row

	-- For append mode, update all cursor positions to be at col+1 (after current char)
	-- This keeps secondary cursors in sync with where the primary cursor will be after startinsert!
	if insert_type == "a" then
		local cursors = state.get_cursors()
		for i, cursor in ipairs(cursors) do
			local line = vim.api.nvim_buf_get_lines(0, cursor.row - 1, cursor.row, false)[1] or ""
			local new_col = math.min(cursor.col + 1, #line)
			state.update_cursor(i, cursor.row, new_col)
		end
		-- Update primary cursor position tracking after adjustment
		insert_state.primary_cursor_col = math.min(primary.col + 1, #(vim.api.nvim_buf_get_lines(0, primary.row - 1, primary.row, false)[1] or ""))
	end

	-- Enter insert mode at primary cursor
	vim.api.nvim_win_set_cursor(0, { primary.row, primary.col })

	-- Use startinsert! for append mode (inserts after cursor position)
	if insert_type == "a" then
		vim.cmd("startinsert!")
	else
		vim.cmd("startinsert")
	end
end

--- Exit insert mode
function M.exit_insert_mode()
	if not insert_state.active then
		return
	end

	-- Reset insert state
	insert_state.active = false
	insert_state.insert_type = "i"
	insert_state.primary_cursor_row = nil
	insert_state.primary_cursor_col = nil
	insert_state.last_line_content = nil
	insert_state.last_line_number = nil

	state.set_mode("normal")

	-- Move to primary cursor
	local primary = state.get_primary_cursor()
	if primary then
		vim.api.nvim_win_set_cursor(0, { primary.row, primary.col })
	end

	render.update()
end

--- Handle visual mode selection
function M.handle_visual_mode()
	if not state.is_active() then
		return
	end

	-- Store visual selection for each cursor
	local cursors = state.get_cursors()

	for i, cursor in ipairs(cursors) do
		-- Move to cursor position
		vim.api.nvim_win_set_cursor(0, { cursor.row, cursor.col })

		-- Get visual selection
		local start_pos = vim.fn.getpos("'<")
		local end_pos = vim.fn.getpos("'>")

		cursor.visual_start = { row = start_pos[2], col = start_pos[3] - 1 }
		cursor.visual_end = { row = end_pos[2], col = end_pos[3] - 1 }
	end

	state.set_mode("visual")
end

--- Apply visual mode operation to all selections
---@param operation string Operation to perform ('d', 'c', 'y', etc.)
function M.apply_visual_operation(operation)
	if not state.is_active() or state.get_mode() ~= "visual" then
		return
	end

	local cursors = state.get_cursors()

	-- Sort in reverse order to avoid position shifting
	local sorted_cursors = vim.tbl_map(function(c)
		return c
	end, cursors)
	table.sort(sorted_cursors, function(a, b)
		if a.row == b.row then
			return a.col > b.col
		end
		return a.row > b.row
	end)

	for _, cursor in ipairs(sorted_cursors) do
		if cursor.visual_start and cursor.visual_end then
			-- Move to selection start
			vim.api.nvim_win_set_cursor(0, { cursor.visual_start.row, cursor.visual_start.col })

			-- Enter visual mode and select to end
			vim.cmd("normal! v")
			vim.api.nvim_win_set_cursor(0, { cursor.visual_end.row, cursor.visual_end.col })

			-- Apply operation
			vim.cmd("normal! " .. operation)

			-- Update cursor position
			local new_pos = vim.api.nvim_win_get_cursor(0)
			cursor.row = new_pos[1]
			cursor.col = new_pos[2]
		end
	end

	state.set_mode("normal")
	render.update()
end

--- Setup insert mode automation
function M.setup_insert_automation()
	local group = vim.api.nvim_create_augroup("MultilineaInsert", { clear = true })

	-- Track insert mode entry
	vim.api.nvim_create_autocmd("InsertEnter", {
		group = group,
		callback = function()
			if state.is_active() and not insert_state.active then
				insert_state.active = true

				-- Initialize tracking for replication
				local primary = state.get_primary_cursor()
				if primary then
					local line = vim.api.nvim_buf_get_lines(0, primary.row - 1, primary.row, false)[1] or ""
					insert_state.last_line_content = line
					insert_state.last_line_number = primary.row
					insert_state.primary_cursor_col = primary.col
				end
			end
		end,
	})

	-- Track insert mode exit
	vim.api.nvim_create_autocmd("InsertLeave", {
		group = group,
		callback = function()
			if state.is_active() and insert_state.active then
				M.exit_insert_mode()
			end
		end,
	})

	-- Handle text changes in insert mode
	vim.api.nvim_create_autocmd("TextChangedI", {
		group = group,
		callback = function()
			if not state.is_active() or not insert_state.active then
				return
			end

			M.replicate_insert_changes()
		end,
	})
end

--- Replicate insert mode changes to all cursors
function M.replicate_insert_changes()
	if not insert_state.active then
		return
	end

	local bufnr = vim.api.nvim_get_current_buf()
	local primary = state.get_primary_cursor()
	if not primary then
		return
	end

	-- Get current position and line
	local curr_pos = vim.api.nvim_win_get_cursor(0)
	local curr_row = curr_pos[1]
	local curr_col = curr_pos[2]

	-- Get current line content
	local curr_line = vim.api.nvim_buf_get_lines(bufnr, curr_row - 1, curr_row, false)[1] or ""

	-- Defensive: initialize tracking if somehow not set
	if not insert_state.last_line_number then
		insert_state.last_line_number = curr_row
		-- Set old content to current to avoid false detection on first event
		insert_state.last_line_content = curr_line
		insert_state.primary_cursor_col = curr_col
		-- Note: Don't return - let defensive initialization happen, then
		-- future events will work. This first event will see no change.
	end

	-- Check if we're still on the same line
	if curr_row ~= insert_state.last_line_number then
		-- Newline was inserted - handle separately
		M.handle_newline_insert()
		return
	end

	-- Calculate what changed
	local old_line = insert_state.last_line_content or ""
	local old_col = insert_state.primary_cursor_col

	-- Detect insertion or deletion
	local inserted_text = ""
	local deleted_count = 0

	if #curr_line > #old_line then
		-- Text was inserted
		-- curr_col is 0-indexed and points AFTER the inserted text
		local length_diff = #curr_line - #old_line
		local insert_end_pos = curr_col -- 0-indexed position after insertion
		local insert_start_pos = insert_end_pos - length_diff -- 0-indexed start

		-- Extract inserted text (convert to 1-indexed for string.sub)
		inserted_text = curr_line:sub(insert_start_pos + 1, insert_end_pos)
	elseif #curr_line < #old_line then
		-- Text was deleted (backspace)
		deleted_count = #old_line - #curr_line
	end

	-- Apply changes to all secondary cursors
	local cursors = state.get_cursors()

	-- Sort in reverse order to avoid position shifting
	local sorted_cursors = {}
	for i, cursor in ipairs(cursors) do
		if not cursor.is_primary then
			table.insert(sorted_cursors, { index = i, cursor = cursor })
		end
	end
	table.sort(sorted_cursors, function(a, b)
		if a.cursor.row == b.cursor.row then
			return a.cursor.col > b.cursor.col
		end
		return a.cursor.row > b.cursor.row
	end)

	-- Use undojoin to make this part of same undo operation
	pcall(vim.cmd, "undojoin")

	for _, item in ipairs(sorted_cursors) do
		local cursor = item.cursor
		local idx = item.index
		local row = cursor.row - 1 -- 0-indexed
		local col = cursor.col

		local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""

		if inserted_text ~= "" then
			-- For append mode, insert AFTER the cursor position
			local insert_col = col
			if insert_state.insert_type == "a" then
				insert_col = math.min(col + 1, #line)
			end

			-- Insert text at cursor position
			local new_line = line:sub(1, insert_col) .. inserted_text .. line:sub(insert_col + 1)
			vim.api.nvim_buf_set_lines(bufnr, row, row + 1, false, { new_line })

			-- Update cursor position
			state.update_cursor(idx, cursor.row, insert_col + #inserted_text)
		elseif deleted_count > 0 then
			-- For append mode, adjust deletion position
			local effective_col = col
			if insert_state.insert_type == "a" then
				effective_col = math.min(col + 1, #line)
			end

			-- Delete text before cursor position
			local delete_start = math.max(0, effective_col - deleted_count)
			local new_line = line:sub(1, delete_start) .. line:sub(effective_col + 1)
			vim.api.nvim_buf_set_lines(bufnr, row, row + 1, false, { new_line })

			-- Update cursor position
			state.update_cursor(idx, cursor.row, delete_start)
		end
	end

	-- Update primary cursor position in state
	state.update_cursor(state.state.primary_cursor_index, curr_row, curr_col)

	-- Update tracking
	insert_state.last_line_content = curr_line
	insert_state.primary_cursor_col = curr_col
	insert_state.last_line_number = curr_row -- CRITICAL: update row tracking

	-- Update render
	render.update()
end

--- Handle newline insertion in insert mode
function M.handle_newline_insert()
	-- Simplified: apply newline at all cursor positions
	local cursors = state.get_cursors()
	local bufnr = vim.api.nvim_get_current_buf()

	-- Sort in reverse
	local sorted_cursors = {}
	for i, cursor in ipairs(cursors) do
		if not cursor.is_primary then
			table.insert(sorted_cursors, { index = i, cursor = cursor })
		end
	end
	table.sort(sorted_cursors, function(a, b)
		if a.cursor.row == b.cursor.row then
			return a.cursor.col > b.cursor.col
		end
		return a.cursor.row > b.cursor.row
	end)

	pcall(vim.cmd, "undojoin")

	for _, item in ipairs(sorted_cursors) do
		local cursor = item.cursor
		local idx = item.index

		-- Insert newline at cursor position
		local row = cursor.row - 1
		local col = cursor.col
		local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""

		local before = line:sub(1, col)
		local after = line:sub(col + 1)

		vim.api.nvim_buf_set_lines(bufnr, row, row + 1, false, { before, after })

		-- Update cursor to next line
		state.update_cursor(idx, cursor.row + 1, 0)
	end

	-- Update tracking for new line
	local curr_pos = vim.api.nvim_win_get_cursor(0)
	local curr_row = curr_pos[1]
	local curr_line = vim.api.nvim_buf_get_lines(bufnr, curr_row - 1, curr_row, false)[1] or ""

	insert_state.last_line_number = curr_row
	insert_state.last_line_content = curr_line
	insert_state.primary_cursor_col = curr_pos[2]

	render.update()
end

-- Handle move operation at all cursors
-- @param motion string Motion to move (e.g., 'w', '$', '0', 'l', 'h')
function M.move_at_cursors(motion)
	M.handle_normal_mode(motion)
end

--- Handle delete operation at all cursors
---@param motion string Motion to delete (e.g., 'w', '$', 'iw')
function M.delete_at_cursors(motion)
	M.handle_normal_mode("d" .. motion)
end

--- Handle change operation at all cursors
---@param motion string Motion to change
---@deprecated This function is not used by keymaps. Keymaps use delete + explicit insert mode instead.
--- Change commands (c*) automatically enter insert mode which conflicts with multi-cursor tracking.
--- For proper multi-cursor change operations, use: operations.apply_to_all('d' .. motion) + M.enter_insert_mode('i')
function M.change_at_cursors(motion)
	-- Note: This uses the old approach which has insert mode conflicts
	-- Kept for backwards compatibility but not recommended
	M.handle_normal_mode("c" .. motion)
	-- Automatically enter insert mode after change
	if state.is_active() then
		M.enter_insert_mode()
	end
end

--- Handle yank operation at all cursors
---@param motion string Motion to yank
function M.yank_at_cursors(motion)
	M.handle_normal_mode("y" .. motion)
end

--- Paste at all cursor positions
---@param register string|nil Register to paste from
function M.paste_at_cursors(register)
	register = register or '"'
	local content = vim.fn.getreg(register)

	if not content or content == "" then
		return
	end

	local cursors = state.get_cursors()

	-- Sort in reverse to avoid position shifting
	local sorted_cursors = vim.tbl_map(function(c)
		return c
	end, cursors)
	table.sort(sorted_cursors, function(a, b)
		if a.row == b.row then
			return a.col > b.col
		end
		return a.row > b.row
	end)

	for _, cursor in ipairs(sorted_cursors) do
		vim.api.nvim_win_set_cursor(0, { cursor.row, cursor.col })
		vim.cmd('normal! "' .. register .. "p")

		-- Update cursor position
		local new_pos = vim.api.nvim_win_get_cursor(0)
		cursor.row = new_pos[1]
		cursor.col = new_pos[2]
	end

	render.update()
end

--- Initialize mode handlers
function M.setup()
	M.setup_insert_automation()
end

return M
