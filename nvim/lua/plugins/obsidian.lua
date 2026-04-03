local search = require('obsidian.search')

require('obsidian').setup {
  legacy_commands = false,
  workspaces = {
    {
      name = 'lanl',
      path = '~/.vault/lanl',
    },
    {
      name = 'personal',
      path = '~/.vault/personal',
    },
  },
}

vim.keymap.set('n', '<leader>oo', '<cmd>Obsidian quick_switch<CR>', { desc = 'Obsidian open note (picker)' })
vim.keymap.set('n', '<leader>ow', '<cmd>Obsidian workspace<CR>', { desc = 'Obsidian change workspace' })
vim.keymap.set('n', '<leader>on', '<cmd>Obsidian new<CR>', { desc = 'Obsidian new note' })
vim.keymap.set('n', '<leader>ob', '<cmd>Obsidian backlinks<CR>', { desc = 'Obsidian backlinks' })
vim.keymap.set('n', '<leader>oi', function()
  local notes = search.resolve_note('index')
  if vim.tbl_isempty(notes) then
    vim.notify("Obsidian note alias 'index' not found", vim.log.levels.ERROR)
    return
  end

  vim.cmd.edit(vim.fn.fnameescape(tostring(notes[1].path)))
end, { desc = "Obsidian open the note with alias 'index'" })
