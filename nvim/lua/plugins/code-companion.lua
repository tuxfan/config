return {
  'olimorris/codecompanion.nvim',
  opts = {},
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-treesitter/nvim-treesitter'
  },
  config = function()
      require("codecompanion").setup({
      adapters = {
        ollama_remote = function()
          return require("codecompanion.adapters").extend("ollama", {
            name = "ollama_remote",
            env = {
              url = "https://192.168.1.104:10200",
              api_key = "OLLAMA_API_KEY",
            },
            headers = {
              ["Content-Type"] = "application/json",
              ["Authorization"] = "Bearer ${api_key}",
            },
            parameters = {
              sync = true,
            },
            schema = {
              model = {
                default = "gemma3n",
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
      strategies = {
        chat = {
          adapter = "ollama_remote",
        },
        inline = {
          adapter = "ollama_remote",
        },
        agent = {
          adapter = "ollama_remote",
        },
      },
    })
  end
}
