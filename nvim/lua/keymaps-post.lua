---------------------------------------------------------------------------------
--- Lazy
---------------------------------------------------------------------------------
vim.keymap.set('n', '<leader>l', vim.cmd.Lazy, { desc = 'Lazy' })

---------------------------------------------------------------------------------
--- Harpoon
---------------------------------------------------------------------------------
local mark = require('harpoon.mark')
local ui = require('harpoon.ui')
vim.keymap.set('n', '<leader>a', mark.add_file, { desc = 'Harpoon add file' })
vim.keymap.set('n', '<C-e>', ui.toggle_quick_menu,
  { desc = 'Harpoon toggle quick menu' })

---------------------------------------------------------------------------------
-- Telescope
---------------------------------------------------------------------------------
local tele = require('telescope.builtin')

vim.keymap.set('n', '<leader>fb', tele.buffers, { desc = 'Telescope buffers' })
vim.keymap.set('n', '<leader>ff', tele.find_files,
  { desc = 'Telescope find files' })
vim.keymap.set('n', '<leader>en',
  function()
    tele.find_files{
      cwd = vim.fn.stdpath('config')
    }
  end,
  { desc = 'Telescope find files (path config)' }
)
vim.keymap.set('n', '<leader>fr', tele.oldfiles,
  { desc = 'Telescope old files'})
vim.keymap.set('n', '<leader>fs', tele.live_grep,
  { desc = 'Telescope live grep'})
vim.keymap.set('n', '<leader>fc', tele.grep_string,
  { desc = 'Telescope grep string'})
vim.keymap.set('n', '<leader>vh', tele.help_tags,
  { desc = 'Telescope help tags'})
