require 'options'

vim.opt.shell = 'bash'
vim.opt.foldlevelstart = 99
vim.opt.concealcursor = 'nc'

require 'keymaps'
require 'packages'
require 'autocmds'
require 'health'
require 'filetypes'
require 'local_plugins.mng_colorschemes'
require 'local_plugins.mng_workspace'
