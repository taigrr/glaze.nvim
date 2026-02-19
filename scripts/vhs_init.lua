-- Minimal init.lua for VHS recordings
-- Loads only glaze.nvim with no colorscheme or other plugins
-- Usage: nvim --clean -u /path/to/vhs_init.lua --cmd "set rtp+=/path/to/glaze.nvim"

-- Basic settings for clean recording
vim.o.number = true
vim.o.relativenumber = false
vim.o.signcolumn = "yes"
vim.o.termguicolors = true
vim.o.showmode = false
vim.o.ruler = false
vim.o.laststatus = 2
vim.o.cmdheight = 1
vim.o.updatetime = 100
vim.o.timeoutlen = 300
vim.o.swapfile = false
vim.o.backup = false
vim.o.writebackup = false
vim.o.autoread = true

-- Disable intro message and other noise
vim.opt.shortmess:append("I")
vim.opt.shortmess:append("c")

-- Simple statusline
vim.o.statusline = " %f %m%=%l:%c "

-- Set leader key
vim.g.mapleader = " "

-- Source the plugin file (--clean doesn't auto-load plugin/ dir)
vim.cmd("runtime! plugin/glaze.lua")

-- Load glaze with some demo binaries pre-registered
local glaze = require("glaze")
glaze.setup({
  auto_install = { enabled = false },
  auto_check = { enabled = false },
})

-- Register some binaries for the demo
glaze.register("freeze", "github.com/charmbracelet/freeze")
glaze.register("glow", "github.com/charmbracelet/glow")
glaze.register("gum", "github.com/charmbracelet/gum")
glaze.register("mods", "github.com/charmbracelet/mods")
glaze.register("vhs", "github.com/charmbracelet/vhs")
