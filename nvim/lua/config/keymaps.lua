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
-- Telekasten
---------------------------------------------------------------------------------
vim.keymap.set('n', '<leader>z', '<cmd>Telekasten panel<CR>')
vim.keymap.set('n', '<leader>c', '<cmd>Calendar<CR>')

-- Most used functions
vim.keymap.set("n", "<leader>zf", "<cmd>Telekasten find_notes<CR>")
vim.keymap.set("n", "<leader>zg", "<cmd>Telekasten search_notes<CR>")
vim.keymap.set("n", "<leader>zd", "<cmd>Telekasten goto_today<CR>")
vim.keymap.set("n", "<leader>zz", "<cmd>Telekasten follow_link<CR>")
vim.keymap.set("n", "<leader>zn", "<cmd>Telekasten new_note<CR>")
vim.keymap.set("n", "<leader>zc", "<cmd>Telekasten show_calendar<CR>")
vim.keymap.set("n", "<leader>zb", "<cmd>Telekasten show_backlinks<CR>")
vim.keymap.set("n", "<leader>zI", "<cmd>Telekasten insert_img_link<CR>")

-- Call insert link automatically when we start typing a link
vim.keymap.set("i", "[[", "<cmd>Telekasten insert_link<CR>")

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
