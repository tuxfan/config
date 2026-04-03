require('oil').setup {
  skip_confirm_for_simple_edits = true,
  watch_for_changes = true,
  use_default_keymaps = false,
  keymaps = {
    ['-'] = { 'actions.cd', mode = 'n' },
    ['_'] = { 'actions.open_cwd', mode = 'n' },
    ['<BS>'] = { 'actions.parent', mode = 'n' },
    ['<C-c>'] = { 'actions.close', mode = 'n' },
    ['<C-p>'] = 'actions.preview',
    ['<CR>'] = 'actions.select',
    ['g?'] = { 'actions.show_help', mode = 'n' },
    ['g.'] = { 'actions.toggle_hidden', mode = 'n' },
    ['gs'] = { 'actions.change_sort', mode = 'n' },
    ['<leader>h'] = { 'actions.select', opts = { horizontal = true } },
    ['<leader>v'] = { 'actions.select', opts = { vertical = true } },
  },
  -- Configuration for the floating action confirmation window
  confirmation = {
    border = 'rounded',
  },
}

-- Open oil
vim.keymap.set('n', '<leader>l', vim.cmd.Oil, { desc = 'Oil' })

-- If renaming a file with Oil, let the LSP know
-- through snacks.rename
vim.api.nvim_create_autocmd('User', {
  pattern = 'OilActionsPost',
  callback = function(event)
    if event.data.actions[1].type == 'move' then
      require('snacks').rename.on_rename_file(
        event.data.actions[1].src_url,
        event.data.actions[1].dest_url
      )
    end
  end,
})
