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
	if cwd ~= M.config.base_dir then
		local current_list = harpoon:list()

		if current_list then
			local current_key = harpoon.config.settings.key()
			harpoon.data:sync(current_key, current_list.name, current_list)
		end

		local base_dir = cwd
		vim.cmd[M.config.cd_command](M.config.base_dir)
		local base_key = harpoon.config.settings.key()
		local base_list = harpoon:list(base_key)

		if base_list then
			harpoon.data:sync(base_key, base_list.name, base_list)
		end
		vim.cmd[M.config.cd_command](base_dir)
		harpoon:list(current_key)
	else
		local list = harpoon:list()
		if list then
			local key = harpoon.config.settings.key()
			harpoon.data:sync(key, list.name, list)
		end
	end
end

local function hop_to_dir(target_dir)
	local harpoon = require("harpoon")
	sync_to_base()
	vim.cmd[M.config.cd_command](target_dir)
	local new_key = harpoon.config.settings.key()
	harpoon.lists[new_key] = nil

	local ok, new_list = pcall(function()
		return harpoon:list(new_key)
	end)

	if not ok or not new_list or not new_list.items then
		local harpoon_file, file_data = find_harpoon_file_for_dir(target_dir)
		if harpoon_file and file_data and file_data[target_dir] then
			harpoon.data._data[new_key] = file_data[target_dir]
		else
			harpoon.data._data[new_key] = { __harpoon_files = {} }
		end
		harpoon.lists[new_key] = nil
		harpoon:list(new_key)
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
		local root =
			vim.fn.systemlist("git -C " .. vim.fn.shellescape(dir) .. " rev-parse --show-toplevel 2>/dev/null")[1]

		if vim.v.shell_error == 0 and root and root ~= "" then
			root = vim.loop.fs_realpath(root)
			if root ~= cwd then
				hop_to_dir(root)
				vim.cmd.edit(file)
				return
			end
		end

		vim.cmd.edit(file)
	end

	vim.api.nvim_create_autocmd("VimLeavePre", {
		callback = function()
			sync_to_base()
			local ok, _ = pcall(function()
				harpoon.data:write_all()
			end)

			if not ok then
				local list = harpoon:list()
				if list then
					local key = harpoon.config.settings.key()
					pcall(function()
						harpoon.data:sync(key, list.name, list)
					end)
				end
			end
		end,
	})

	vim.api.nvim_create_autocmd("BufWritePost", {
		callback = function()
			local list = harpoon:list()

			if list then
				local key = harpoon.config.settings.key()
				pcall(function()
					harpoon.data:sync(key, list.name, list)
				end)
			end
		end,
	})
end

return M
