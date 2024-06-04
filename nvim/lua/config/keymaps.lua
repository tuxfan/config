---------------------------------------------------------------------------------
-- Basic Operations
---------------------------------------------------------------------------------
vim.keymap.set('n', '<leader>dl', vim.cmd.Ex)
vim.keymap.set('n', '<leader>h', function() vim.cmd('noh') end)

---------------------------------------------------------------------------------
-- Neorg
---------------------------------------------------------------------------------
vim.keymap.set('n', '<leader>no', ':Neorg<CR>')
vim.keymap.set('n', '<leader>ni', ':Neorg index<CR>')
vim.keymap.set('n', '<leader>nr', ':Neorg return<CR>')
vim.keymap.set('n', '<leader>nw', ':Neorg workspace')
vim.keymap.set('n', '<localleader>nc', ':Neorg toggle-concealer<CR>')

---------------------------------------------------------------------------------
-- Harpoon
---------------------------------------------------------------------------------
local mark = require('harpoon.mark')
local ui = require('harpoon.ui')

vim.keymap.set('n', '<leader>a', mark.add_file)
vim.keymap.set('n', '<C-e>', ui.toggle_quick_menu)

---------------------------------------------------------------------------------
-- Telescope
---------------------------------------------------------------------------------
local builtin = require('telescope.builtin')

vim.keymap.set('n', '<leader>fb', builtin.buffers, {})
vim.keymap.set('n', '<leader>ff', builtin.find_files, {})
vim.keymap.set('n', '<leader>fg', builtin.live_grep, {})
vim.keymap.set('n', '<leader>gf', builtin.git_files, {})
vim.keymap.set('n', '<leader>vh', builtin.help_tags, {})

---------------------------------------------------------------------------------
-- NVim Tree
---------------------------------------------------------------------------------
vim.keymap.set('n', '<c-n>', ':NvimTreeFindFileToggle<CR>')

---------------------------------------------------------------------------------
-- Fugitive
---------------------------------------------------------------------------------
vim.keymap.set('n', '<leader>gs', vim.cmd.Git)

---------------------------------------------------------------------------------
-- Undo
---------------------------------------------------------------------------------
vim.keymap.set('n', '<leader>u', vim.cmd.UndotreeToggle)

---------------------------------------------------------------------------------
-- Leap
---------------------------------------------------------------------------------
--vim.keymap.set({'n', 'x', 'o'}, 's',  '<Plug>(leap-forward)')
--vim.keymap.set({'n', 'x', 'o'}, 'S',  '<Plug>(leap-backward)')
--vim.keymap.set({'n', 'x', 'o'}, 'gs', '<Plug>(leap-from-window)')

---------------------------------------------------------------------------------
-- Trouble
---------------------------------------------------------------------------------
vim.keymap.set('n', '<leader>xx',
  function() require('trouble').toggle() end)
vim.keymap.set('n', '<leader>xw',
  function() require('trouble').toggle('workspace_diagnostics') end)
vim.keymap.set('n', '<leader>xd',
  function() require('trouble').toggle('document_diagnostics') end)
vim.keymap.set('n', '<leader>xq',
  function() require('trouble').toggle('quickfix') end)
vim.keymap.set('n', '<leader>xl',
  function() require('trouble').toggle('loclist') end)
vim.keymap.set('n', 'gR',
  function() require('trouble').toggle('lsp_references') end)
