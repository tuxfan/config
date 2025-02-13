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
vim.keymap.set('n', '<localleader>nw', ':Neorg workspace')
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
-- Fugitive
---------------------------------------------------------------------------------
vim.keymap.set('n', '<leader>gs', vim.cmd.Git)

---------------------------------------------------------------------------------
-- Undo
---------------------------------------------------------------------------------
vim.keymap.set('n', '<leader>u', vim.cmd.UndotreeToggle)

vim.api.nvim_create_user_command("DiagnosticToggle", function()
	local config = vim.diagnostic.config
	local vt = config().virtual_text
	config {
		virtual_text = not vt,
		underline = not vt,
		signs = not vt,
	}
end, { desc = "toggle diagnostic" })
vim.keymap.set('n', '<leader>te', vim.cmd.DiagnosticToggle)

---------------------------------------------------------------------------------
-- Trouble keymaps are in plugin.
---------------------------------------------------------------------------------
