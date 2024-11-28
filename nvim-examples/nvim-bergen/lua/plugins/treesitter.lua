---------------------------------------------------------------------------------
-- Treesitter
---------------------------------------------------------------------------------
return {
  {
    'nvim-treesitter/nvim-treesitter',
    run = function()
      local ts_update =
        require('nvim-treesitter.install').update({ with_sync = true })
      ts_update()
    end,
    opts = {
      ensure_installed = {
        "bash",
        "cmake",
        "cpp",
        "comment",
        "c",
        "cuda",
        "dockerfile",
        "fortran",
        "gitignore",
        "html",
        "json",
        "make",
        "markdown",
        "latex",
        "lua",
        "python",
        "vim",
        "vimdoc",
        "query",
        "yaml"
      },
      sync_install = false,
      auto_install = true,
      highlight = { enable = true, additional_vim_regex_highlighting = false }
    },
    config = function(_, opts)
      require('nvim-treesitter.configs').setup(opts)
    end
  }
}
