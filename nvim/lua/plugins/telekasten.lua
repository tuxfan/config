---------------------------------------------------------------------------------
-- Telekasten
---------------------------------------------------------------------------------
return {
  {
    'renerocksai/telekasten.nvim',
    dependencies = {
      'nvim-telescope/telescope.nvim',
      'nvim-telekasten/calendar-vim'
    },
    opts = {
      home = vim.fn.expand("~/.notes")
    }
  }
}
