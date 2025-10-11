return {
  {
    'stevearc/oil.nvim',
    opts = {
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
    },
  },
}
