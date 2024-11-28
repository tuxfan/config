local nvim_lsp = require('lspconfig')
local utils = require('lsp.utils')

local common_on_attach = utils.common_on_attach

local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = require('cmp_nvim_lsp').default_capabilities(capabilities)

local servers = {
  "bashls",
  "clangd",
  "dockerls",
  "fortls",
  "jsonls",
  "julials",
  "lua_ls",
  "pyright",
  "texlab",
  "yamlls"
}

for _, lsp in ipairs(servers) do
  nvim_lsp[lsp].setup({
    on_attach = common_on_attach,
    capabilities = capabilities,
  })
end

require('lsp.sumneko')
