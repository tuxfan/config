---------------------------------------------------------------------------------
--- Lazy
---------------------------------------------------------------------------------
vim.keymap.set('n', '<leader>l', vim.cmd.Lazy, { desc = 'Lazy' })

---------------------------------------------------------------------------------
--- Harpoon
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
