---------------------------------------------------------------------------------
-- LSP
---------------------------------------------------------------------------------
return {
  {
    'williamboman/mason.nvim',
    build = ':MasonUpdate',
    cmd = 'Mason',
    opts = {
      ui = {
        icons = {
          package_installed = '',
          package_pending = '',
          package_uninstalled = ''
        }
      }
    }
  },
  {
    'neovim/nvim-lspconfig',
    -----------------------------------------------------------------------------
    -- Dependencies
    -----------------------------------------------------------------------------
    dependencies = {
      'williamboman/mason.nvim',
      {
        'williamboman/mason-lspconfig.nvim',
        opts = {
          ensure_installed = {
            'cmake',
            'lua_ls',
            'texlab',
            'yamlls'
          }
        }
      }
    },
    -----------------------------------------------------------------------------
    -- Events
    -----------------------------------------------------------------------------
    event = { "BufReadPre", "BufNewFile" }
  }
}
