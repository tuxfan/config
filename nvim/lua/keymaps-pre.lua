---------------------------------------------------------------------------
--- Set leaders
---------------------------------------------------------------------------
vim.g.mapleader = ' '
vim.g.maplocalleader = ','

---------------------------------------------------------------------------
--- Oil
---------------------------------------------------------------------------------
vim.keymap.set('n', '<leader>o', vim.cmd.Oil, { desc = 'Oil' })

---------------------------------------------------------------------------
--- Nvim-Tree
---------------------------------------------------------------------------------
vim.keymap.set('n', '<leader>ee', '<cmd>NvimTreeToggle<CR>',
  { desc = 'Toggle file explorer' })
vim.keymap.set('n', '<leader>dl', '<cmd>NvimTreeFindFileToggle<CR>',
  { desc = 'Toggle file explorer on current file' })
vim.keymap.set('n', '<leader>er', '<cmd>NvimTreeRefresh<CR>',
  { desc = 'Refresh file explorer' })

---------------------------------------------------------------------------------
--- Neorg
---------------------------------------------------------------------------------
vim.keymap.set('n', '<leader>no', ':Neorg<CR>')
vim.keymap.set('n', '<leader>ni', ':Neorg index<CR>')
vim.keymap.set('n', '<leader>nr', ':Neorg return<CR>')
vim.keymap.set('n', '<leader>nw', ':Neorg workspace')
vim.keymap.set('n', '<localleader>nw', ':Neorg workspace')
vim.keymap.set('n', '<localleader>nc', ':Neorg toggle-concealer<CR>')

---------------------------------------------------------------------------------
--- Markview
---------------------------------------------------------------------------------
vim.keymap.set('n', '<leader>mv', ':Markview toggle<CR>')
