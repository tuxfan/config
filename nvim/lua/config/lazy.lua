return {
  {
    'nvim-telescope/telescope.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' }
  },
  {
    "nvim-telescope/telescope-file-browser.nvim",
    dependencies = {
      {
        'nvim-telescope/telescope.nvim',
        'nvim-lua/plenary.nvim'
      }
    }
  },
  {
    'nvim-treesitter/nvim-treesitter',
    run = function()
      local ts_update =
        require('nvim-treesitter.install').update({ with_sync = true })
      ts_update()
    end
  },
  {
    'folke/trouble.nvim',
    dependencies = {
      'nvim-tree/nvim-web-devicons'
    }
  },
  {
    'rose-pine/neovim',
    as = 'rose-pine',
    lazy = false,
    config = function()
        vim.cmd('colorscheme rose-pine')
    end
  },
  {
    'theprimeagen/harpoon',
    dependencies = { 'nvim-lua/plenary.nvim' },
  }
}
