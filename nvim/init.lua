--- Load all the options
require 'options'

--- Make the vim shell "fish"
vim.opt.shell = 'fish'
vim.opt.foldlevelstart = 99

--- Install `lazy.nvim` plugin manager
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
  local out = vim.fn.system {
    'git',
    'clone',
    '--filter=blob:none',
    '--branch=stable',
    lazyrepo,
    lazypath,
  }
  if vim.v.shell_error ~= 0 then
    error('Error cloning lazy.nvim:\n' .. out)
  end
end

---@type vim.Option
local rtp = vim.opt.rtp
rtp:prepend(lazypath)

--- [[ Configure and install plugins ]]

--- Load pre-lazy keymaps
require 'keymaps-pre'

require('lazy').setup({

  --- Import all plugins inside of the "plugins" directory
  { import = 'plugins' },

  --- Add treesitter
  { --- Highlight, edit, and navigate code
    'nvim-treesitter/nvim-treesitter',
    build = ':TSUpdate',
    main = 'nvim-treesitter.configs', -- Sets main module to use for opts
    -- [[ Configure Treesitter ]] See `:help nvim-treesitter`
    opts = {
      ensure_installed = {
        'bash',
        'c',
        'diff',
        'html',
        'lua',
        'luadoc',
        'markdown',
        'markdown_inline',
        'query',
        'vim',
        'vimdoc',
      },
      --- Autoinstall languages that are not installed
      auto_install = true,
      highlight = {
        enable = true,
        --- Some languages depend on vim's regex highlighting system (such as Ruby) for indent rules.
        ---  If you are experiencing weird indenting issues, add the language to
        ---  the list of additional_vim_regex_highlighting and disabled languages for indent.
        additional_vim_regex_highlighting = { 'ruby' },
      },
      indent = { enable = true, disable = { 'ruby' } },
    },
    --- There are additional nvim-treesitter modules that you can use to interact
    --- with nvim-treesitter. You should go explore a few and see what interests you:
    ---
    ---    - Incremental selection: Included, see `:help nvim-treesitter-incremental-selection-mod`
    ---    - Show your current context: https://github.com/nvim-treesitter/nvim-treesitter-context
    ---    - Treesitter + textobjects: https://github.com/nvim-treesitter/nvim-treesitter-textobjects
  },
},
{
  ui = {
    --- If you are using a Nerd Font: set icons to an empty table which will use the
    --- default lazy.nvim defined Nerd Font icons, otherwise define a unicode icons table
    icons = vim.g.have_nerd_font and {} or {
      cmd = '⌘',
      config = '🛠',
      event = '📅',
      ft = '📂',
      init = '⚙',
      keys = '🗝',
      plugin = '🔌',
      runtime = '💻',
      require = '🌙',
      source = '📄',
      start = '🚀',
      task = '📌',
      lazy = '💤 ',
    },
  },
})

--- Load keymaps-post
require 'keymaps-post'
