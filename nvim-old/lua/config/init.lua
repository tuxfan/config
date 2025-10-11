--------------------------------------------------------------------------------
-- Lazy plugin manager inintialization
---------------------------------------------------------------------------------
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    'git',
    'clone',
    '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git',
    '--branch=stable', -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

---------------------------------------------------------------------------------
-- Set mapleader before lazy setup.
---------------------------------------------------------------------------------
vim.g.mapleader = ' '
vim.g.maplocalleader = ','

---------------------------------------------------------------------------------
-- lazy.nvim configuration
---------------------------------------------------------------------------------
require('lazy').setup({
  {import = 'plugins'},
  {import = 'plugins.lsp'},
  checker = {
    enabled = true,
    notify = false
  },
  change_detection = {
    nofify = false
  }
})

---------------------------------------------------------------------------------
-- Clangd
---------------------------------------------------------------------------------
require'lspconfig'.clangd.setup{}

---------------------------------------------------------------------------------
-- Vim
---------------------------------------------------------------------------------
require('config.vim')

---------------------------------------------------------------------------------
-- Keymaps
---------------------------------------------------------------------------------
require('config.keymaps')
