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
            'bashls',
            'dockerls',
            'jsonls',
            'lua_ls',
	    'marksman',
            'pyright',
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
