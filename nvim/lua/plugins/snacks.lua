local Snacks = require 'snacks'
local devicons = require 'nvim-web-devicons'

Snacks.setup {
  bigfile = { enabled = true },
  dashboard = { enabled = false },
  explorer = { enabled = true },
  image = { enabled = true },
  indent = { enabled = true, chunk = { enabled = true } },
  lazygit = { enabled = true },
  notifier = { enabled = true },
  quickfile = { enabled = true },
  rename = { enabled = true },
  scratch = { enabled = true },
  scroll = { enabled = true },
  statuscolumn = { enabled = true },
  toggle = { enabled = true },
}

vim.api.nvim_create_autocmd('User', {
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
    Snacks.toggle.option('wrap', { name = 'Wrap' }):map '<leader>uW'
    Snacks.toggle
      .option('relativenumber', { name = 'Relative Number' })
      :map '<leader>uL'
    Snacks.toggle.diagnostics():map '<leader>ud'
    Snacks.toggle.line_number():map '<leader>ul'
    Snacks.toggle
      .option('conceallevel', {
        off = 0,
        on = vim.o.conceallevel > 0 and vim.o.conceallevel or 2,
      })
      :map '<leader>uc'
    Snacks.toggle.treesitter():map '<leader>uT'
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

    -- Toggle git blame
    Snacks.toggle
      .new({
        id = 'gitsigns-blame',
        name = 'Gitsigns Blame',
        get = function()
          return require('gitsigns.config').config.current_line_blame
        end,
        set = function()
          require('gitsigns').toggle_current_line_blame()
        end,
      })
      :map '<leader>ub'

    -- Toggle move-enclosing ts
    Snacks.toggle
      .new({
        id = 'move-enclosing',
        name = 'Move Enclosing TS',
        get = function()
          return require('move-enclosing').use_ts
        end,
        set = function()
          require('move-enclosing').toggle_ts()
        end,
      })
      :map '<leader>ue'

    -- Toggle Markview
    Snacks.toggle
      .new({
        id = 'markview',
        name = 'Markview',
        get = function()
          local buffer = vim.api.nvim_get_current_buf()
          if not require('markview.state').buf_attached(buffer) then
            require('markview.commands').attach(buffer)
            require('markview.commands').disable(buffer)
          end
          return require('markview.state').get_buffer_state(buffer, false).enable
        end,
        set = function()
          local buffer = vim.api.nvim_get_current_buf()
          require('markview.commands').toggle(buffer)
        end,
      })
      :map '<leader>um'

    -- Toggle for no neck pain
    Snacks.toggle
      .new({
        id = 'no-neck-pain',
        name = 'No neck pain',
        get = function()
          local state = require('no-neck-pain').state
          if state then
            return state.enabled
          else
            return false
          end
        end,
        set = function()
          require('no-neck-pain').toggle()
        end,
      })
      :map '<leader>uP'

    -- Toggle for relative number change
    Snacks.toggle
      .new({
        id = 'rel_number_change',
        name = 'Relative num change',
        get = function()
          return Change_relnum
        end,
        set = function()
          Change_relnum = not Change_relnum
        end,
      })
      :map '<leader>uf'

    -- Fully custom toggle for colorizer
    Snacks.toggle
      .new({
        id = 'colorizer',
        name = 'Colorizer',
        get = function()
          return require('colorizer').is_buffer_attached(0)
        end,
        set = function()
          vim.cmd 'ColorizerToggle'
        end,
      })
      :map '<leader>uz'

    -- Toggle for gitsigns
    Snacks.toggle
      .new({
        id = 'gitsigns-word-diff',
        name = 'Word diff',
        get = function()
          return require('gitsigns.config').config.word_diff
        end,
        set = function()
          require('gitsigns').toggle_word_diff()
        end,
      })
      :map '<leader>uw'

    -- Fully custom toggle for visual_bold
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
