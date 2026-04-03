local colors = {
  blue = "#65D1FF",
  green = "#3EFFDC",
  violet = "#FF61EF",
  yellow = "#FFDA7B",
  red = "#FF4A4A",
  fg = "#c3ccdc",
  bg = "#112638",
  inactive_bg = "#2c3043",
}

local my_lualine_theme = {
  normal = {
    a = { bg = colors.blue, fg = colors.bg, gui = "bold" },
    b = { bg = colors.bg, fg = colors.fg },
    c = { bg = colors.bg, fg = colors.fg },
  },
  insert = {
    a = { bg = colors.green, fg = colors.bg, gui = "bold" },
    b = { bg = colors.bg, fg = colors.fg },
    c = { bg = colors.bg, fg = colors.fg },
  },
  visual = {
    a = { bg = colors.violet, fg = colors.bg, gui = "bold" },
    b = { bg = colors.bg, fg = colors.fg },
    c = { bg = colors.bg, fg = colors.fg },
  },
  command = {
    a = { bg = colors.yellow, fg = colors.bg, gui = "bold" },
    b = { bg = colors.bg, fg = colors.fg },
    c = { bg = colors.bg, fg = colors.fg },
  },
  replace = {
    a = { bg = colors.red, fg = colors.bg, gui = "bold" },
    b = { bg = colors.bg, fg = colors.fg },
    c = { bg = colors.bg, fg = colors.fg },
  },
  inactive = {
    a = { bg = colors.inactive_bg, fg = colors.semilightgray, gui = "bold" },
    b = { bg = colors.inactive_bg, fg = colors.semilightgray },
    c = { bg = colors.inactive_bg, fg = colors.semilightgray },
  },
}

require('lualine').setup {
  options = {
    icons_enabled = true,
    theme = my_lualine_theme,
    section_separators = { left = '', right = '' },
    component_separators = { left = '', right = '' },
    disabled_filetypes = {
      statusline = {},
      winbar = {},
    },
    ignore_focus = {},
    always_divide_middle = true,
    always_show_tabline = true,
    globalstatus = true,
    refresh = {
      statusline = 1000,
      tabline = 1000,
      winbar = 1000,
      refresh_time = 16, -- ~60fps
      events = {
        'WinEnter',
        'BufEnter',
        'BufWritePost',
        'SessionLoadPost',
        'FileChangedShellPost',
        'VimResized',
        'Filetype',
        'CursorMoved',
        'CursorMovedI',
        'ModeChanged',
      },
    },
  },
  sections = {
    lualine_a = {
      {
        -- Add X mode to "mode",
        function()
          -- Dictionary with modes
          local mode_names = {
            n = 'NORMAL',
            no = 'O-PENDING',
            nov = 'O-PENDING',
            noV = 'O-PENDING',
            niI = 'I-NORMAL',
            niR = 'R-NORMAL',
            niV = 'V-NORMAL',
            nt = 'NORMAL',
            ntT = 'I-NORMAL',
            v = 'VISUAL',
            vs = 'S-VISUAL',
            V = 'VISUAL',
            Vs = 'S-VISUAL',
            s = 'SELECT',
            S = 'SELECT',
            i = 'INSERT',
            ic = 'I-COMPLETION',
            ix = 'X-MODE',
            R = 'REPLACE',
            Rc = 'R-COMPLETION',
            Rx = 'X-MODE',
            Rv = 'VIRT-REPLACE',
            Rvc = 'VR-COMPLETION',
            Rvx = 'X-MODE',
            c = 'COMMAND',
            cr = 'OVERSTRIKE',
            cv = 'EX',
            cvr = 'EX-OVERSTRIKE',
            r = 'PROMPT',
            rm = 'MORE',
            t = 'TERMINAL',
          }
          -- Add the modes that have special characters
          mode_names['noCTRL-V'] = 'O-PENDING'
          mode_names['CTRL-V'] = 'VISUAL'
          mode_names['CTRL-Vs'] = 'VISUAL'
          mode_names['CTRL-S'] = 'SELECT'
          mode_names['r?'] = 'CONFIRM'
          mode_names['!'] = 'EXTERNAL'
          mode_names['\22'] = 'V-BLOCK'

          -- Retrieve and return mode
          return mode_names[vim.api.nvim_get_mode().mode]
        end,
      },
    },
    lualine_b = {
      'windows',
      { 'lsp_status', icon = '' },
      'diagnostics',
    },
    lualine_c = {
      'branch',
      'diff',
      'searchcount',
      {
        -- Recorder
        function()
          return require('recorder').displaySlots()
            .. require('recorder').recordingStatus()
        end,
      },
      -- NOTE: Uncomment if we want to see "@recording"
      -- {
      --   require('noice').api.status.mode.get,
      --   cond = require('noice').api.status.mode.has,
      --   color = { fg = '#ff9e64' },
      -- },
    },
    lualine_x = {
      '%S', -- This can be used because vim.o.showcmdloc = 'statusline' is in the opts
      'encoding',
      'fileformat',
      'filetype',
    },
    lualine_y = { 'selectioncount', 'progress', 'location' },
    lualine_z = { { 'datetime', style = '%a %d-%m-%y %H:%M' } },
  },
  inactive_sections = {},
  tabline = {},
  winbar = {},
  inactive_winbar = {},
  extensions = {
    'fugitive',
    'oil',
    'quickfix',
    'mason',
  },
}
