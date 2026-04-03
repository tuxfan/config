vim.pack.add {
  -- [ general ----------------------------------------------------------------]
  'https://github.com/nvim-tree/nvim-web-devicons',
  'https://github.com/rcarriga/nvim-notify',

  -- blink
  -- NOTE: The version is specified so the rust fuzzy find can be compiled
  {
    src = 'https://github.com/saghen/blink.cmp',
    version = vim.version.range '1.*',
  },

  -- treesitter
  {
    src = 'https://github.com/nvim-treesitter/nvim-treesitter',
    version = 'main',
  },
  -- [ general ----------------------------------------------------------------]

  -- codex
  'https://github.com/kkrampis/codex.nvim',

  -- colorschemes
  'https://github.com/rose-pine/neovim',
  'https://github.com/EdenEast/nightfox.nvim',
  'https://github.com/folke/tokyonight.nvim',
  'https://github.com/rebelot/kanagawa.nvim',
  'https://github.com/catppuccin/nvim',
  'https://github.com/binhtddev/dracula.nvim',

  -- editing
  'https://github.com/folke/todo-comments.nvim',
  'https://github.com/rafamadriz/friendly-snippets',
  'https://github.com/stevearc/conform.nvim',
  'https://github.com/windwp/nvim-autopairs',
  'https://github.com/ysmb-wtsg/in-and-out.nvim',

  -- lsp
  'https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim',
  'https://github.com/folke/lazydev.nvim',
  'https://github.com/mason-org/mason.nvim',
  'https://github.com/neovim/nvim-lspconfig',

  -- lualine
  'https://github.com/nvim-lualine/lualine.nvim',

  -- markview
  'https://github.com/OXY2DEV/markview.nvim',

  -- multicursor
  {
    src = 'https://github.com/jake-stewart/multicursor.nvim',
    version = '1.0',
  },

  -- noice
  'https://github.com/MunifTanjim/nui.nvim',
  'https://github.com/folke/noice.nvim',
  'https://github.com/nvim-lua/plenary.nvim',

  -- obsidian
  'https://github.com/obsidian-nvim/obsidian.nvim',

  -- oil
  'https://github.com/stevearc/oil.nvim',

  -- others
  'https://github.com/AndresYague/move-enclosing.nvim',
  'https://github.com/AndresYague/nvim-colorizer.lua',
  'https://github.com/AndresYague/print-debug.nvim',
  'https://github.com/folke/flash.nvim',
  'https://github.com/folke/persistence.nvim',
  'https://github.com/kylechui/nvim-surround',
  'https://github.com/AndresYague/fish-files.nvim',
  'https://github.com/shortcuts/no-neck-pain.nvim.git',

  -- snacks
  'https://github.com/folke/snacks.nvim',

  -- treesitter
  'https://github.com/nvim-treesitter/nvim-treesitter-context',
  {
    src = 'https://github.com/nvim-treesitter/nvim-treesitter-textobjects',
    version = 'main',
  },

  -- vcs
  'https://github.com/lewis6991/gitsigns.nvim',
  'https://github.com/tpope/vim-fugitive',
  'https://github.com/NicolasGB/jj.nvim.git',

  -- which-key
  'https://github.com/folke/which-key.nvim',
}

-- Needs to come ASAP
require 'plugins.snacks'

require 'plugins.codex'
require 'plugins.colorschemes'
require 'plugins.editing'
require 'plugins.lsp'
require 'plugins.lualine'
require 'plugins.multicursor'
require 'plugins.noice'
require 'plugins.obsidian'
require 'plugins.oil'
require 'plugins.others'
require 'plugins.picker' -- after lsp
require 'plugins.treesitter'
require 'plugins.vcs'
require 'plugins.which-key'

-- Activate nvim plugins
vim.cmd.packadd { args = { 'nvim.undotree' }, bang = true }
vim.cmd.packadd { args = { 'termdebug' }, bang = true }
