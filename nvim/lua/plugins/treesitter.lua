require('treesitter-context').setup {
  enable = false, -- Start with context disabled
  separator = '=',
  max_lines = '30%',
}

local parsers = {
  'bash',
  'c',
  'comment',
  'cpp',
  'css',
  'diff',
  'fish',
  'fortran',
  'html',
  'javascript',
  'jsdoc',
  'json',
  'latex',
  'lua',
  'luadoc',
  'luap',
  'markdown',
  'markdown_inline',
  -- 'norg', -- NOTE: norg is not supported by nvim-treesitter yet
  'printf',
  'python',
  'query',
  'regex',
  'scss',
  'svelte',
  'toml',
  'tsx',
  'typescript',
  'typst',
  'vim',
  'vimdoc',
  'vue',
  'xml',
  'yaml',
}
require('nvim-treesitter').install(parsers)

-- Start the parser in all the above filetypes
vim.api.nvim_create_autocmd({ 'FileType' }, {
  pattern = parsers,
  callback = function()
    -- Start treesitter for highlighting and folds
    vim.treesitter.start()
    vim.opt.foldmethod = 'expr'
    vim.opt.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
  end,
})

require('nvim-treesitter-textobjects').setup {
  select = {
    -- Automatically jump forward to textobj, similar to targets.vim
    lookahead = true,
    -- You can choose the select mode (default is charwise 'v')
    --
    -- Can also be a function which gets passed a table with the keys
    -- * query_string: eg '@function.inner'
    -- * method: eg 'v' or 'o'
    -- and should return the mode ('v', 'V', or '<c-v>') or a table
    -- mapping query_strings to modes.
    selection_modes = {
      ['@parameter.outer'] = 'v', -- charwise
      ['@function.outer'] = 'V',  -- linewise
    },
    -- If you set this to `true` (default is `false`) then any textobject is
    -- extended to include preceding or succeeding whitespace. Succeeding
    -- whitespace has priority in order to act similarly to eg the built-in
    -- `ap`.
    --
    -- Can also be a function which gets passed a table with the keys
    -- * query_string: eg '@function.inner'
    -- * selection_mode: eg 'v'
    -- and should return true of false
    include_surrounding_whitespace = false,
  },
  move = {
    -- whether to set jumps in the jumplist
    set_jumps = true,
  },
}

-- keymaps
-- Swap
vim.keymap.set('n', '<leader>cs', function()
  require('nvim-treesitter-textobjects.swap').swap_next '@parameter.inner'
end, { desc = 'Swap next' })
vim.keymap.set('n', '<leader>cS', function()
  require('nvim-treesitter-textobjects.swap').swap_previous '@parameter.inner'
end, { desc = 'Swap previous' })

-- Function and classes selections
vim.keymap.set({ 'x', 'o' }, 'af', function()
  require('nvim-treesitter-textobjects.select').select_textobject(
    '@function.outer',
    'textobjects'
  )
end, { desc = 'Around function' })
vim.keymap.set({ 'x', 'o' }, 'if', function()
  require('nvim-treesitter-textobjects.select').select_textobject(
    '@function.inner',
    'textobjects'
  )
end, { desc = 'Inside function' })
vim.keymap.set({ 'x', 'o' }, 'ac', function()
  require('nvim-treesitter-textobjects.select').select_textobject(
    '@class.outer',
    'textobjects'
  )
end, { desc = 'Around class' })
vim.keymap.set({ 'x', 'o' }, 'ic', function()
  require('nvim-treesitter-textobjects.select').select_textobject(
    '@class.inner',
    'textobjects'
  )
end, { desc = 'Inside class' })

-- Block selections
vim.keymap.set({ 'x', 'o' }, 'al', function()
  require('nvim-treesitter-textobjects.select').select_textobject(
    '@block.outer',
    'textobjects'
  )
end, { desc = 'Around block' })
vim.keymap.set({ 'x', 'o' }, 'il', function()
  require('nvim-treesitter-textobjects.select').select_textobject(
    '@block.inner',
    'textobjects'
  )
end, { desc = 'Inside block' })

-- Moves
-- Functions
vim.keymap.set({ 'n', 'x', 'o' }, ']f', function()
  require('nvim-treesitter-textobjects.move').goto_next_start(
    '@function.outer',
    'textobjects'
  )
end, { desc = 'Next function start' })
vim.keymap.set({ 'n', 'x', 'o' }, ']F', function()
  require('nvim-treesitter-textobjects.move').goto_next_end(
    '@function.outer',
    'textobjects'
  )
end, { desc = 'Next function end' })
vim.keymap.set({ 'n', 'x', 'o' }, '[f', function()
  require('nvim-treesitter-textobjects.move').goto_previous_start(
    '@function.outer',
    'textobjects'
  )
end, { desc = 'Previous function start' })
vim.keymap.set({ 'n', 'x', 'o' }, '[F', function()
  require('nvim-treesitter-textobjects.move').goto_previous_end(
    '@function.outer',
    'textobjects'
  )
end, { desc = 'Previous function end' })

