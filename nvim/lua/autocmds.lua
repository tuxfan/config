-- Custom functions

-- Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.hl.on_yank()`
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('highlight-yank', { clear = true }),
  callback = function()
    vim.hl.on_yank()
  end,
})

-- fugitive keybinds with autocmd
local fugitive_group = vim.api.nvim_create_augroup('fugitive-commands', {
  clear = true,
})
vim.api.nvim_create_autocmd('BufEnter', {
  group = fugitive_group,
  callback = function(event)
    local match_str = 'fugitive:///'
    if event.file:sub(1, match_str:len()) == match_str then
      vim.keymap.set('n', 'gh', function()
        return '<cmd>diffget //2<CR>'
      end, { expr = true, desc = 'Get diff from left merge window' })
      vim.keymap.set('n', 'gl', function()
        return '<cmd>diffget //3<CR>'
      end, { expr = true, desc = 'Get diff from right merge window' })
      vim.keymap.set('n', 'gq', function()
        local cmd = ''
        for _, b in ipairs(vim.api.nvim_list_bufs()) do
          if string.find(vim.api.nvim_buf_get_name(b), 'fugitive://') then
            cmd = cmd .. '<cmd>bwipeout ' .. b .. '<CR>'
          end
        end

        return cmd
      end, { expr = true, desc = 'Close the diff windows' })
    end
  end,
  desc = 'Create the fugitive diffsplit keymaps',
})
vim.api.nvim_create_autocmd('BufWinLeave', {
  group = fugitive_group,
  callback = function(event)
    local match_str = 'fugitive:///'
    if event.file:sub(1, match_str:len()) == match_str then
      vim.keymap.del('n', 'gh')
      vim.keymap.del('n', 'gl')
      vim.keymap.del('n', 'gq')
    end
  end,
  desc = 'Clear the fugitive diffsplit keymaps',
})

-- Restore diffmode keymap for dp
vim.api.nvim_create_autocmd('DiffUpdated', {
  group = vim.api.nvim_create_augroup('diff-commands', {
    clear = true,
  }),
  callback = function()
    if vim.o.diff then
      _ = pcall(vim.keymap.del, 'o', 'p')
    else
      vim.keymap.set('o', 'p', '}', { desc = 'Next empty line' })
    end
  end,
  desc = 'Clear or add p as operator mode',
})

-- Loadview for this file if it exists
local loadview_g = vim.api.nvim_create_augroup('Loadview', { clear = true })
vim.api.nvim_create_autocmd('BufWinEnter', {
  group = loadview_g,
  pattern = '?*',
  command = 'silent! loadview',
  desc = 'Load this buffer view if it exists',
})
vim.api.nvim_create_autocmd({ 'BufUnload', 'BufWinLeave' }, {
  group = loadview_g,
  pattern = '?*',
  command = 'mkview',
  desc = 'Save this buffer view',
})

-- Change relativenumber when changing modes
-- Do nothing if user sets off any of the number options
local relative_change = vim.o.number and vim.o.relativenumber
local change_relnum_g =
  vim.api.nvim_create_augroup('Change relnum', { clear = true })

vim.api.nvim_create_autocmd('OptionSet', {
  group = change_relnum_g,
  pattern = { 'number', 'relativenumber' },
  callback = function(event)
    if event.file ~= '' then
      relative_change = vim.o.number and vim.o.relativenumber
    end
  end,
  desc = 'Track whether relative_change should be set',
})
vim.api.nvim_create_autocmd('ModeChanged', {
  group = change_relnum_g,
  pattern = '*:i',
  callback = function()
    if relative_change and Change_relnum then
      vim.o.relativenumber = false
    end
  end,
  desc = 'Change from relativenumber to absolute numbers',
})
vim.api.nvim_create_autocmd('ModeChanged', {
  group = change_relnum_g,
  pattern = 'i:n',
  callback = function()
    if relative_change and Change_relnum then
      vim.o.relativenumber = true
    end
  end,
  desc = 'Change from absolute numbers to relativenumber',
})
