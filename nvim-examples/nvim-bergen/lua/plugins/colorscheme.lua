---------------------------------------------------------------------------------
-- Rose Pine Theme
---------------------------------------------------------------------------------
return {
  {
    'rose-pine/neovim',
    as = 'rose-pine',
    lazy = false,
    config = function()
        vim.cmd('colorscheme rose-pine')
    end
  }
}
