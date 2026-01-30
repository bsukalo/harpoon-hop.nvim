# harpoon-hop.nvim
Harpoon-hop extends [Harpoon](https://github.com/ThePrimeagen/harpoon/tree/harpoon2) with project-aware navigation. Pin your projects in a base directory, then navigate between them while maintaining separate harpoon lists for each project.

## The Problem
You have multiple projects. Each project has files you frequently jump between. You want to:
- Quickly switch between projects
- Keep separate harpoon lists per project
- Not lose your pinned files when changing directories

Harpoon-hop solves this by having a "base" directory (e.g., `~/projects`) as a meta-harpoon list where each entry is a project, and each project maintains its own harpoon list of files. It automatically detects git repositories and keeps separate lists per repo.

## Installation
### lazy.nvim
```lua
{
    "bnjjo/harpoon-hop.nvim",
    dependencies = {
      "ThePrimeagen/harpoon"
    },
    config = function()
        require("harpoon-hop").setup({
            -- your config goes here
        })
    end
}
```

## Basic Usage
### The Two-Level System
1. **Base directory level**: Your `base_dir` (default: `~`) contains pinned projects
2. **Project level**: Each project has its own harpoon list of files

### Workflow Example

In your base directory (e.g., `~/projects`):
- Add projects to harpoon like normal using your configured keybinds
- Use `<leader>1-9` to quick-switch to any pinned project
  - Automatically changes to that project's directory
  - Loads that project's harpoon list
  - Opens the file at that index

Within a project:
- Use harpoon normally to pin and navigate between files
- Use `<leader>1-9` again to quick-switch to a different project
- Or use `<C-b>` to hop back to your base directory

## Configuration
### Default Config
```lua
require("harpoon-hop").setup({
    cd_command = "tcd",           -- command to change directory (tcd, cd, lcd)
    base_dir = vim.fn.expand("~"), -- your projects directory
    back_keymap = "<C-b>",        -- keymap to hop back to base_dir
    quick_switch_keymaps = {      -- keymaps for quick project switching
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
})
```

### Options
#### `cd_command`
Command used to change directories. Options:
- `"tcd"` (default) - tab-local directory
- `"cd"` - global directory  
- `"lcd"` - window-local directory

#### `base_dir`
The directory containing your projects. All projects pinned in harpoon at this level will be available for quick switching.

#### `back_keymap`
Keymap to return to `base_dir` from any project.

#### `quick_switch_keymaps`
Table of keymaps that switch to `base_dir` and immediately select the project at that index. Customize the keymaps or add/remove entries as needed.

## License
MIT
