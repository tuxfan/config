local codex = require 'codex'

vim.keymap.set({ 'n', 't' }, '<leader>cd', function()
  codex.toggle()
end, { desc = 'Toggle Codex' })

codex.setup {
  keymaps = {
    quit = '<C-q>',
  },
  width = 0.5,
  panel = true,
}
