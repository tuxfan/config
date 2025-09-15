return {
  'olimorris/codecompanion.nvim',
  version = "v16.1.0",
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
              url = "http://192.168.1.104:10200",
              api_key = "OLLAMA_API_KEY",
              models_endpoint = ""
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
        openai_remote = function()
          return require("codecompanion.adapters").extend("openai_compatible", {
            name = "openai_remote",
            env = {
              url = "https://darwin-litellm.lanl.gov",
              api_key = "sk-letL1Mu-14m9a0NeH7C8Fg",
              models_endpoint = "/models"
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
                default = "sambanova/Meta-Llama-3.3-70B-Instruct",
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
          adapter = "openai_remote",
        },
        inline = {
          adapter = "openai_remote",
        },
        agent = {
          adapter = "openai_remote",
        },
      },
    })
  end
}
