---Parse a plugin string to retrieve something close to the name
---@param plug_str string
---@return string
local plug_name_parse = function(plug_str)
  -- Reverse string so we can easily find the last forward slash
  plug_str = plug_str:reverse()
  local substring = plug_str:sub(1, string.find(plug_str, '/') - 1)

  -- Turn it back to normal
  substring = substring:reverse()

  -- Remove commas and quotation marks
  substring = substring:gsub('"', '')
  substring = substring:gsub("'", '')
  substring = substring:gsub(',', '')

  -- If ".git" in string, remove
  substring = substring:gsub('%.git', '')

  -- Return
  return substring
end

---Parse a plugin string to retrieve something close to the name
---Use the fact that we took the string with TS
---@param plug_str string
---@return string
local plug_name_parse_TS = function(plug_str)
  -- Reverse string so we can easily find the last forward slash
  plug_str = plug_str:reverse()
  local substring = plug_str:sub(1, string.find(plug_str, '/') - 1)

  -- Turn it back to normal
  substring = substring:reverse()

  -- If ".git" in string, remove
  substring = substring:gsub('%.git', '')

  -- Reverse and return
  return substring
end

---This function calls vim.pack.del on a plugin which name is contained in
---plug_str, if no string is given, it uses the line where the cursor is
---located. It does not know about comments.
---@param plug_str string?
---@return nil
local plug_delete = function(plug_str)
  if not plug_str then
    plug_str = vim.api.nvim_get_current_line()
  end

  if not pcall(vim.pack.del, { plug_name_parse(plug_str) }) then
    vim.notify(
      'Plugin not found - already deleted?',
      vim.log.levels.INFO,
      { title = 'Notify' }
    )
  end
end

---Find all plugins "added" in the file via "vim.pack.add"
---@return string[]
local find_plugins_in_file = function()
  -- Explore the buffer to find plugins

  local plugin_names = {}

  if vim.treesitter.language.add 'lua' then
    local query = vim.treesitter.query.parse(
      'lua',
      [[
   (function_call
     name: (dot_index_expression
       field: (identifier)) @fname
     arguments: (arguments
       (table_constructor [
         (field
           value: (string
             content: (string_content) @string))
         (field
           value: (table_constructor
             (field
               name: (identifier) @name
               value: (string
                 content: (string_content) @string))))]
         ))
     )
   ]]
    )
    local tree = vim.treesitter.get_parser():parse()[1]

    local in_pack_add = false
    local is_source = true
    for _, node, _ in query:iter_captures(tree:root(), 0) do
      local name =
          vim.treesitter.get_node_text(node, vim.api.nvim_get_current_buf())

      -- Only look at strings in "vim.pack.add"
      if node:type() == 'dot_index_expression' then
        in_pack_add = name == 'vim.pack.add'
      end

      -- If in "vim.pack.add"
      if in_pack_add then
        -- If we have an identifier, we are capturing an inner table, and we
        -- only want the string that accompanies "src"
        if node:type() == 'identifier' then
          is_source = name == 'src'
        end

        -- We need to reset the "is_source" flag each time we find a string, so
        -- it is ready for the next one
        if node:type() == 'string_content' then
          if is_source then
            table.insert(plugin_names, plug_name_parse_TS(name))
          else
            is_source = true
          end
        end
      end
    end
  else
    local in_pack_add = false
    local match = { left = nil, right = nil, index = 0 }
    for _, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, true)) do
      if line:find 'vim.pack.add' then
        if line:find 'vim.pack.add%s*%(' then
          match.left = '%('
          match.right = '%)'
        elseif line:find 'vim.pack.add%s*%{' then
          match.left = '%{'
          match.right = '%}'
        else
          error 'vim.pack.add not found, doing nothing'
        end

        match.index = 1
        in_pack_add = true
        goto continue
      end

      if in_pack_add then
        if line:find(match.left) then
          match.index = match.index + 1
        elseif line:find(match.right) then
          match.index = match.index - 1
        elseif line:find '[%a%p]+/[%a%p]+' then
          table.insert(plugin_names, plug_name_parse(line))
        end

        if match.index == 0 then
          in_pack_add = false
        end
      end
      ::continue::
    end
  end

  return plugin_names
end

---This function attempts to sync plugins loaded with plugins in vim.pack.add,
---assuming that all plugins are added in a single file, which is the current
---buffer. If a plugin is loaded but not in vim.pack.add, it will delete it.
---@return nil
local plug_sync = function()
  -- Make sure "vim.pack.add" is in the file
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
  if not vim.tbl_contains(lines, 'vim.pack.add {') then
    vim.notify("Wrong file, run where 'vim.pack.add' is located", vim.log.levels.INFO)
    return
  end

  -- Get the plugin table
  local loaded_plugins = vim.pack.get()

  -- Find all plugins in file
  local plugins_in_file = find_plugins_in_file()

  -- For every plugin in  loaded_plugins, check if it is in plugins_in_file
  -- if not, remove it
  for _, plugin_table in ipairs(loaded_plugins) do
    local found = false
    for _, plugin in ipairs(plugins_in_file) do
      if plugin_table.spec.name == plugin then
        found = true
        break
      end
    end

    if not found then
      vim.pack.del { plugin_table.spec.name }
    end
  end
end

-- Keymap to delete plugin under the cursor
vim.keymap.set(
  'n',
  '<leader>pd',
  plug_delete,
  { desc = 'Delete plugin under cursor' }
)

-- Keymap to update plugins
vim.keymap.set('n', '<leader>pu', vim.pack.update, { desc = 'Update plugins' })

-- Keymap to sync plugins
vim.keymap.set('n', '<leader>ps', function()
  plug_sync()
end, { desc = 'Sync plugins' })
