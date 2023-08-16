local nvim_lsp = require('lspconfig')

local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = require('cmp_nvim_lsp').default_capabilities(capabilities)

local servers = {
  "bashls",
  "clangd",
  "pyright",
  "jsonls",
  "dockerls",
  "fortls",
  "julials",
  "texlab"
}

for _, lsp in ipairs(servers) do
  nvim_lsp[lsp].setup({
    on_attach = common_on_attach,
    capabilities = capabilities,
  })
end
