vim.cmd [[packadd packer.nvim]]

return require('packer').startup(
function(use)
  use 'wbthomason/packer.nvim'

  use {
    'nvim-telescope/telescope.nvim', tag = '0.1.2',
    requires = { {'nvim-lua/plenary.nvim'} }
  }

  use {
    "nvim-telescope/telescope-file-browser.nvim",
    requires = { {'nvim-telescope/telescope.nvim', 'nvim-lua/plenary.nvim'} }
  }

  use{
    'rose-pine/neovim',
	  as = 'rose-pine',
	  config = function()
	      vim.cmd('colorscheme rose-pine')
	  end
  }

  use {
    'nvim-treesitter/nvim-treesitter',
    run = function()
      local ts_update = require('nvim-treesitter.install').update({ with_sync = true })
      ts_update()
    end
  }

  use { 'nvim-treesitter/playground' }
  use { 'mbbill/undotree' }
  use { 'tpope/vim-fugitive' }
  use { 'theprimeagen/harpoon' }

  use { 'neovim/nvim-lspconfig' }
  use { 'L3MON4D3/LuaSnip' }
  use {
    'hrsh7th/nvim-cmp',
    requires = {
      'hrsh7th/cmp-nvim-lsp',
      'hrsh7th/cmp-buffer',
      'hrsh7th/cmp-path',
      'hrsh7th/cmp-nvim-lua',
      'saadparwaiz1/cmp_luasnip'
    }
  }

end
)
