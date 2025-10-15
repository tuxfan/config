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
                default = "qwen3-coder:latest",
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
        sn_remote = function()
          return require("codecompanion.adapters").extend("openai_compatible", {
            name = "sn_remote",
            env = {
              url = "https://aiportal-api.aws.lanl.gov",
              api_key = "sk-2bO3sHuGTcAl7VsosDY4ew",
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
                default = "sambanova.Llama-4-Maverick-17B-128E-Instruct",
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
        claude_remote = function()
          return require("codecompanion.adapters").extend("openai_compatible", {
            name = "claude_remote",
            env = {
              url = "https://aiportal-api.aws.lanl.gov",
              api_key = "sk-47HzRPl4LQsqSDcXz0XkDA",
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
                default = "anthropic.claude-3-7-sonnet-20250219-v1:0",
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
        darwin_remote = function()
          return require("codecompanion.adapters").extend("openai_compatible", {
            name = "darwin_remote",
            env = {
              url = "https://aiportal-api.aws.lanl.gov",
              api_key = "sk-n_aAhaA6n3r5jd-KiVOYzg",
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
                default = "darwin.gpt-oss-120b",
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
          adapter = "claude_remote",
        },
        inline = {
          adapter = "claude_remote",
        },
        agent = {
          adapter = "claude_remote",
        },
      },
    })
  end
}