-- Classes
vim.keymap.set({ 'n', 'x', 'o' }, ']]', function()
  require('nvim-treesitter-textobjects.move').goto_next_start(
    '@class.outer',
    'textobjects'
  )
end, { desc = 'Next class start' })
vim.keymap.set({ 'n', 'x', 'o' }, '][', function()
  require('nvim-treesitter-textobjects.move').goto_next_end(
    '@class.outer',
    'textobjects'
  )
end, { desc = 'Next class end' })
vim.keymap.set({ 'n', 'x', 'o' }, '[]', function()
  require('nvim-treesitter-textobjects.move').goto_previous_start(
    '@class.outer',
    'textobjects'
  )
end, { desc = 'Previous class start' })
vim.keymap.set({ 'n', 'x', 'o' }, '[[', function()
  require('nvim-treesitter-textobjects.move').goto_previous_end(
    '@class.outer',
    'textobjects'
  )
end, { desc = 'Previous class end' })

-- Blocks
vim.keymap.set({ 'n', 'x', 'o' }, ']l', function()
  require('nvim-treesitter-textobjects.move').goto_next_start(
    '@block.outer',
    'textobjects'
  )
end, { desc = 'Next block start' })
vim.keymap.set({ 'n', 'x', 'o' }, ']L', function()
  require('nvim-treesitter-textobjects.move').goto_next_end(
    '@block.outer',
    'textobjects'
  )
end, { desc = 'Next block end' })
vim.keymap.set({ 'n', 'x', 'o' }, '[l', function()
  require('nvim-treesitter-textobjects.move').goto_previous_start(
    '@block.outer',
    'textobjects'
  )
end, { desc = 'Previous block start' })
vim.keymap.set({ 'n', 'x', 'o' }, '[L', function()
  require('nvim-treesitter-textobjects.move').goto_previous_end(
    '@block.outer',
    'textobjects'
  )
end, { desc = 'Previous block end' })

-- Loops
-- You can also pass a list to group multiple queries.
vim.keymap.set({ 'n', 'x', 'o' }, ']o', function()
  require('nvim-treesitter-textobjects.move').goto_next_start(
    { '@loop.inner', '@loop.outer' },
    'textobjects'
  )
end, { desc = 'Next loop start' })
vim.keymap.set({ 'n', 'x', 'o' }, ']O', function()
  require('nvim-treesitter-textobjects.move').goto_next_end(
    { '@loop.inner', '@loop.outer' },
    'textobjects'
  )
end, { desc = 'Next loop end' })
vim.keymap.set({ 'n', 'x', 'o' }, '[o', function()
  require('nvim-treesitter-textobjects.move').goto_previous_start(
    { '@loop.inner', '@loop.outer' },
    'textobjects'
  )
end, { desc = 'Previous loop start' })
vim.keymap.set({ 'n', 'x', 'o' }, '[O', function()
  require('nvim-treesitter-textobjects.move').goto_previous_end(
    { '@loop.inner', '@loop.outer' },
    'textobjects'
  )
end, { desc = 'Previous loop end' })

-- Conditionals
-- You can also pass a list to group multiple queries.
vim.keymap.set({ 'n', 'x', 'o' }, ']c', function()
  require('nvim-treesitter-textobjects.move').goto_next_start(
    { '@conditional.inner', '@conditional.outer' },
    'textobjects'
  )
end, { desc = 'Next conditional start' })
vim.keymap.set({ 'n', 'x', 'o' }, ']C', function()
  require('nvim-treesitter-textobjects.move').goto_next_end(
    { '@conditional.inner', '@conditional.outer' },
    'textobjects'
  )
end, { desc = 'Next conditional end' })
vim.keymap.set({ 'n', 'x', 'o' }, '[c', function()
  require('nvim-treesitter-textobjects.move').goto_previous_start(
    { '@conditional.inner', '@conditional.outer' },
    'textobjects'
  )
end, { desc = 'Previous conditional start' })
vim.keymap.set({ 'n', 'x', 'o' }, '[C', function()
  require('nvim-treesitter-textobjects.move').goto_previous_end(
    { '@conditional.inner', '@conditional.outer' },
    'textobjects'
  )
end, { desc = 'Previous conditional end' })

-- Folds
-- You can also use captures from other query groups like `locals.scm` or `folds.scm`
vim.keymap.set({ 'n', 'x', 'o' }, ']z', function()
  require('nvim-treesitter-textobjects.move').goto_next_start('@fold', 'folds')
end, { desc = 'Next fold start' })
vim.keymap.set({ 'n', 'x', 'o' }, ']Z', function()
  require('nvim-treesitter-textobjects.move').goto_next_end('@fold', 'folds')
end, { desc = 'Next fold end' })
vim.keymap.set({ 'n', 'x', 'o' }, '[z', function()
  require('nvim-treesitter-textobjects.move').goto_previous_start(
    '@fold',
    'folds'
  )
end, { desc = 'Next fold start' })
vim.keymap.set({ 'n', 'x', 'o' }, '[Z', function()
  require('nvim-treesitter-textobjects.move').goto_previous_end(
    '@fold',
    'folds'
  )
end, { desc = 'Next fold end' })

local ts_repeat_move = require 'nvim-treesitter-textobjects.repeatable_move'

-- Repeat movement with ; and ,
-- vim way: ; goes to the direction you were moving.
-- NOTE: using ñ and Ñ respectively to avoid conflicts with flash
vim.keymap.set({ 'n', 'x', 'o' }, 'ñ', ts_repeat_move.repeat_last_move)
vim.keymap.set(
  { 'n', 'x', 'o' },
  'Ñ',
  ts_repeat_move.repeat_last_move_opposite
)

-- Treesitter context keymaps
-- Jump to previous context
vim.keymap.set('n', '[u', function()
  require('treesitter-context').go_to_context(vim.v.count1)
end, { silent = true, desc = 'Jump to top of context' })
