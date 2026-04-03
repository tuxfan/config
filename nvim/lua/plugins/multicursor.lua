local mc = require 'multicursor-nvim'

mc.setup()

-- Add or skip cursor above/below the main cursor.
vim.keymap.set({ 'n', 'x' }, '<M-k>', function()
  mc.lineAddCursor(-1)
end, { desc = 'Add cursor above' })
vim.keymap.set({ 'n', 'x' }, '<M-j>', function()
  mc.lineAddCursor(1)
end, { desc = 'Add cursor below' })
vim.keymap.set({ 'n', 'x' }, '<C-M-k>', function()
  mc.lineSkipCursor(-1)
end, { desc = 'Skip cursor above' })
vim.keymap.set({ 'n', 'x' }, '<C-M-j>', function()
  mc.lineSkipCursor(1)
end, { desc = 'Skip cursor below' })

-- Add or skip adding a new cursor by matching word/selection
vim.keymap.set({ 'n', 'x' }, '<M-n>', function()
  mc.matchAddCursor(1)
end, { desc = 'Add cursor to next match' })
vim.keymap.set({ 'n', 'x' }, '<M-p>', function()
  mc.matchAddCursor(-1)
end, { desc = 'Add cursor to previous match' })
vim.keymap.set({ 'n', 'x' }, '<M-s>', function()
  mc.matchSkipCursor(1)
end, { desc = 'Skip cursor to next match' })
vim.keymap.set({ 'n', 'x' }, '<M-f>', function()
  mc.matchSkipCursor(-1)
end, { desc = 'Skip cursor to previous match' })

-- Split cursors
vim.keymap.set('v', '<M-s>', mc.splitCursors, { desc = 'Split cursors' })

-- Match cursors
vim.keymap.set('v', '<M-m>', mc.matchCursors, { desc = 'Match cursors' })

-- Disable and enable cursors.
vim.keymap.set(
  { 'n', 'x' },
  '<M-q>',
  mc.toggleCursor,
  { desc = 'Toggle cursors' }
)

-- Mappings defined in a keymap layer only apply when there are
-- multiple cursors. This lets you have overlapping mappings.
mc.addKeymapLayer(function(layerSet)
  -- Select a different cursor as the main one.
  layerSet('n', '<M-l>', mc.nextCursor, { desc = 'Next cursor' })
  layerSet('n', '<M-h>', mc.prevCursor, { desc = 'Previous cursor' })

  -- Swap cursors
  layerSet('x', '<M-h>', function()
    mc.swapCursors(-1)
  end, { desc = 'Swap with next cursor' })
  layerSet('x', '<M-l>', function()
    mc.swapCursors(1)
  end, { desc = 'Swap with previous cursor' })

  -- Align cursors
  layerSet('n', '<M-a>', mc.alignCursors, { desc = 'Align cursors' })

  -- Delete the main cursor.
  layerSet('n', '<M-d>', mc.deleteCursor, { desc = 'Delete cursor' })

  -- Enable and clear cursors using escape.
  layerSet('n', '<esc>', function()
    if not mc.cursorsEnabled() then
      mc.enableCursors()
    else
      mc.clearCursors()
    end
  end, { desc = 'Clear cursors' })
end)

-- Customize how cursors look.
local hl = vim.api.nvim_set_hl
hl(0, 'MultiCursorCursor', { reverse = true })
hl(0, 'MultiCursorVisual', { link = 'Visual' })
hl(0, 'MultiCursorSign', { link = 'SignColumn' })
hl(0, 'MultiCursorMatchPreview', { link = 'Search' })
hl(0, 'MultiCursorDisabledCursor', { link = 'Substitute' })
hl(0, 'MultiCursorDisabledVisual', { link = 'Visual' })
hl(0, 'MultiCursorDisabledSign', { link = 'SignColumn' })
