---------------------------------------------------------------------------------
-- Vim Settings
---------------------------------------------------------------------------------
vim.o.smarttab     = true
vim.o.smartindent  = true
vim.o.expandtab    = true
vim.o.linebreak    = true
vim.o.tabstop      = 2
vim.o.softtabstop  = 2
vim.o.shiftwidth   = 2
vim.o.mouse        = 'r'
vim.o.colorcolumn  = '81'
vim.o.cursorline   = true
vim.o.cursorcolumn = true
vim.o.hlsearch     = true
vim.o.incsearch    = true

---------------------------------------------------------------------------------
-- Remember last cursor position
---------------------------------------------------------------------------------
local lastplace = vim.api.nvim_create_augroup("LastPlace", {})
vim.api.nvim_clear_autocmds({ group = lastplace })
vim.api.nvim_create_autocmd("BufReadPost", {
    group = lastplace,
    pattern = { "*" },
    desc = "remember last cursor place",
    callback = function()
        local mark = vim.api.nvim_buf_get_mark(0, '"')
        local lcount = vim.api.nvim_buf_line_count(0)
        if mark[1] > 0 and mark[1] <= lcount then
            pcall(vim.api.nvim_win_set_cursor, 0, mark)
        end
    end,
})
