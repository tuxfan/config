return {
  'neovim/nvim-lspconfig',
  dependencies = {
    'saghen/blink.cmp',
    { 'antosha417/nvim-lsp-file-operations', config = true },
    { 'folke/neodev.nvim', opts = {} }
  },
  config = function()
    local capabilities = require('blink.cmp').get_lsp_capabilities()
    vim.lsp.config('*', capabilities)
  end
}
