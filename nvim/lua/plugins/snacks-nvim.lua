return {
  'folke/snacks.nvim',
  priority = 1000,
  lazy = false,
  ---@type snacks.Config
  opts = {
    bigfile = { enabled = true }, -- Deactivates things for files too large
    dashboard = { enabled = true }, -- Initial neovim dashboard
    indent = { enabled = true }, -- Indent lines
    rename = { enabled = true }, -- Rename files
    scroll = { enabled = true }, -- Smooth scrolling
    picker = { enabled = true }, -- Picker
    statuscolumn = { enabled = true }, -- Status column on its own
    scratch = { enabled = true }, -- Scratch space
    scope = {
      enabled = true,
      treesitter = {
        blocks = {
          enabled = true,
          'function_declaration',
          'function_definition',
          'method_declaration',
          'method_definition',
          'class_declaration',
          'class_definition',
          'do_statement',
          'while_statement',
          'repeat_statement',
          'if_statement',
          'for_statement',
        },
        -- these treesitter fields will be considered as blocks
        field_blocks = {
          'local_declaration',
        },
      },
    }, -- Scope jumps
    toggle = { enabled = true }, -- Toggle things
    lazygit = { enabled = true }, -- Lazygit
    words = { enabled = true }, -- LSP help for references
    notifier = { enabled = true }, -- Better notifications
    zen = { enabled = true }, -- Zen/Zoom mode
  },
  keys = {
    {
      '<C-w>z',
      function()
        Snacks.zen()
      end,
      desc = 'Toggle Zen Mode',
    },
    {
      '<C-w>m',
      function()
        Snacks.zen.zoom()
      end,
      desc = 'Toggle Zoom',
    },
    {
      '<leader>.',
      function()
        Snacks.scratch()
      end,
      desc = 'Toggle Scratch Buffer',
    },
    {
      '<leader>S',
      function()
        Snacks.scratch.select()
      end,
      desc = 'Select Scratch Buffer',
    },
    {
      '<leader>n',
      function()
        Snacks.notifier.show_history()
      end,
      desc = 'Notification History',
    },
    {
      '<leader>cR',
      function()
        Snacks.rename.rename_file()
      end,
      desc = 'Rename File',
    },
    {
      '<leader>gB',
      function()
        Snacks.gitbrowse()
      end,
      desc = 'Git Browse',
      mode = { 'n', 'v' },
    },
    {
      '<leader>gg',
      function()
        Snacks.lazygit()
      end,
      desc = 'Lazygit',
    },
    {
      '<leader>un',
      function()
        Snacks.notifier.hide()
      end,
      desc = 'Dismiss All Notifications',
    },
  },
  init = function()
    -- Local variable for keeping track of visual bold
    local visual_bold = false

    vim.api.nvim_create_autocmd('User', {
      pattern = 'VeryLazy',
      callback = function()
        -- Setup some globals for debugging (lazy-loaded)
        _G.dd = function(...)
          Snacks.debug.inspect(...)
        end
        _G.bt = function()
          Snacks.debug.backtrace()
        end
        vim.print = _G.dd -- Override print to use snacks for `:=` command

        -- Create some toggle mappings
        Snacks.toggle.option('spell', { name = 'Spelling' }):map '<leader>us'
        Snacks.toggle.option('wrap', { name = 'Wrap' }):map '<leader>uw'
        Snacks.toggle
          .option('relativenumber', { name = 'Relative Number' })
          :map '<leader>uL'
        Snacks.toggle.diagnostics():map '<leader>ud'
        Snacks.toggle.line_number():map '<leader>ul'
        Snacks.toggle
          .option(
            'conceallevel',
            { off = 0, on = vim.o.conceallevel > 0 and vim.o.conceallevel or 2 }
          )
          :map '<leader>uc'
        Snacks.toggle.treesitter():map '<leader>uT'
        Snacks.toggle
          .option(
            'background',
            { off = 'light', on = 'dark', name = 'Dark Background' }
          )
          :map '<leader>ub'
        Snacks.toggle.inlay_hints():map '<leader>uh'
        Snacks.toggle.indent():map '<leader>ug'
        Snacks.toggle.dim():map '<leader>uD'
        Snacks.toggle.animate():map '<leader>ua'
        Snacks.toggle
          .option('cursorline', { name = 'Cursor Line' })
          :map '<leader>uR'
        Snacks.toggle
          .option('cursorcolumn', { name = 'Cursor Column' })
          :map '<leader>ur'

        -- Toggle context
        Snacks.toggle
          .new({
            id = 'treesitter-context',
            name = 'Treesitter Context',
            get = function()
              return require('treesitter-context').enabled()
            end,
            set = function()
              require('treesitter-context').toggle()
            end,
          })
          :map '<leader>ut'

        -- Toggle autopairs
        Snacks.toggle
          .new({
            id = 'nvim-autopairs',
            name = 'Autopairs',
            get = function()
              return not require('nvim-autopairs').state.disabled
            end,
            set = function()
              require('nvim-autopairs').toggle()
            end,
          })
          :map '<leader>up'

        -- Fully custom toggle
        Snacks.toggle
          .new({
            id = 'visual_bold',
            name = 'Visual Bold',
            get = function()
              return visual_bold
            end,
            set = function(state)
              if state then
                vim.cmd.highlight {
                  args = { 'link Visual IncSearch' },
                  bang = true,
                }
                visual_bold = true
              else
                vim.cmd.highlight { args = { 'link Visual NONE' } }
                visual_bold = false
              end
            end,
          })
          :map '<leader>uv'
      end,
    })
  end,
}
