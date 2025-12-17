local M = {}

M.config = {
	cd_command = "tcd",
	base_dir = vim.fn.expand("~"),
	back_keymap = "<C-b>",
	quick_switch_keymaps = {
		["<leader>1"] = 1,
		["<leader>2"] = 2,
		["<leader>3"] = 3,
		["<leader>4"] = 4,
		["<leader>5"] = 5,
		["<leader>6"] = 6,
		["<leader>7"] = 7,
		["<leader>8"] = 8,
		["<leader>9"] = 9,
	},
}

-- returns git root for a directory, nil if not in a git repo
local function get_git_root(dir)
	local result =
		vim.fn.systemlist("git -C " .. vim.fn.shellescape(dir) .. " rev-parse --show-toplevel 2>/dev/null")[1]
	if vim.v.shell_error == 0 and result and result ~= "" then
		return vim.loop.fs_realpath(result)
	end
	return nil
end

-- determines the "canonical" key for a directory
-- returns git root if in a repo, base_dir if not
local function get_canonical_key(dir)
	dir = vim.loop.fs_realpath(dir) or dir
	local base = vim.loop.fs_realpath(M.config.base_dir) or M.config.base_dir

	if dir == base then
		return base
	end

	local git_root = get_git_root(dir)
	if git_root then
		return git_root
	end

	-- fall back to base_dir
	return base
end

local function find_harpoon_file_for_dir(target_dir)
	local data_path = vim.fn.stdpath("data") .. "/harpoon"
	local files = vim.fn.glob(data_path .. "/*.json", false, true)
	for _, file in ipairs(files) do
		local ok, data = pcall(vim.fn.json_decode, table.concat(vim.fn.readfile(file), "\n"))
		if ok and data then
			if data[target_dir] then
				return file, data
			end
		end
	end
	return nil, nil
end

local function sync_to_base()
	local harpoon = require("harpoon")
	local cwd = vim.loop.cwd()
	local base = vim.loop.fs_realpath(M.config.base_dir) or M.config.base_dir

	if cwd ~= base then
		local current_list = harpoon:list()
		if current_list then
			local current_key = get_canonical_key(cwd)
			harpoon.data:sync(current_key, current_list.name, current_list)
		end

		local original_dir = cwd
		vim.cmd[M.config.cd_command](M.config.base_dir)
		local base_list = harpoon:list()
		if base_list then
			harpoon.data:sync(base, base_list.name, base_list)
		end

		vim.cmd[M.config.cd_command](original_dir)
	else
		local list = harpoon:list()
		if list then
			harpoon.data:sync(base, list.name, list)
		end
	end
end

local function hop_to_dir(target_dir)
	local harpoon = require("harpoon")
	sync_to_base()
	vim.cmd[M.config.cd_command](target_dir)

	local new_key = get_canonical_key(target_dir)

	-- clear cached list to force reload
	harpoon.lists[new_key] = nil

	local ok, new_list = pcall(function()
		return harpoon:list()
	end)

	if not ok or not new_list or not new_list.items then
		local harpoon_file, file_data = find_harpoon_file_for_dir(target_dir)
		if harpoon_file and file_data and file_data[target_dir] then
			harpoon.data._data[new_key] = file_data[target_dir]
		else
			harpoon.data._data[new_key] = { __harpoon_files = {} }
		end
		harpoon.lists[new_key] = nil
		harpoon:list()
	end

	print("hop → " .. vim.fn.fnamemodify(target_dir, ":t"))
end

function M._internal_hop(target_dir)
	hop_to_dir(target_dir)
end

function M.setup(user_config)
	M.config = vim.tbl_deep_extend("force", M.config, user_config or {})
	local harpoon = require("harpoon")
	local List = require("harpoon.list")

	-- override harpoon's key function
	harpoon:setup({
		settings = {
			key = function()
				return get_canonical_key(vim.loop.cwd())
			end,
			save_on_toggle = true,
			sync_on_ui_close = true,
		},
	})

	-- on startup, if in a non-canonical directory, redirect to base
	vim.schedule(function()
		local cwd = vim.loop.cwd()
		local canonical = get_canonical_key(cwd)
		local real_cwd = vim.loop.fs_realpath(cwd) or cwd

		-- if canonical key differs from actual cwd and not in a git repo,
		-- preload base_dir data to prevent corruption
		if canonical ~= real_cwd then
			local base_data = harpoon.data._data[canonical]
			if not base_data then
				local harpoon_file, file_data = find_harpoon_file_for_dir(canonical)
				if harpoon_file and file_data and file_data[canonical] then
					harpoon.data._data[canonical] = file_data[canonical]
				end
			end
		end
	end)

	vim.keymap.set("n", M.config.back_keymap, function()
		hop_to_dir(M.config.base_dir)
	end, { desc = "Hop back to base directory" })

	for keymap, idx in pairs(M.config.quick_switch_keymaps) do
		vim.keymap.set("n", keymap, function()
			hop_to_dir(M.config.base_dir)
			harpoon:list():select(idx)
		end, { desc = "Quick switch to project " .. idx })
	end

	local original_select = List.select
	List.select = function(self, idx, ...)
		local item = self.items[idx]

		if not item or not item.value then
			return original_select(self, idx, ...)
		end

		local file = item.value
		local cwd = vim.loop.cwd()

		if not vim.startswith(file, "/") then
			file = vim.fn.fnamemodify(cwd .. "/" .. file, ":p")
		end

		local dir = vim.fn.fnamemodify(file, ":h")
		local root = get_git_root(dir)

		if root and root ~= cwd then
			hop_to_dir(root)
			vim.cmd.edit(file)
			return
		end

		vim.cmd.edit(file)
	end

	vim.api.nvim_create_autocmd("VimLeavePre", {
		callback = function()
			sync_to_base()
			pcall(function()
				harpoon.data:write_all()
			end)
		end,
	})

	vim.api.nvim_create_autocmd("BufWritePost", {
		callback = function()
			local list = harpoon:list()
			if list then
				local key = get_canonical_key(vim.loop.cwd())
				pcall(function()
					harpoon.data:sync(key, list.name, list)
				end)
			end
		end,
	})
end

return M
