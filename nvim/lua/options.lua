-- These need to be set before plugins are loaded
vim.g.mapleader = ' '
vim.g.maplocalleader = ','

-- Colors
vim.o.termguicolors = true

-- Setting for Nerd Fonts
vim.g.have_nerd_font = true

-- Turn off line numbering by default
vim.o.number = false
vim.o.relativenumber = false

-- Enable mouse mode
vim.o.mouse = 'a'

-- The mode is already shown by lualine
vim.o.showmode = false

-- Sync clipboard between OS and Neovim.
--  Schedule the setting after `UiEnter` because it can increase startup-time.
--  Remove this option if you want your OS clipboard to remain independent.
vim.schedule(function()
  vim.o.clipboard = 'unnamedplus'
end)

-- Enable break indent
vim.o.breakindent = true

-- Save undo history
vim.o.undofile = true

-- Keep signcolumn on by default
vim.o.signcolumn = 'yes'

-- Decrease update time
vim.o.updatetime = 250

-- Decrease mapped sequence wait time
vim.o.timeoutlen = 300

-- Configure how new splits should be opened
vim.o.splitright = true
vim.o.splitbelow = true

-- Configure how whitespace is shown
vim.o.list = true
vim.opt.listchars = { tab = '» ', trail = '·', extends = '>', nbsp = '␣' }

-- Set up tabs and column preview
vim.o.colorcolumn = '81'
vim.o.tabstop = 2
vim.o.softtabstop = 2
vim.o.shiftwidth = 2
vim.o.expandtab = true

-- Spelling
vim.o.spelllang    = 'en_us'
vim.o.spell        = true

-- Preview substitutions live, as you type!
vim.o.inccommand = 'split'

-- Show current line and column
vim.o.cursorline = true
vim.o.cursorcolumn = false
vim.o.scrolloff = 10

-- Unsaved changes prompt
vim.o.confirm = true

-- Set conceallevel
vim.o.conceallevel = 2
