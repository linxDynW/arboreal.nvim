local M = {}

--- Register tree-aware operator callbacks for >, <, d, and c.
--- Dependencies are injected through ctx; callbacks stay exposed as arboreal.tree.op_* for operatorfunc.
function M.setup(ctx)
  local enabled = ctx.enabled
  local get_lines = ctx.get_lines
  local set_lines = ctx.set_lines
  local notify = ctx.notify
  local current_opts = ctx.current_opts
  local cfg = ctx.cfg
  local detect = ctx.detect
  local edit = ctx.edit
  local name_start_at = ctx.name_start_at
  local indent_lines = ctx.indent_lines
  local selection_is_body = ctx.selection_is_body
  local delete_char_range = ctx.delete_char_range
  local tree_map = ctx.tree_map

  local function op_range()
    local from = vim.fn.line("'[")
    local to = vim.fn.line("']")
    if from > to then
      from, to = to, from
    end
    return from, to
  end

  local function op_shift(dir)
    local from, to = op_range()
    local lines = get_lines()
    if enabled() and selection_is_body(lines, from, to) then
      local nl = edit.shift_lines(lines, from, to, dir, current_opts())
      if nl then
        set_lines(nl)
        return
      end
      if cfg().notify_on_limit then
        notify(
          "cannot shift selection (level limit or partially selected subtree)",
          vim.log.levels.WARN
        )
      end
      return
    end
    set_lines(indent_lines(lines, from, to, dir))
  end

  local function op_shift_right()
    op_shift(1)
  end

  local function op_shift_left()
    op_shift(-1)
  end

  local function op_delete(mode)
    local from, to = op_range()
    local lines = get_lines()
    local model = nil
    if enabled() then
      model = detect.detect(lines, from, current_opts())
    end
    if model then
      local b = vim.fn.getpos("'[")
      local e = vim.fn.getpos("']")
      if mode ~= "line" and b[2] == e[2] and from == to then
        local node = nil
        for _, n in ipairs(model.nodes) do
          if n.line == from then
            node = n
            break
          end
        end
        if node and node.level > 0 then
          local name_start = name_start_at(lines[from], node)
          if b[3] < name_start - 1 or e[3] < name_start - 1 then
            notify(
              "deletion would damage the tree\n(use :Arb off to edit raw text)",
              vim.log.levels.WARN
            )
            return
          end
        end
        vim.cmd("silent! normal! `[v`]d")
        ctx.refresh(nil, false)
        return
      end
      -- Cross-line characterwise/blockwise operators must not use structural
      -- line deletion or they would remove whole tree nodes; block instead.
      if mode ~= "line" then
        notify(
          "deletion would damage the tree\n(use :Arb off to edit raw text)",
          vim.log.levels.WARN
        )
        return
      end
      local nl, merged = edit.delete_lines(lines, from, to, current_opts())
      if not nl then
        notify("could not delete the selection as a tree", vim.log.levels.WARN)
        return
      end
      if merged and cfg().confirm_directory_delete then
        local choice = vim.fn.confirm(
          "Delete selection? Some children will be merged into their parents (undo with u)",
          "&Yes\n&No",
          1
        )
        if choice ~= 1 then
          return
        end
      end
      set_lines(nl)
      if merged then
        notify("selection deleted, children merged into parents (u to undo)", vim.log.levels.WARN)
      end
      return
    end
    if mode == "line" then
      vim.cmd(from .. "," .. to .. "delete")
    else
      vim.cmd("silent! normal! `[v`]d")
    end
  end

  tree_map("n", ">", function()
    vim.o.operatorfunc = "v:lua.require'arboreal.tree'.op_shift_right"
    return "g@"
  end, { expr = true })

  tree_map("n", "<", function()
    vim.o.operatorfunc = "v:lua.require'arboreal.tree'.op_shift_left"
    return "g@"
  end, { expr = true })

  tree_map("n", "d", function()
    vim.o.operatorfunc = "v:lua.require'arboreal.tree'.op_delete"
    return "g@"
  end, { expr = true })

  local function op_change(mode)
    local from, to = op_range()
    local lines = get_lines()
    local model = nil
    if enabled() then
      model = detect.detect(lines, from, current_opts())
    end
    local b = vim.fn.getpos("'[")
    local e = vim.fn.getpos("']")
    if model then
      if mode ~= "line" and b[2] == e[2] then
        local node = nil
        for _, n in ipairs(model.nodes) do
          if n.line == from then
            node = n
            break
          end
        end
        if node and node.level > 0 then
          local name_start = name_start_at(lines[from], node)
          if b[3] < name_start then
            notify(
              "change would damage the tree\n(use :Arb off to edit raw text)",
              vim.log.levels.WARN
            )
            return
          end
        end
      else
        notify(
          "linewise change is blocked in tree mode\n(use :Arb off to edit raw text)",
          vim.log.levels.WARN
        )
        return
      end
    end
    if mode == "line" then
      vim.cmd(from .. "," .. to .. "delete")
      vim.api.nvim_win_set_cursor(0, { math.min(from, vim.fn.line("$")), 0 })
      vim.cmd("startinsert")
      return
    end
    set_lines(delete_char_range(lines, b, e))
    vim.api.nvim_win_set_cursor(0, { b[2], b[3] - 1 })
    vim.cmd("startinsert")
  end

  return {
    shift_right = op_shift_right,
    shift_left = op_shift_left,
    delete = op_delete,
    change = op_change,
  }
end

return M
