return {
  'olimorris/codecompanion.nvim',
  opts = {},
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-treesitter/nvim-treesitter'
  },
  config = function()
    require("codecompanion").setup({
      strategies = {
        chat = {
          adapter = "ollama"
        },
        inline = {
          adapter = "ollama"
        }
      },
  adapters = {
    llama3 = function()
      return require("codecompanion.adapters").extend("ollama", {
        name = "gemma3n", -- Give this adapter a different name to differentiate it from the default ollama adapter
        schema = {
          model = {
            default = "gemma3n:latest",
          },
          num_ctx = {
            default = 16384,
          },
          num_predict = {
            default = -1,
          },
        },
      })
    end,
  },
})
  end,
}
