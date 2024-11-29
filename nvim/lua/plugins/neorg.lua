return {
  {
    'vhyrro/luarocks.nvim',
    priority = 1000, -- We'd like this plugin to load first out of the rest
    config = true, -- This automatically runs `require('luarocks-nvim').setup()`
  },
  {
    'nvim-neorg/neorg',
    dependencies = { 'luarocks.nvim', 'nvim-lua/plenary.nvim' },
    -- put any other flags you wanted to pass to lazy here!
    config = function()
      require('neorg').setup({
        load = {
          ['core.defaults'] = {},
          ['core.concealer'] = {},
          ['core.dirman'] = {
            config = {
              workspaces = {
                notes = '~/.notes/notes',
                lanl = '~/.notes/lanl'
              },
              default_workspace = 'lanl'
            },
            ['core.keybinds'] = {
              config = {
                default_keybinds = true
              }
            }
          }
        },
        lazy = false,
        version = '*',
        config = true,
      })
    end,
  }
}
