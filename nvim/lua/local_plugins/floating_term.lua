-- Save the buffer and window information
local state = {}

---Close or open the floating terminal, handle the buffer creation
---@param relsize number Relative window size
local toggle_floating_terminal = function(relsize)
  -- Reset state
  if not state.bufnr or not vim.api.nvim_buf_is_loaded(state.bufnr) then
    state.is_open = false
    state.bufnr = -1
  end

  -- If the window is open, close it
  if vim.api.nvim_win_is_valid(state.win_id or -1) then
    vim.api.nvim_win_close(state.win_id, true)
  else
    -- Create a new buffer if we don't have one already
    if state.bufnr == -1 or not vim.api.nvim_buf_is_loaded(state.bufnr) then
      local bufnr = vim.api.nvim_create_buf(false, true)
      state.bufnr = bufnr
    end

    -- Open new window
    state.win_id = vim.api.nvim_open_win(state.bufnr, true, {
      relative = 'editor',

      -- Center window and give it the desired relative size to the editor
      row = math.floor(vim.o.lines * (1 - relsize) * 0.5),
      col = math.floor(vim.o.columns * (1 - relsize) * 0.5),
      height = math.floor(vim.o.lines * relsize),
      width = math.floor(vim.o.columns * relsize),
      border = 'rounded',
      style = 'minimal',
    })

    -- Open terminal if it was not there before
    if vim.bo.buftype ~= 'terminal' then
      vim.cmd.terminal()
    end
    vim.cmd.startinsert()
  end
end

-- Relative size of the terminal
-- to the editor window
local relsize = 0.8

-- Floating terminal
vim.keymap.set('n', '<C-Space>', function()
  toggle_floating_terminal(relsize)

  -- Create autocmd to close the window when leaving it
  -- Doing it inside of the keymap so we can retrieve state.bufnr
  -- so the autocmd only listens to the floating terminal
  vim.api.nvim_create_autocmd({ 'WinLeave' }, {
    group = vim.api.nvim_create_augroup('FloatingTerm', { clear = true }),
    buffer = state.bufnr,
    callback = function()
      toggle_floating_terminal(relsize)
    end,
    desc = 'Close floating terminal when leaving the window',
  })
end, { desc = 'Toggle floating terminal (cwd)' })

-- Allow also the ergonomic one
vim.keymap.set('n', '<Space>tt', function()
  toggle_floating_terminal(relsize)

  -- Create autocmd to close the window when leaving it
  -- Doing it inside of the keymap so we can retrieve state.bufnr
  -- so the autocmd only listens to the floating terminal
  vim.api.nvim_create_autocmd({ 'WinLeave' }, {
    group = vim.api.nvim_create_augroup('FloatingTerm', { clear = true }),
    buffer = state.bufnr,
    callback = function()
      toggle_floating_terminal(relsize)
    end,
    desc = 'Close floating terminal when leaving the window',
  })
end, { desc = 'Toggle floating terminal (cwd)' })

vim.keymap.set('t', '<C-Space>', function()
  toggle_floating_terminal(relsize)
end, { desc = 'Toggle floating terminal (cwd)' })
