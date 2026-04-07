-- Setup mason early for lsp capabilities below
require('mason').setup()
vim.lsp.enable('clangd')

require('lazydev').setup {
  library = {
    -- Load luvit types when the `vim.uv` word is found
    { path = '${3rd}/luv/library', words = { 'vim%.uv' } },
  },
}

--  This function gets run when an LSP attaches to a particular buffer.
--    That is to say, every time a new file is opened that is associated with
--    an lsp (for example, opening `main.rs` is associated with `rust_analyzer`) this
--    function will be executed to configure the current buffer
local lsp_attach_group = vim.api.nvim_create_augroup('lsp-attach', { clear = true })
local lsp_detach_group = vim.api.nvim_create_augroup('lsp-detach', { clear = true })

vim.api.nvim_create_autocmd('LspAttach', {
  group = lsp_attach_group,
  callback = function(event)
    local client = vim.lsp.get_client_by_id(event.data.client_id)
    local highlight_augroup

    -- Uncomment to enable inlay hints automatically
    -- vim.lsp.inlay_hint.enable()

    -- Set up foldmethod and foldexpr
    vim.opt.foldmethod = 'expr'
    vim.opt.foldexpr = 'v:lua.vim.lsp.foldexpr()'

    -- Create a function that lets us more easily define mappings
    -- specific for LSP related items. It sets the mode, buffer and
    -- description for us each time.
    ---@param keys string
    ---@param func function
    ---@param desc string
    ---@param mode? string|string[]
    local map = function(keys, func, desc, mode)
      mode = mode or 'n'
      vim.keymap.set(
        mode,
        keys,
        func,
        { buffer = event.buf, desc = 'LSP: ' .. desc }
      )
    end

    -- Rename the variable under your cursor.
    --  Most Language Servers support renaming across files, etc.
    map('<leader>cr', vim.lsp.buf.rename, 'Rename')

    -- Execute a code action, usually your cursor needs to be on top of an error
    -- or a suggestion from your LSP for this to activate.
    map('<leader>ca', vim.lsp.buf.code_action, 'Code Action', { 'n', 'x' })

    -- The following two autocommands are used to highlight references of the
    -- word under your cursor when your cursor rests there for a little while.
    -- See `:help CursorHold` for information about when this is executed
    --
    -- When you move your cursor, the highlights will be cleared (the second
    -- autocommand).
    if client and client:supports_method 'textDocument/documentHighlight' then
      highlight_augroup = vim.api.nvim_create_augroup(
        ('lsp-highlight-%d'):format(event.buf),
        { clear = true }
      )
      vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
        buffer = event.buf,
        group = highlight_augroup,
        callback = vim.lsp.buf.document_highlight,
      })

      vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
        buffer = event.buf,
        group = highlight_augroup,
        callback = vim.lsp.buf.clear_references,
      })
    end

    vim.api.nvim_create_autocmd('LspDetach', {
      group = lsp_detach_group,
      buffer = event.buf,
      callback = function(event2)
        vim.lsp.buf.clear_references()
        if highlight_augroup then
          vim.api.nvim_clear_autocmds {
            group = highlight_augroup,
            buffer = event2.buf,
          }
        end
      end,
    })
  end,
})

-- Diagnostic Config
vim.diagnostic.config {
  severity_sort = true,
  float = { border = 'rounded', source = 'if_many' },
  underline = { severity = vim.diagnostic.severity.ERROR },
  signs = vim.g.have_nerd_font and {
    text = {
      [vim.diagnostic.severity.ERROR] = '󰅚 ',
      [vim.diagnostic.severity.WARN] = '󰀪 ',
      [vim.diagnostic.severity.INFO] = '󰋽 ',
      [vim.diagnostic.severity.HINT] = '󰌶 ',
    },
  } or {},
  virtual_text = {
    source = 'if_many',
    spacing = 2,
    format = function(diagnostic)
      local diagnostic_message = {
        [vim.diagnostic.severity.ERROR] = diagnostic.message,
        [vim.diagnostic.severity.WARN] = diagnostic.message,
        [vim.diagnostic.severity.INFO] = diagnostic.message,
        [vim.diagnostic.severity.HINT] = diagnostic.message,
      }
      return diagnostic_message[diagnostic.severity]
    end,
  },
}

-- Ensure the servers and tools above are installed
-- You can add other tools here that you want Mason to install
-- for you, so that they are available from within Neovim.
local all_tools = {
  'autopep8',
  'bash-language-server',
  'bibtex-tidy',
  'clang-format',
  'cmake-language-server',
  'cmakelang',
  'cmakelint',
  'codelldb',
  'debugpy',
  'flake8',
  'gopls',
  'isort',
  'json-lsp',
  'jupytext',
  'local-lua-debugger-vscode',
  'lua-language-server',
  'markdownlint',
  'mypy',
  'pydocstyle',
  'python-lsp-server',
  'shfmt',
  'stylua',
  'taplo',
  'tex-fmt',
  'texlab',
  'yaml-language-server',
}
require('mason-tool-installer').setup {
  ensure_installed = all_tools,
}

-- Only activate the servers. Also, LSPs may have different names
-- in nvim than the tools have in mason, such as lua-language-server -> lua_ls
-- so write those correctly here
local all_servers = {
  'bacon-ls',
  'bashls',
  'clangd',
  'cmake',
  'gopls',
  'json-lsp',
  'lua_ls',
  'pylsp',
  'stylua',
  'taplo',
  'texlab',
  'yaml-language-server',
}
vim.lsp.enable(all_servers)

-- Get LSP capabilities from blink for the lsp and add them to the servers
vim.lsp.config(
  '*',
  { capabilities = require('blink.cmp').get_lsp_capabilities() }
)
