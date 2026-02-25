---------------------------------------------------------------------------
--- Set leaders
---------------------------------------------------------------------------
vim.g.mapleader = ' '
vim.g.maplocalleader = ','

vim.keymap.set('n', '<leader>kk', ':qa<CR>',
  { desc = 'Quit all' })

vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move window (left)' })
vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move window (right)' })
vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move window (up)' })
vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move window (down)' })

---------------------------------------------------------------------------------
-- Basic Operations
---------------------------------------------------------------------------------
vim.keymap.set('n', '<leader>h', function() vim.cmd('noh') end)

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
vim.keymap.set('n', '<leader>no', ':Neorg<CR>',
  { desc = 'Neorg'})
vim.keymap.set('n', '<leader>ni', ':Neorg index<CR>',
  { desc = 'Neorg index'})
vim.keymap.set('n', '<leader>nr', ':Neorg return<CR>',
  { desc = 'Neorg return'})
vim.keymap.set('n', '<leader>nw', ':Neorg workspace',
  { desc = 'Neorg workspace'})
vim.keymap.set('n', '<localleader>nc', ':Neorg toggle-concealer<CR>',
  { desc = 'Neorg toggle concealer'})

---------------------------------------------------------------------------------
--- Markview toggle
---------------------------------------------------------------------------------
vim.keymap.set('n', '<leader>mv', ':Markview toggle<CR>',
  { desc = 'Markview toggle'})

---------------------------------------------------------------------------------
--- Code Companion
---------------------------------------------------------------------------------
vim.keymap.set('n', '<leader>ch', ':CodeCompanionChat<CR>',
  { desc = 'Code Companion Chat'})
vim.keymap.set('n', '<leader>ca', ':CodeCompanionActions<CR>',
  { desc = 'Code Companion Actions'})

---------------------------------------------------------------------------------
--- Claude Code
---------------------------------------------------------------------------------
vim.keymap.set('n', '<leader>cc', '<cmd>ClaudeCode<CR>',
  { desc = 'Toggle Claude Code' })
