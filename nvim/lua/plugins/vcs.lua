require('gitsigns').setup {
  numhl = true, -- Toggle with `:Gitsigns toggle_numhl`
  current_line_blame = true, -- Toggle with `:Gitsigns toggle_current_line_blame`
  -- NOTE: Not needed bufnr here as keyamp applies to current buffer
  on_attach = function( --[[ bufnr ]])
    -- Setup keymaps
    vim.keymap.set('n', '<leader>hb', function()
      require('gitsigns').blame_line()
    end, { desc = 'Blame Line' })
    vim.keymap.set('n', ']h', function()
      require('gitsigns').nav_hunk 'next'
    end, { desc = 'Goto next hunk' })
    vim.keymap.set('n', '[h', function()
      require('gitsigns').nav_hunk 'prev'
    end, { desc = 'Goto previous hunk' })
    vim.keymap.set('n', '<leader>hp', function()
      require('gitsigns').preview_hunk_inline()
    end, { desc = 'Preview Hunk inline' })
    vim.keymap.set('n', '<leader>hr', function()
      require('gitsigns').reset_hunk()
    end, { desc = 'Reset Hunk' })
    vim.keymap.set('n', '<leader>hs', function()
      require('gitsigns').stage_hunk()
    end, { desc = 'Stage/Unstage Hunk' })
  end,
}

require('jj').setup {}
