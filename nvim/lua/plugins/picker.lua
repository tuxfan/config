local Snacks = require 'snacks'

-- Top Pickers & Explorer
vim.keymap.set({ 'n' }, '<leader>fs', function()
  Snacks.picker.smart()
end, { desc = 'Smart Find Files' })
vim.keymap.set({ 'n' }, '<leader>,', function()
  Snacks.picker.buffers()
end, { desc = 'Buffers' })
vim.keymap.set({ 'n' }, '<leader>/', function()
  Snacks.picker.grep {
    win = {
      input = {
        keys = {
          ['<c-t>'] = { 'filter_type', mode = { 'i', 'n' } },
        },
      },
    },
  }
end, { desc = 'Grep' })
vim.keymap.set({ 'n' }, '<leader>:', function()
  Snacks.picker.command_history()
end, { desc = 'Command History' })
vim.keymap.set({ 'n' }, '<leader>n', function()
  Snacks.picker.notifications()
end, { desc = 'Notification History' })
vim.keymap.set({ 'n' }, '<leader>e', function()
  Snacks.explorer()
end, { desc = 'File Explorer' })



-- find
vim.keymap.set({ 'n' }, '<leader>fb', function()
  Snacks.picker.buffers()
end, { desc = 'Buffers' })
vim.keymap.set({ 'n' }, '<leader>fc', function()
  Snacks.picker.files { cwd = vim.fn.stdpath 'config' }
end, { desc = 'Find Config File' })
vim.keymap.set({ 'n' }, '<leader><space>', function()
  Snacks.picker.files()
end, { desc = 'Find Files' })
vim.keymap.set({ 'n' }, '<leader>fg', function()
  Snacks.picker.git_files()
end, { desc = 'Find Git Files' })
vim.keymap.set({ 'n' }, '<leader>fp', function()
  Snacks.picker.projects()
end, { desc = 'Projects' })
vim.keymap.set({ 'n' }, '<leader>fr', function()
  Snacks.picker.recent()
end, { desc = 'Recent' })
-- git
vim.keymap.set({ 'n' }, '<leader>gb', function()
  Snacks.picker.git_branches()
end, { desc = 'Git Branches' })
vim.keymap.set({ 'n' }, '<leader>gl', function()
  Snacks.picker.git_log()
end, { desc = 'Git Log' })
vim.keymap.set({ 'n' }, '<leader>gL', function()
  Snacks.picker.git_log_line()
end, { desc = 'Git Log Line' })
vim.keymap.set({ 'n' }, '<leader>gs', function()
  Snacks.picker.git_status()
end, { desc = 'Git Status' })
vim.keymap.set({ 'n' }, '<leader>gS', function()
  Snacks.picker.git_stash()
end, { desc = 'Git Stash' })
vim.keymap.set({ 'n' }, '<leader>gd', function()
  Snacks.picker.git_diff()
end, { desc = 'Git Diff (Hunks)' })
vim.keymap.set({ 'n' }, '<leader>gf', function()
  Snacks.picker.git_log_file()
end, { desc = 'Git Log File' })
-- Grep
vim.keymap.set({ 'n' }, '<leader>sb', function()
  Snacks.picker.lines()
end, { desc = 'Buffer Lines' })
vim.keymap.set({ 'n' }, '<leader>sB', function()
  Snacks.picker.grep_buffers {
    win = {
      input = {
        keys = {
          ['<c-t>'] = { 'filter_type', mode = { 'i', 'n' } },
        },
      },
    },
  }
end, { desc = 'Grep Open Buffers' })
vim.keymap.set({ 'n' }, '<leader>sg', function()
  Snacks.picker.grep {
    win = {
      input = {
        keys = {
          ['<c-t>'] = { 'filter_type', mode = { 'i', 'n' } },
        },
      },
    },
  }
end, { desc = 'Grep' })
vim.keymap.set({ 'n', 'x' }, '<leader>sw', function()
  Snacks.picker.grep_word {
    win = {
      input = {
        keys = {
          ['<c-t>'] = { 'filter_type', mode = { 'i', 'n' } },
        },
      },
    },
  }
end, { desc = 'Visual selection or word' })
-- search
vim.keymap.set({ 'n' }, '<leader>s"', function()
  Snacks.picker.registers()
end, { desc = 'Registers' })
vim.keymap.set({ 'n' }, '<leader>s/', function()
  Snacks.picker.search_history()
end, { desc = 'Search History' })
vim.keymap.set({ 'n' }, '<leader>sa', function()
  Snacks.picker.autocmds()
end, { desc = 'Autocmds' })
vim.keymap.set({ 'n' }, '<leader>sc', function()
  Snacks.picker.command_history()
end, { desc = 'Command History' })
vim.keymap.set({ 'n' }, '<leader>sC', function()
  Snacks.picker.commands()
end, { desc = 'Commands' })
vim.keymap.set({ 'n' }, '<leader>sd', function()
  Snacks.picker.diagnostics()
end, { desc = 'Diagnostics' })
vim.keymap.set({ 'n' }, '<leader>sD', function()
  Snacks.picker.diagnostics_buffer()
end, { desc = 'Buffer Diagnostics' })
vim.keymap.set({ 'n' }, '<leader>sh', function()
  Snacks.picker.help()
end, { desc = 'Help Pages' })
vim.keymap.set({ 'n' }, '<leader>sH', function()
  Snacks.picker.highlights()
end, { desc = 'Highlights' })
vim.keymap.set({ 'n' }, '<leader>si', function()
  Snacks.picker.icons()
end, { desc = 'Icons' })
vim.keymap.set({ 'n' }, '<leader>sj', function()
  Snacks.picker.jumps()
end, { desc = 'Jumps' })
vim.keymap.set({ 'n' }, '<leader>sk', function()
  Snacks.picker.keymaps()
end, { desc = 'Keymaps' })
vim.keymap.set({ 'n' }, '<leader>sl', function()
  Snacks.picker.loclist()
end, { desc = 'Location List' })
vim.keymap.set({ 'n' }, '<leader>sm', function()
  Snacks.picker.marks()
end, { desc = 'Marks' })
vim.keymap.set({ 'n' }, '<leader>sM', function()
  Snacks.picker.man()
end, { desc = 'Man Pages' })
vim.keymap.set({ 'n' }, '<leader>sq', function()
  Snacks.picker.qflist()
end, { desc = 'Quickfix List' })
vim.keymap.set({ 'n' }, '<leader>sR', function()
  Snacks.picker.resume()
end, { desc = 'Resume' })
vim.keymap.set({ 'n' }, '<leader>st', function()
  Snacks.picker.todo_comments()
end, { desc = 'Todo-comments' })
vim.keymap.set({ 'n' }, '<leader>su', function()
  Snacks.picker.undo()
end, { desc = 'Undo History' })
vim.keymap.set({ 'n' }, '<leader>uC', function()
  Snacks.picker.colorschemes()
end, { desc = 'Colorschemes' })
