local M = {}

--- Insert-mode mappings plus normal-mode i/I/a used to enter insert mode.
function M.setup(ctx)
  local enabled = ctx.enabled
  local get_lines = ctx.get_lines
  local set_lines = ctx.set_lines
  local row = ctx.row
  local col = ctx.col
  local fallback = ctx.fallback
  local current_opts = ctx.current_opts
  local cfg = ctx.cfg
  local notify = ctx.notify
  local detect = ctx.detect
  local edit = ctx.edit
  local node_at = ctx.node_at
  local name_start_at = ctx.name_start_at
  local char_len_at = ctx.char_len_at
  local tree_map = ctx.tree_map
  local refresh = ctx.refresh

  tree_map("i", "<Left>", function()
    if not enabled() then
      return fallback("<Left>")
    end
    local lines = get_lines()
    local r = row()
    local model = detect.detect(lines, r, current_opts())
    if not model then
      return fallback("<Left>")
    end
    local node = nil
    for _, n in ipairs(model.nodes) do
      if n.line == r then
        node = n
        break
      end
    end
    if node and node.level > 0 then
      local name_start = name_start_at(lines[r], node)
      if col() <= name_start then
        return
      end
    end
    fallback("<Left>")
  end)

  tree_map("i", "<Home>", function()
    if not enabled() then
      return fallback("<Home>")
    end
    local lines = get_lines()
    local r = row()
    local model = detect.detect(lines, r, current_opts())
    if not model then
      return fallback("<Home>")
    end
    local node = nil
    for _, n in ipairs(model.nodes) do
      if n.line == r then
        node = n
        break
      end
    end
    if node and node.level > 0 then
      local name_start = name_start_at(lines[r], node)
      vim.api.nvim_win_set_cursor(0, { r, name_start - 1 })
      return
    end
    fallback("<Home>")
  end)

  tree_map("i", "<Tab>", function()
    if not enabled() then
      return fallback("<Tab>")
    end
    local r, c = row(), col()
    local lines = get_lines()
    local model = detect.detect(lines, r, current_opts())
    if not model then
      return fallback("<Tab>")
    end
    for _, n in ipairs(model.nodes) do
      if n.line == r and n.level == 0 then
        return fallback("<Tab>")
      end
    end
    local nl = edit.shift(lines, r, 1, current_opts())
    if not nl then
      if cfg().notify_on_limit then
        notify("indent limit reached", vim.log.levels.WARN)
      end
      return
    end
    set_lines(nl)
    vim.api.nvim_win_set_cursor(0, { r, c - 1 + cfg().indent })
  end)

  tree_map("i", "<S-Tab>", function()
    if not enabled() then
      return fallback("<S-Tab>")
    end
    local r, c = row(), col()
    local lines = get_lines()
    local model = detect.detect(lines, r, current_opts())
    if not model then
      return fallback("<S-Tab>")
    end
    for _, n in ipairs(model.nodes) do
      if n.line == r and n.level == 0 then
        return fallback("<S-Tab>")
      end
    end
    local nl = edit.shift(lines, r, -1, current_opts())
    if not nl then
      if cfg().notify_on_limit then
        notify("cannot outdent (node has children)", vim.log.levels.WARN)
      end
      return
    end
    set_lines(nl)
    vim.api.nvim_win_set_cursor(0, { r, c - 1 - cfg().indent })
  end)

  tree_map("i", "<CR>", function()
    if not enabled() then
      return fallback("<CR>")
    end
    local r = row()
    local _, node = node_at(get_lines(), r)
    if not node or node.level == 0 then
      return fallback("<CR>")
    end
    local nl, new_line = edit.new_sibling(get_lines(), r, current_opts())
    if not nl then
      return fallback("<CR>")
    end
    set_lines(nl)
    vim.api.nvim_win_set_cursor(0, { new_line, #nl[new_line] })
    refresh(row(), true)
  end)

  tree_map("i", "<BS>", function()
    if not enabled() then
      return fallback("<BS>")
    end
    local r, c = row(), col()
    local nl, new_line, new_col, blocked = edit.backspace(get_lines(), r, c, current_opts())
    if blocked then
      return
    end
    if not nl then
      return fallback("<BS>")
    end
    set_lines(nl)
    vim.api.nvim_win_set_cursor(0, { new_line, new_col - 1 })
  end)

  tree_map("n", "i", function()
    if enabled() then
      local lines = get_lines()
      local r = row()
      local model = detect.detect(lines, r, current_opts())
      if model then
        for _, n in ipairs(model.nodes) do
          if n.line == r and n.level > 0 then
            local name_start = name_start_at(lines[r], n)
            vim.cmd("startinsert")
            local c = vim.api.nvim_win_get_cursor(0)
            if c[2] < name_start - 1 then
              vim.api.nvim_win_set_cursor(0, { r, name_start - 1 })
            end
            refresh(row(), true)
            return
          end
        end
      end
    end
    vim.cmd("startinsert")
  end)

  tree_map("n", "I", function()
    if enabled() then
      local lines = get_lines()
      local r = row()
      local model = detect.detect(lines, r, current_opts())
      if model then
        for _, n in ipairs(model.nodes) do
          if n.line == r and n.level > 0 then
            local name_start = name_start_at(lines[r], n)
            vim.cmd("startinsert")
            vim.api.nvim_win_set_cursor(0, { r, name_start - 1 })
            refresh(row(), true)
            return
          end
        end
      end
    end
    local lines = get_lines()
    local r = row()
    local first = lines[r]:match("^%s*") or ""
    vim.cmd("startinsert")
    vim.api.nvim_win_set_cursor(0, { r, #first })
  end)

  tree_map("n", "a", function()
    if enabled() then
      local lines = get_lines()
      local r = row()
      local model = detect.detect(lines, r, current_opts())
      if model then
        for _, n in ipairs(model.nodes) do
          if n.line == r and n.level > 0 then
            local name_start = name_start_at(lines[r], n)
            vim.cmd("startinsert")
            local c = vim.api.nvim_win_get_cursor(0)
            if c[2] < name_start - 1 then
              vim.api.nvim_win_set_cursor(0, { r, #lines[r] })
            else
              vim.api.nvim_win_set_cursor(0, { r, c[2] + char_len_at(lines[r], c[2] + 1) })
            end
            refresh(row(), true)
            return
          end
        end
      end
    end
    local lines = get_lines()
    local r = row()
    local c = vim.api.nvim_win_get_cursor(0)
    vim.cmd("startinsert")
    vim.api.nvim_win_set_cursor(0, { r, c[2] + char_len_at(lines[r], c[2] + 1) })
  end)
end

return M
