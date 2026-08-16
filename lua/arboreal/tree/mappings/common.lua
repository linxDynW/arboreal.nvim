local M = {}

--- Structural tree-region operations shared by mapping modules.
function M.setup(ctx)
  local get_lines = ctx.get_lines
  local set_lines = ctx.set_lines
  local row = ctx.row
  local notify = ctx.notify
  local current_opts = ctx.current_opts
  local cfg = ctx.cfg
  local detect = ctx.detect
  local edit = ctx.edit

  local function indent_lines(lines, from, to, dir)
    local sw = vim.bo.shiftwidth
    if not sw or sw <= 0 then
      sw = vim.bo.tabstop or 8
    end
    local out = {}
    for k = 1, #lines do
      local l = lines[k]
      if k >= from and k <= to then
        if dir == 1 then
          local pad = vim.bo.expandtab and string.rep(" ", sw) or "\t"
          l = pad .. l
        else
          local rest = l
          local removed = 0
          while removed < sw do
            local m = rest:match("^[ \t]")
            if not m then
              break
            end
            rest = rest:sub(2)
            removed = removed + (m == "\t" and 8 or 1)
          end
          l = rest
        end
      end
      out[k] = l
    end
    return out
  end
  local function preserve_visual(from, to)
    local cur = vim.api.nvim_win_get_cursor(0)
    vim.fn.setpos("'<", { 0, from, 1, 0 })
    vim.fn.setpos("'>", { 0, to, 1, 0 })
    vim.api.nvim_win_set_cursor(0, cur)
  end

  -- Whether the selection consists entirely of body lines (root or non-tree lines mean plain text).
  local function selection_is_body(lines, from, to)
    local model = detect.detect(lines, from, current_opts())
    if not model then
      return false
    end
    local in_range = 0
    for _, n in ipairs(model.nodes) do
      if n.line >= from and n.line <= to then
        in_range = in_range + 1
        if n.level == 0 then
          return false
        end
      end
    end
    return in_range == to - from + 1
  end

  local function shift_visual(dir, from, to)
    local lines = get_lines()
    if selection_is_body(lines, from, to) then
      local nl = edit.shift_lines(lines, from, to, dir, current_opts())
      if not nl then
        if cfg().notify_on_limit then
          notify(
            "cannot shift selection (level limit or partially selected subtree)",
            vim.log.levels.WARN
          )
        end
        return
      end
      set_lines(nl)
      preserve_visual(from, to)
      return
    end
    set_lines(indent_lines(lines, from, to, dir))
  end

  local function shift_line(dir)
    local count = math.max(vim.v.count1, 1)
    local lines = get_lines()
    local r = row()
    local to_line = math.min(r + count - 1, #lines)
    if not selection_is_body(lines, r, to_line) then
      set_lines(indent_lines(lines, r, to_line, dir))
      return
    end
    local nl = edit.shift_lines(lines, r, to_line, dir, current_opts())
    if not nl then
      if cfg().notify_on_limit then
        notify("cannot shift (level limit)", vim.log.levels.WARN)
      end
      return
    end
    set_lines(nl)
  end

  -- nil = not in a tree (fall back to native); false = blocked/cancelled
  -- (keep the selection); true = applied (leave visual mode).
  local function delete_selection(from, to)
    local lines = get_lines()
    if not detect.detect(lines, from, current_opts()) then
      return nil
    end
    local nl, merged = edit.delete_lines(lines, from, to, current_opts())
    if not nl then
      notify("could not delete the selection as a tree", vim.log.levels.WARN)
      return false
    end
    if merged and cfg().confirm_directory_delete then
      local choice = vim.fn.confirm(
        "Delete selection? Some children will be merged into their parents (undo with u)",
        "&Yes\n&No",
        1
      )
      if choice ~= 1 then
        return false
      end
    end
    set_lines(nl)
    if merged then
      notify("selection deleted, children merged into parents (u to undo)", vim.log.levels.WARN)
    end
    return true
  end

  local function delete_char_range(lines, b, e)
    local out = {}
    for k = 1, #lines do
      out[k] = lines[k]
    end
    if b[2] == e[2] then
      local line = lines[b[2]]
      out[b[2]] = line:sub(1, b[3] - 1) .. line:sub(e[3])
    else
      out[b[2]] = lines[b[2]]:sub(1, b[3] - 1)
      out[e[2]] = lines[e[2]]:sub(e[3])
      local cleaned = {}
      for k = 1, #out do
        if k <= b[2] or k >= e[2] then
          cleaned[#cleaned + 1] = out[k]
        end
      end
      out = cleaned
    end
    return out
  end

  return {
    indent_lines = indent_lines,
    preserve_visual = preserve_visual,
    selection_is_body = selection_is_body,
    shift_visual = shift_visual,
    shift_line = shift_line,
    delete_selection = delete_selection,
    delete_char_range = delete_char_range,
  }
end

return M
