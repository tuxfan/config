require('noice').setup {
  routes = {
    -- HACK: Temporary fix for external command show
    {
      view = 'notify',
      filter = {
        event = 'msg_show',
        kind = {
          'shell_out',
          'shell_err',
        },
      },
    },
  },
  lsp = {
    -- override markdown rendering so that **cmp** and other plugins use **Treesitter**
    override = {
      ['vim.lsp.util.convert_input_to_markdown_lines'] = true,
      ['vim.lsp.util.stylize_markdown'] = true,
    },
    progress = {
      enabled = false,
    },
    signature = {
      enabled = false, -- Remove the huge signature help from noice
    },
  },
  cmdline = {
    view = 'cmdline',
  },
  -- you can enable a preset for easier configuration
  presets = {
    bottom_search = false,        -- use a classic bottom cmdline for search
    command_palette = true,       -- position the cmdline and popupmenu together
    long_message_to_split = true, -- long messages will be sent to a split
    inc_rename = false,           -- enables an input dialog for inc-rename.nvim
    lsp_doc_border = true,        -- add a border to hover docs and signature help
  },
}
