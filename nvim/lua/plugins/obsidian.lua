local api = require('obsidian.api')
local Note = require('obsidian.note')

require('obsidian').setup {
  legacy_commands = false,
  workspaces = {
    {
      name = 'lanl',
      path = '~/.vault/lanl',
    },
    {
      name = 'personal',
      path = '~/.vault/personal',
    },
  },
}

vim.keymap.set('n', '<leader>oo', '<cmd>Obsidian quick_switch<CR>', { desc = 'Obsidian open note (picker)' })
vim.keymap.set('n', '<leader>ow', '<cmd>Obsidian workspace<CR>', { desc = 'Obsidian change workspace' })
vim.keymap.set('n', '<leader>on', '<cmd>Obsidian new<CR>', { desc = 'Obsidian new note' })
vim.keymap.set('n', '<leader>ob', '<cmd>Obsidian backlinks<CR>', { desc = 'Obsidian backlinks' })
vim.keymap.set('n', '<leader>oc', '<cmd>Obsidian check<CR>', { desc = 'Obsidian check' })
vim.keymap.set({ 'n', 'x' }, '<leader>ox', '<cmd>Obsidian toggle_checkbox<CR>', {
  desc = 'Obsidian cycle checkbox state',
})
vim.keymap.set('n', '<leader>oi', function()
  local query = 'index'
  local active_workspace = _G.Obsidian and _G.Obsidian.workspace
  local workspace_root

  if active_workspace and active_workspace.path then
    workspace_root = tostring(active_workspace.path)
  else
    local current_path = vim.api.nvim_buf_get_name(0)
    local workspace_dir = api.resolve_workspace_dir(current_path ~= '' and current_path or nil)
    workspace_root = tostring(workspace_dir)
  end

  local exact_filename = vim.fs.find('index.md', {
    path = workspace_root,
    type = 'file',
    limit = 1,
  })[1]

  if exact_filename then
    vim.cmd.edit(vim.fn.fnameescape(exact_filename))
    return
  end

  local markdown_files = vim.fs.find(function(name, path)
    return name:sub(-3) == '.md' and path:sub(1, #workspace_root) == workspace_root
  end, {
    path = workspace_root,
    type = 'file',
    limit = math.huge,
  })

  local exact_match
  for _, path in ipairs(markdown_files) do
    local ok, note = pcall(Note.from_file, path)
    if ok and note and vim.list_contains(note:reference_ids { lowercase = true }, query) then
      exact_match = path
      break
    end
  end

  if not exact_match then
    vim.notify("Obsidian note alias 'index' not found", vim.log.levels.ERROR)
    return
  end

  vim.cmd.edit(vim.fn.fnameescape(exact_match))
end, { desc = "Obsidian open the note with alias 'index'" })
