---------------------------------------------------------------------------------
-- Basic Operations
---------------------------------------------------------------------------------
--vim.keymap.set('n', '<leader>dl', vim.cmd.Ex)
vim.keymap.set('n', '<leader>h', function() vim.cmd('noh') end)

---------------------------------------------------------------------------------
-- Window Management
---------------------------------------------------------------------------------
vim.keymap.set("n", "<leader>sv", "<C-w>v", { desc = "Split window vertically" })
vim.keymap.set("n", "<leader>sh", "<C-w>s", { desc = "Split window horizontally" })
vim.keymap.set("n", "<leader>se", "<C-w>=", { desc = "Make splits equal size" })
vim.keymap.set("n", "<leader>sx", "<cmd>close<CR>", { desc = "Close current split" })

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
-- CodeCompanion
---------------------------------------------------------------------------------
vim.keymap.set('n', '<leader>ch', ':CodeCompanionChat<CR>')
vim.keymap.set('n', '<leader>ca', ':CodeCompanionActions<CR>')

---------------------------------------------------------------------------------
-- Markview
---------------------------------------------------------------------------------
vim.keymap.set('n', '<leader>mv', ':Markview toggle<CR>')

---------------------------------------------------------------------------------
-- Markview
---------------------------------------------------------------------------------
vim.keymap.set('n', '[u', function()
  require('treesitter-context').go_to_context(vim.v.count1)
end, { silent = true, desc = 'Jump to top of context' })
vim.keymap.set('n', '<leader>ct', ':TSContext toggle<CR>')

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
local tele = require('telescope.builtin')

vim.keymap.set('n', '<leader>fb', tele.buffers, {})
vim.keymap.set('n', '<leader>ff', tele.find_files, {})
vim.keymap.set('n', '<leader>en',
  function()
    tele.find_files{
      cwd = vim.fn.stdpath('config')
    }
  end
)
vim.keymap.set('n', '<leader>fr', tele.oldfiles, {})
vim.keymap.set('n', '<leader>fs', tele.live_grep, {})
vim.keymap.set('n', '<leader>fc', tele.grep_string, {})
vim.keymap.set('n', '<leader>vh', tele.help_tags, {})

---------------------------------------------------------------------------------
-- Fugitive
---------------------------------------------------------------------------------
vim.keymap.set('n', '<leader>gs', vim.cmd.Git)

---------------------------------------------------------------------------------
-- Undo
---------------------------------------------------------------------------------
--vim.keymap.set('n', '<leader>u', vim.cmd.UndotreeToggle)

---------------------------------------------------------------------------------
-- Toggle Diagnostics
---------------------------------------------------------------------------------

vim.api.nvim_create_user_command('DiagnosticToggle', function()
	local config = vim.diagnostic.config
	local vt = config().virtual_text
	config {
		virtual_text = not vt,
		underline = not vt,
		signs = not vt,
	}
end, { desc = 'toggle diagnostic' })
vim.keymap.set('n', '<leader>te', vim.cmd.DiagnosticToggle)

---------------------------------------------------------------------------------
-- Toggle Diagnostics
---------------------------------------------------------------------------------

vim.keymap.set("n", "<leader>wr", "<cmd>SessionRestore<CR>",
  { desc = "Restore session for cwd" })
vim.keymap.set("n", "<leader>ws", "<cmd>SessionSave<CR>",
  { desc = "Save session for auto session root dir" })

---------------------------------------------------------------------------------
-- Nvim-Tree
---------------------------------------------------------------------------------

vim.keymap.set('n', '<leader>ee', '<cmd>NvimTreeToggle<CR>',
  { desc = 'Toggle file explorer' })
vim.keymap.set('n', '<leader>dl', '<cmd>NvimTreeFindFileToggle<CR>',
  { desc = 'Toggle file explorer on current file' })
vim.keymap.set('n', '<leader>ec', '<cmd>NvimTreeCollapse<CR>',
  { desc = 'Collapse file explorer' })
vim.keymap.set('n', '<leader>er', '<cmd>NvimTreeRefresh<CR>',
  { desc = 'Refresh file explorer' })

---------------------------------------------------------------------------------
-- Trouble keymaps are in plugin.
---------------------------------------------------------------------------------
