---------------------------------------------------------------------------------
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
vim.g.maplocalleader = '\\'

---------------------------------------------------------------------------------
-- lazy.nvim configuration
---------------------------------------------------------------------------------
require('lazy').setup('config.lazy', opts)

---------------------------------------------------------------------------------
-- Keymaps
---------------------------------------------------------------------------------
require('config.keymaps')

---------------------------------------------------------------------------------
-- Color schemes
---------------------------------------------------------------------------------
require('config.colorscheme')
