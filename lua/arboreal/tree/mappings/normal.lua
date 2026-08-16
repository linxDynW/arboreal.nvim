local M = {}

--- Normal-mode tree guards and local helpers.
function M.setup(ctx)
  local enabled = ctx.enabled
  local get_lines = ctx.get_lines
  local set_lines = ctx.set_lines
  local row = ctx.row
  local fallback = ctx.fallback
  local notify = ctx.notify
  local notify_blocked = ctx.notify_blocked
  local current_opts = ctx.current_opts
  local cfg = ctx.cfg
  local detect = ctx.detect
  local edit = ctx.edit
  local node_at = ctx.node_at
  local name_start_at = ctx.name_start_at
  local on_connector_area = ctx.on_connector_area
  local indent_lines = ctx.indent_lines
  local shift_line = ctx.shift_line
  local tree_map = ctx.tree_map
  local refresh = ctx.refresh

  local function open_blank_lines(at, count)
    local lines = get_lines()
    for _ = 1, count do
      table.insert(lines, at, "")
    end
    set_lines(lines)
    vim.cmd("startinsert")
    vim.api.nvim_win_set_cursor(0, { at, 0 })
  end

  tree_map("n", "o", function()
    local count = math.max(vim.v.count1, 1)
    if not enabled() then
      return open_blank_lines(row() + 1, count)
    end
    local lines = get_lines()
    local r = row()
    local model = detect.detect(lines, r, current_opts())
    local is_last_node = false
    local cur_node = nil
    if model then
      for _, n in ipairs(model.nodes) do
        if n.line == r then
          cur_node = n
        end
      end
      is_last_node = model.nodes[#model.nodes].line == r and cur_node ~= nil
    end
    local is_buffer_end = r == #lines
    if not model or cur_node == nil or cur_node.level == 0 or (is_last_node and is_buffer_end) then
      return open_blank_lines(r + 1, count)
    end
    local cur = lines
    local new_line = r
    for _ = 1, count do
      local nl, created = edit.new_sibling(cur, new_line, current_opts())
      if not nl then
        break
      end
      cur = nl
      new_line = created
    end
    set_lines(cur)
    vim.cmd("startinsert")
    vim.api.nvim_win_set_cursor(0, { new_line, #cur[new_line] })
    refresh(row(), true)
  end)

  tree_map("n", "O", function()
    local count = math.max(vim.v.count1, 1)
    if not enabled() then
      return open_blank_lines(row(), count)
    end
    local lines = get_lines()
    local r = row()
    local cur = lines
    local new_line = r
    for _ = 1, count do
      local nl, created = edit.new_sibling_before(cur, new_line, current_opts())
      if not nl then
        return open_blank_lines(r, count)
      end
      cur = nl
      new_line = created
    end
    set_lines(cur)
    vim.cmd("startinsert")
    vim.api.nvim_win_set_cursor(0, { new_line, #cur[new_line] })
    refresh(row(), true)
  end)

  tree_map("n", "dd", function()
    local count = math.max(vim.v.count1, 1)
    if not enabled() then
      vim.api.nvim_feedkeys(
        vim.api.nvim_replace_termcodes(count .. "dd", true, false, true),
        "in",
        false
      )
      return
    end
    local r = row()
    local lines = get_lines()
    local _, node = node_at(lines, r)
    if node == nil or node.level == 0 then
      vim.api.nvim_feedkeys(
        vim.api.nvim_replace_termcodes(count .. "dd", true, false, true),
        "in",
        false
      )
      return
    end
    local to_line = math.min(r + count - 1, #lines)
    local nl, merged = edit.delete_lines(lines, r, to_line, current_opts())
    if not nl then
      notify("could not delete the selection as a tree", vim.log.levels.WARN)
      return
    end
    if merged and cfg().confirm_directory_delete then
      local choice = vim.fn.confirm(
        "Delete directory node? Its children will be merged into the parent (undo with u)",
        "&Yes\n&No",
        1
      )
      if choice ~= 1 then
        return
      end
    end
    set_lines(nl)
    if merged then
      notify("directory deleted, children merged into parent (u to undo)", vim.log.levels.WARN)
    end
    vim.api.nvim_win_set_cursor(0, { math.min(r, #nl), 0 })
  end)

  -- Whether the cursor is in a tree line's connector area (name/root/non-tree returns false).

  tree_map("n", "x", function()
    if not enabled() then
      return fallback("x")
    end
    if on_connector_area(get_lines(), row()) then
      notify_blocked("x", "x is blocked on the connector area\n(use :Arb off to edit raw text)")
      return
    end
    fallback("x")
  end)

  tree_map("n", "r", function()
    if not enabled() then
      return fallback("r")
    end
    if on_connector_area(get_lines(), row()) then
      notify_blocked("r", "r is blocked on the connector area\n(use :Arb off to edit raw text)")
      vim.cmd("redraw")
      vim.fn.getcharstr()
      return
    end
    fallback("r")
  end)

  tree_map("n", "s", function()
    if not enabled() then
      return fallback("s")
    end
    local lines = get_lines()
    local r = row()
    if on_connector_area(lines, r) then
      notify_blocked("s", "s is blocked on the connector area\n(use :Arb off to edit raw text)")
      return
    end
    local _, node = node_at(lines, r)
    if not node or node.level == 0 then
      return fallback("s")
    end
    if node.name == "" then
      vim.cmd("startinsert")
      return
    end
    -- Non-empty names delegate to native s so deleting the char under the cursor and typing share one undo block.
    return fallback("s")
  end)

  tree_map("n", ">>", function()
    if not enabled() then
      local count = math.max(vim.v.count1, 1)
      local r = row()
      local lines = get_lines()
      set_lines(indent_lines(lines, r, math.min(r + count - 1, #lines), 1))
      return
    end
    shift_line(1)
  end)

  tree_map("n", "<<", function()
    if not enabled() then
      local count = math.max(vim.v.count1, 1)
      local r = row()
      local lines = get_lines()
      set_lines(indent_lines(lines, r, math.min(r + count - 1, #lines), -1))
      return
    end
    shift_line(-1)
  end)

  tree_map("n", "cc", function()
    if enabled() then
      local lines = get_lines()
      local r = row()
      local model = detect.detect(lines, r, current_opts())
      if model then
        for _, n in ipairs(model.nodes) do
          if n.line == r and n.level > 0 then
            local name_start = name_start_at(lines[r], n)
            vim.api.nvim_win_set_cursor(0, { r, name_start - 1 })
            -- Native C deletes to end-of-line and enters insert mode: the
            -- connector stays intact, and deletion plus typed text form one
            -- undo block (one u restores the original name).
            vim.api.nvim_feedkeys(
              vim.api.nvim_replace_termcodes("C", true, false, true),
              "in",
              false
            )
            return
          end
        end
      end
    end
    -- Root/plain lines: delegate to native cc so behavior and undo match plain text.
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("cc", true, false, true), "in", false)
  end)

  tree_map("n", "c", function()
    vim.o.operatorfunc = "v:lua.require'arboreal.tree'.op_change"
    return "g@"
  end, { expr = true })

  local function delete_to_eol()
    local lines = get_lines()
    local r = row()
    local c = vim.api.nvim_win_get_cursor(0)
    lines[r] = lines[r]:sub(1, c[2])
    set_lines(lines)
  end

  tree_map("n", "C", function()
    if enabled() and on_connector_area(get_lines(), row()) then
      notify_blocked("C", "C is blocked on the connector area\n(use :Arb off to edit raw text)")
      return
    end
    local lines = get_lines()
    local r = row()
    local c = vim.api.nvim_win_get_cursor(0)
    lines[r] = lines[r]:sub(1, c[2])
    set_lines(lines)
    vim.cmd("startinsert")
    vim.api.nvim_win_set_cursor(0, { r, math.min(c[2], #lines[r]) })
  end)

  tree_map("n", "S", function()
    if not enabled() then
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("S", true, false, true), "in", false)
      return
    end
    local lines = get_lines()
    local r = row()
    if on_connector_area(lines, r) then
      notify_blocked("S", "S is blocked on the connector area\n(use :Arb off to edit raw text)")
      return
    end
    local _, node = node_at(lines, r)
    if not node or node.level == 0 then
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("S", true, false, true), "in", false)
      return
    end
    local name_start = name_start_at(lines[r], node)
    vim.api.nvim_win_set_cursor(0, { r, name_start - 1 })
    -- Same as cc: native C deletes from the name start; deletion and typing share one undo block.
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("C", true, false, true), "in", false)
  end)

  tree_map("n", "R", function()
    if enabled() and detect.detect(get_lines(), row(), current_opts()) then
      notify_blocked("R", "R is blocked in tree mode\n(use :Arb off to edit raw text)")
      return
    end
    vim.cmd("startreplace")
  end)

  tree_map("n", "D", function()
    if not enabled() then
      return delete_to_eol()
    end
    if on_connector_area(get_lines(), row()) then
      notify_blocked("D", "D is blocked on the connector area\n(use :Arb off to edit raw text)")
      return
    end
    delete_to_eol()
  end)

  local function join_at_line(sep)
    local lines = get_lines()
    local r = row()
    if not detect.detect(lines, r, current_opts()) then
      return false
    end
    local joins = math.max(vim.v.count1 - 1, 1)
    local cur = lines
    for _ = 1, joins do
      local nl = edit.join_line(cur, r, sep, current_opts())
      if not nl then
        break
      end
      cur = nl
    end
    if cur == lines then
      return false
    end
    set_lines(cur)
    return true
  end

  tree_map("n", "J", function()
    if not enabled() then
      return fallback("J")
    end
    if not join_at_line(" ") then
      fallback("J")
    end
  end)

  tree_map("n", "gJ", function()
    if not enabled() then
      return fallback("gJ")
    end
    if not join_at_line("") then
      fallback("gJ")
    end
  end)
end

return M
