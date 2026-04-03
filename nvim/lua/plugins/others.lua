require('persistence').setup {
  event = 'BufReadPre', -- this will only start session saving when an actual file was opened
}
require('move-enclosing').setup {}
require('print-debug').setup {}
require('fish-files').setup()

require('colorizer').setup({ '*' }, {
  RRGGBBAA = true, -- #RRGGBBAA hex codes
  css = true,      -- Enable all CSS features: rgb_fn, hsl_fn, names, RGB, RRGGBB
  mode = 'background',
})

-- Persistence keymaps
-- Close current session
vim.keymap.set('n', '<leader>qq', vim.cmd.qa, { desc = 'Quit current session' })
-- load the session for the current directory
vim.keymap.set('n', '<leader>qs', function()
  require('persistence').load()
end, { desc = 'Load session in the current directory' })
-- select a session to load
vim.keymap.set('n', '<leader>qS', function()
  require('persistence').select()
end, { desc = 'Select session to load' })
-- load the last session
vim.keymap.set('n', '<leader>ql', function()
  require('persistence').load { last = true }
end, { desc = 'Load last session' })
-- stop Persistence => session won't be saved on exit
vim.keymap.set('n', '<leader>qd', function()
  require('persistence').stop()
end, { desc = 'Do not save session' })
-- Restart keymap (NOTE: Uses persistence)
vim.keymap.set('n', '<leader>qr', function()
  vim.cmd.restart 'lua require("persistence").load()'
end, { desc = 'Restart session' })

-- Flash keymaps
vim.keymap.set({ 'n', 'x', 'o' }, '<leader>w', function()
  require('flash').jump()
end, { desc = 'Flash' })
vim.keymap.set({ 'n', 'x', 'o' }, '<leader>W', function()
  require('flash').treesitter()
end, { desc = 'Flash Treesitter' })
vim.keymap.set('o', 'r', function()
  require('flash').remote()
end, { desc = 'Remote Flash' })
vim.keymap.set({ 'o', 'x' }, 'R', function()
  require('flash').treesitter_search()
end, { desc = 'Treesitter Search' })
vim.keymap.set({ 'c' }, '<c-s>', function()
  require('flash').toggle()
end, { desc = 'Toggle Flash Search' })

-- Fish-files keymaps
vim.keymap.set(
  'n',
  '<leader>ja',
  require('fish-files').add_hook,
  { desc = 'Hook this file' }
)
vim.keymap.set(
  'n',
  '<leader>jd',
  require('fish-files').remove_hook,
  { desc = 'Unhook this file' }
)
vim.keymap.set(
  'n',
  '<leader>jm',
  require('fish-files').manage_hooks,
  { desc = 'Manage hooks' }
)
vim.keymap.set(
  'n',
  '<leader>jr',
  require('fish-files').unhook_all_files,
  { desc = 'Unhook all files' }
)
