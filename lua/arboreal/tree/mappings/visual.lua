local M = {}

--- Register visual-mode tree guards and the ArbVis command.
--- All dependencies are injected through ctx to avoid a cycle with arboreal.tree.
function M.setup(ctx)
  local enabled = ctx.enabled
  local get_lines = ctx.get_lines
  local set_lines = ctx.set_lines
  local fallback = ctx.fallback
  local notify = ctx.notify
  local current_opts = ctx.current_opts
  local detect = ctx.detect
  local edit = ctx.edit
  local char_len_at = ctx.char_len_at
  local name_start_at = ctx.name_start_at
  local delete_char_range = ctx.delete_char_range
  local indent_lines = ctx.indent_lines
  local shift_visual = ctx.shift_visual
  local delete_selection = ctx.delete_selection
  local tree_map = ctx.tree_map

  -- Whether a characterwise/blockwise selection touches tree formatting (connector/pipe area).
  local function selection_touches_format(mode, vpos, cpos)
    if not mode:match("[vV\22]") then
      return false
    end
    local lines = get_lines()
    local from_line = math.min(vpos[2], cpos[2])
    local to_line = math.max(vpos[2], cpos[2])
    if mode == "V" then
      for l = from_line, to_line do
        local model = detect.detect(lines, l, current_opts())
        if model then
          for _, n in ipairs(model.nodes) do
            if n.line == l and n.level > 0 then
              return true
            end
          end
        end
      end
      return false
    end
    local from_col = math.min(vpos[3], cpos[3])
    for l = from_line, to_line do
      local model = detect.detect(lines, l, current_opts())
      if model then
        for _, n in ipairs(model.nodes) do
          if n.line == l and n.level > 0 then
            local name_start = name_start_at(lines[l], n)
            -- Blockwise starts at the same column on every line; characterwise spans middle lines from column 1.
            local sel_start = mode == "\22" and from_col or (l == from_line and from_col or 1)
            if sel_start < name_start then
              return true
            end
          end
        end
      end
    end
    return false
  end

  local function visual_change_range(b, e)
    local lines = get_lines()
    set_lines(delete_char_range(lines, b, e))
    vim.api.nvim_win_set_cursor(0, { b[2], b[3] - 1 })
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>i", true, false, true), "in", false)
  end

  local function visual_change(vpos, cpos)
    local b, e
    if vpos[2] < cpos[2] or (vpos[2] == cpos[2] and vpos[3] <= cpos[3]) then
      b, e = vpos, cpos
    else
      b, e = cpos, vpos
    end
    if b[2] == e[2] and b[3] == e[3] then
      local line = get_lines()[b[2]]
      e = { b[1], b[2], b[3] + char_len_at(line, b[3]), b[4] }
    end
    visual_change_range(b, e)
  end

  local function visual_join(sep, from, to)
    local lines = get_lines()
    local model = detect.detect(lines, from, current_opts())
    if not model then
      return nil
    end
    local in_range = 0
    for _, n in ipairs(model.nodes) do
      if n.line >= from and n.line <= to then
        in_range = in_range + 1
      end
    end
    if in_range < to - from + 1 then
      return nil
    end
    local cur = lines
    for _ = from, to - 1 do
      local nl = edit.join_line(cur, from, sep, current_opts())
      if not nl then
        return nil
      end
      cur = nl
    end
    return cur
  end

  -- Blocked visual operations must handle their follow-up keys: r consumes
  -- one replacement char; c/s/C consume input until Esc; always leave visual
  -- mode so the leftover selection cannot reinterpret later keys.
  local function leave_visual_mode()
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
  end

  local function consume_until_esc()
    while true do
      local ch = vim.fn.getcharstr()
      if ch == "\27" or ch == "\3" then
        return
      end
    end
  end

  local function block_visual(key, consume)
    notify(key .. " would damage the tree\n(use :Arb off to edit raw text)", vim.log.levels.WARN)
    vim.cmd("redraw")
    if consume == "char" then
      vim.fn.getcharstr()
    elseif consume == "until-esc" then
      consume_until_esc()
    end
    leave_visual_mode()
  end

  -- Native visual D is linewise and would delete the whole tree line. Inside
  -- names, D safely deletes the selected chars instead (like visual x) and
  -- cross-line selections are blocked.
  local function visual_delete_selection(vpos, cpos)
    local b, e
    if vpos[2] < cpos[2] or (vpos[2] == cpos[2] and vpos[3] <= cpos[3]) then
      b, e = vpos, cpos
    else
      b, e = cpos, vpos
    end
    if b[2] ~= e[2] then
      notify(
        "D across tree lines would damage the tree\n(use :Arb off to edit raw text)",
        vim.log.levels.WARN
      )
      leave_visual_mode()
      return
    end
    if b[3] == e[3] then
      local line = get_lines()[b[2]]
      e = { b[1], b[2], b[3] + char_len_at(line, b[3]), b[4] }
    end
    set_lines(delete_char_range(get_lines(), b, e))
    leave_visual_mode()
  end

  -- Visual operations go through <cmd> + user command: v marks are reliable in command context.
  pcall(vim.api.nvim_del_user_command, "ArbVis")
  vim.api.nvim_create_user_command("ArbVis", function(op)
    local sub = op.fargs[1]
    local vpos = vim.fn.getpos("v")
    local cpos = vim.fn.getpos(".")
    local from = math.min(vpos[2], cpos[2])
    local to = math.max(vpos[2], cpos[2])
    local mode = vim.fn.mode()
    if sub == "sr" or sub == "sl" then
      if not enabled() then
        set_lines(indent_lines(get_lines(), from, to, sub == "sr" and 1 or -1))
        return
      end
      shift_visual(sub == "sr" and 1 or -1, from, to)
    elseif sub == "del" then
      if not enabled() then
        fallback("d")
        return
      end
      -- Only linewise V d is the structural delete-whole-node operation;
      -- characterwise/blockwise block when format is touched, otherwise run native d.
      if mode ~= "V" then
        if selection_touches_format(mode, vpos, cpos) then
          block_visual("d", nil)
          return
        end
        fallback("d")
        return
      end
      local res = delete_selection(from, to)
      if res == nil then
        fallback("d")
      elseif res == true then
        vim.api.nvim_feedkeys(
          vim.api.nvim_replace_termcodes("<Esc>", true, false, true),
          "n",
          false
        )
      end
    elseif sub == "join" or sub == "joinx" then
      if not enabled() then
        fallback(sub == "join" and "J" or "gJ")
        return
      end
      local nl = visual_join(sub == "join" and " " or "", from, to)
      if not nl then
        fallback(sub == "join" and "J" or "gJ")
        return
      end
      set_lines(nl)
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
    elseif sub == "ch" or sub == "cheol" then
      local key = sub == "ch" and "c" or "C"
      if not enabled() then
        fallback(key)
        return
      end
      if selection_touches_format(mode, vpos, cpos) then
        block_visual(key, "until-esc")
        return
      end
      if sub == "cheol" then
        local b = (vpos[2] < cpos[2] or (vpos[2] == cpos[2] and vpos[3] <= cpos[3])) and vpos
          or cpos
        visual_change_range(b, { 0, b[2], vim.fn.col("$") + 1, 0 })
      else
        visual_change(vpos, cpos)
      end
    elseif sub == "gx" or sub == "gD" or sub == "gr" then
      local key = sub == "gx" and "x" or (sub == "gD" and "D" or "r")
      if not enabled() then
        fallback(key)
        return
      end
      if selection_touches_format(mode, vpos, cpos) then
        block_visual(key, sub == "gr" and "char" or nil)
        return
      end
      if sub == "gD" then
        visual_delete_selection(vpos, cpos)
      else
        fallback(key)
      end
    elseif sub == "gp" or sub == "gP" then
      if enabled() and selection_touches_format(mode, vpos, cpos) then
        block_visual("paste", nil)
        return
      end
      fallback(sub == "gp" and "p" or "P")
    end
  end, { nargs = 1 })

  tree_map("x", ">", "<cmd>ArbVis sr<CR>")
  tree_map("x", "<", "<cmd>ArbVis sl<CR>")
  tree_map("x", "d", "<cmd>ArbVis del<CR>")
  tree_map("x", "J", "<cmd>ArbVis join<CR>")
  tree_map("x", "gJ", "<cmd>ArbVis joinx<CR>")
  tree_map("x", "c", "<cmd>ArbVis ch<CR>")
  tree_map("x", "s", "<cmd>ArbVis ch<CR>")
  tree_map("x", "C", "<cmd>ArbVis cheol<CR>")
  tree_map("x", "x", "<cmd>ArbVis gx<CR>")
  tree_map("x", "D", "<cmd>ArbVis gD<CR>")
  tree_map("x", "r", "<cmd>ArbVis gr<CR>")
  tree_map("x", "p", "<cmd>ArbVis gp<CR>")
  tree_map("x", "P", "<cmd>ArbVis gP<CR>")
end

return M
