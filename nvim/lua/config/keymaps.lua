---------------------------------------------------------------------------------
-- Basic Operations
---------------------------------------------------------------------------------
vim.keymap.set('n', '<leader>dl', vim.cmd.Ex)
vim.keymap.set('n', '<leader>h', function() vim.cmd('noh') end)

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
