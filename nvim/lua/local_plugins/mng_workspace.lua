-- Save and restore the active Obsidian workspace between sessions.

local obsidian = require("obsidian")

local workspace_path = vim.fs.joinpath(vim.fn.stdpath("config"), "workspace.txt")
local workspace_name = "lanl"

local fread = io.open(workspace_path, "r")
if fread then
  local line = fread:read("*l")
  fread:close()
  if line and line ~= "" then
    workspace_name = line
  end
end

vim.api.nvim_create_autocmd("VimLeave", {
  group = vim.api.nvim_create_augroup("mng_workspace", { clear = true }),
  callback = function()
    local current = _G.Obsidian and _G.Obsidian.workspace
    if not current or not current.name then
      return
    end

    local fwrite = io.open(workspace_path, "w")
    if not fwrite then
      return
    end

    fwrite:write(current.name)
    fwrite:close()
  end,
  once = true,
})

local current = _G.Obsidian and _G.Obsidian.workspace
if current.name ~= workspace_name then
  local ok = pcall(obsidian.Workspace.set, workspace_name)
  if not ok and workspace_name ~= "lanl" then
    obsidian.Workspace.set("lanl")
  end
end
