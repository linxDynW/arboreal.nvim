local detect = require("arboreal.detect")
local common = require("arboreal.edit.common")

local resolve = common.resolve
local node_index = common.node_index
local apply_entries = common.apply_entries

local M = {}

---@param lines string[]
---@param at_line integer 1-based line anywhere inside the target tree
---@param focus_line integer? Line that needs focus rendering; nil for no focus
---@param opts? arboreal.EditOpts
---@return string[]? Re-rendered lines when a valid tree is found, otherwise nil
function M.render_region(lines, at_line, focus_line, opts)
  opts = resolve(opts)
  local model = detect.detect(lines, at_line, opts)
  if not model then
    return nil
  end
  local entries = {}
  for j = 1, #model.nodes do
    local node = model.nodes[j]
    entries[j] = {
      level = node.level,
      name = node.name,
      focus = node.line == focus_line
        and node.name == ""
        and not node.is_dir
        and node.is_last == false,
    }
  end
  return apply_entries(lines, model, entries, opts)
end

--- Shift levels for every selected node (visual < and >).
--- Atomic: validate the whole selection first. If any node violates the
--- constraints (level jump, unselected children, level boundary), apply
--- nothing and return nil.
---@param lines string[]
---@param from_line integer 1-based first selected line
---@param to_line integer 1-based last selected line
---@param dir integer 1 or -1
---@param opts? arboreal.EditOpts
---@return string[]? new_lines
function M.shift_lines(lines, from_line, to_line, dir, opts)
  opts = resolve(opts)
  local model = detect.detect(lines, from_line, opts)
  if not model then
    return nil
  end
  if dir ~= 1 and dir ~= -1 then
    return nil
  end
  local function selected(node)
    return node.line >= from_line and node.line <= to_line
  end
  local any = false
  for _, node in ipairs(model.nodes) do
    if selected(node) then
      any = true
      break
    end
  end
  if not any then
    return nil
  end

  local new_levels = {}
  local prev_new = 0
  for j = 1, #model.nodes do
    local node = model.nodes[j]
    local new_level = node.level
    if selected(node) then
      new_level = node.level + dir
      if dir == 1 then
        if node.level == 0 or new_level > prev_new + 1 then
          return nil
        end
      else
        if node.level <= 1 then
          return nil
        end
      end
      if node.is_dir and dir == -1 then
        local next = model.nodes[j + 1]
        if next and next.level > node.level and not selected(next) then
          return nil
        end
      end
    end
    prev_new = new_level
    new_levels[j] = new_level
  end

  local entries = {}
  for j = 1, #model.nodes do
    entries[j] = { level = new_levels[j], name = model.nodes[j].name }
  end
  return apply_entries(lines, model, entries, opts)
end

--- Delete multiple selected lines (visual d / d operator).
--- Equivalent to delete_node bottom-up; children merge exactly as with
--- single-line deletion, and non-tree lines are removed as plain text.
---@param lines string[]
---@param from_line integer 1-based
---@param to_line integer 1-based
---@param opts? arboreal.EditOpts
---@return string[]? new_lines nil when the first selected line is not in a tree; a selected root line is deleted as plain text
---@return boolean? merged Whether unselected children were merged into the parent
function M.delete_lines(lines, from_line, to_line, opts)
  opts = resolve(opts)
  local model = detect.detect(lines, from_line, opts)
  if not model then
    return nil
  end
  local function selected(node)
    return node.line >= from_line and node.line <= to_line
  end
  local merged = false
  for j = 1, #model.nodes do
    local node = model.nodes[j]
    if selected(node) and node.is_dir and node.level > 0 then
      for k = j + 1, #model.nodes do
        local child = model.nodes[k]
        if child.level <= node.level then
          break
        end
        if child.level == node.level + 1 and not selected(child) then
          merged = true
          break
        end
      end
    end
    if merged then
      break
    end
  end
  local cur = {}
  for k = 1, #lines do
    cur[k] = lines[k]
  end
  for l = to_line, from_line, -1 do
    local nl = M.delete_node(cur, l, opts)
    if nl then
      cur = nl
    else
      local out = {}
      for k = 1, #cur do
        if k ~= l then
          out[#out + 1] = cur[k]
        end
      end
      cur = out
    end
  end
  return cur, merged
end

--- Join the next node into the current line (J). The current name is
--- appended to the next name with sep; the next node is removed and its
--- subtree is shifted by delta = A.level - B.level under the current node
--- (deeper B moves up, sibling stays, shallower B moves down).
---@param lines string[]
---@param i integer 1-based current line
---@param sep string Name separator (" " for J, "" for gJ)
---@param opts? arboreal.EditOpts
---@return string[]? new_lines nil when not in a tree or no next node
function M.join_line(lines, i, sep, opts)
  opts = resolve(opts)
  local model = detect.detect(lines, i, opts)
  if not model then
    return nil
  end
  local idx = nil
  for j = 1, #model.nodes do
    if model.nodes[j].line == i then
      idx = j
      break
    end
  end
  if not idx or idx == #model.nodes then
    return nil
  end
  local A = model.nodes[idx]
  local B = model.nodes[idx + 1]
  local delta = A.level - B.level
  local entries = {}
  local in_subtree = false
  for j = 1, #model.nodes do
    local node = model.nodes[j]
    if j == idx then
      entries[#entries + 1] = { level = node.level, name = node.name .. sep .. B.name }
      in_subtree = true
    elseif j ~= idx + 1 then
      if in_subtree and node.level > B.level then
        entries[#entries + 1] = { level = node.level + delta, name = node.name }
      else
        in_subtree = false
        entries[#entries + 1] = { level = node.level, name = node.name }
      end
    end
  end
  local out = {}
  for k = 1, #lines do
    if k ~= B.line then
      out[#out + 1] = lines[k]
    end
  end
  return apply_entries(out, model, entries, opts)
end

--- Insert a sibling before the current tree line (normal mode O).
--- Returns nil for the root line. The new node takes the current line
--- number and the original node moves down.
---@param lines string[]
---@param i integer 1-based
---@param opts? arboreal.EditOpts
---@return string[]? new_lines
---@return integer? new_line 1-based line number of the new line
function M.new_sibling_before(lines, i, opts)
  opts = resolve(opts)
  local model = detect.detect(lines, i, opts)
  if not model then
    return nil
  end
  local idx = node_index(model, i)
  if idx == nil then
    return nil
  end
  local node = model.nodes[idx]
  if node.level == 0 then
    return nil
  end
  local pos = node.line
  local out = {}
  for k = 1, #lines do
    out[k] = lines[k]
  end
  table.insert(out, pos, "")

  local entries = {}
  for j = 1, #model.nodes do
    if j == idx then
      entries[#entries + 1] = { level = node.level, name = "" }
    end
    entries[#entries + 1] = { level = model.nodes[j].level, name = model.nodes[j].name }
  end
  return apply_entries(out, model, entries, opts), pos
end

---@param lines string[]
---@param i integer 1-based
---@param opts? arboreal.EditOpts
---@return string[]? new_lines nil when the line above is blank or missing
function M.insert_marker(lines, i, opts)
  opts = resolve(opts)
  if i <= 1 then
    return nil
  end
  local above = lines[i - 1]
  if not above or above:match("^%s*$") then
    return nil
  end
  if detect.detect(lines, i, opts) then
    return nil
  end
  local out = {}
  for k = 1, #lines do
    out[k] = lines[k]
  end
  local margin = lines[i]:match("^%s*") or ""
  local rest = lines[i]:sub(#margin + 1)
  out[i] = margin .. opts.leaf .. " " .. rest
  return out
end

---@param lines string[]
---@param i integer 1-based
---@param opts? arboreal.EditOpts
---@return string[]? new_lines
---@return integer? new_line
function M.new_sibling(lines, i, opts)
  opts = resolve(opts)
  local model = detect.detect(lines, i, opts)
  if not model then
    return nil
  end
  local idx = node_index(model, i)
  if idx == nil then
    return nil
  end
  local node = model.nodes[idx]
  local new_level = node.level == 0 and 1 or node.level

  local e = node.line
  for j = idx + 1, #model.nodes do
    if model.nodes[j].level > node.level then
      e = model.nodes[j].line
    else
      break
    end
  end

  local out = {}
  for k = 1, #lines do
    out[k] = lines[k]
  end
  table.insert(out, e + 1, "")

  local entries = {}
  local insert_after = 0
  for j = 1, #model.nodes do
    entries[#entries + 1] = { level = model.nodes[j].level, name = model.nodes[j].name }
    if model.nodes[j].line == e then
      insert_after = #entries
    end
  end
  table.insert(entries, insert_after + 1, { level = new_level, name = "" })

  out = apply_entries(out, model, entries, opts)
  return out, e + 1
end

---@param lines string[]
---@param i integer
---@param dir integer 1 or -1
---@param opts? arboreal.EditOpts
---@return string[]? new_lines
function M.shift(lines, i, dir, opts)
  opts = resolve(opts)
  local model = detect.detect(lines, i, opts)
  if not model then
    return nil
  end
  local idx = node_index(model, i)
  if idx == nil then
    return nil
  end
  local node = model.nodes[idx]

  if dir == 1 then
    if node.level == 0 then
      return nil
    end
    local prev = idx > 1 and model.nodes[idx - 1].level or 0
    if node.level >= prev + 1 then
      return nil
    end
  elseif dir == -1 then
    if node.level == 0 or node.level == 1 or node.is_dir then
      return nil
    end
  else
    return nil
  end

  local entries = {}
  for j = 1, #model.nodes do
    local lvl = model.nodes[j].level
    if j == idx then
      lvl = lvl + dir
    end
    entries[#entries + 1] = { level = lvl, name = model.nodes[j].name }
  end

  return apply_entries(lines, model, entries, opts)
end

---@param lines string[]
---@param i integer
---@param col integer 1-based
---@param opts? arboreal.EditOpts
---@return string[]? new_lines
---@return integer? new_line
---@return integer? new_col
---@return boolean? blocked In a tree but deletion would damage formatting (connector area or empty directory)
function M.backspace(lines, i, col, opts)
  opts = resolve(opts)
  local model = detect.detect(lines, i, opts)
  if not model then
    return nil
  end
  local idx = node_index(model, i)
  if idx == nil then
    return nil
  end
  local node = model.nodes[idx]
  local name_start = #lines[i] - #node.name + 1

  if node.level == 0 then
    return nil
  end

  if node.name ~= "" then
    if col <= name_start then
      return nil, nil, nil, true
    end
    local name = node.name
    local pos = math.min(col - name_start, #name)
    local lead = pos
    while lead > 1 do
      local cur = name:byte(lead)
      if cur and cur >= 0x80 and cur < 0xC0 then
        lead = lead - 1
      else
        break
      end
    end
    local new_name = name:sub(1, lead - 1) .. name:sub(pos + 1)

    local entries = {}
    for j = 1, #model.nodes do
      local nm = model.nodes[j].name
      if j == idx then
        nm = new_name
      end
      entries[#entries + 1] = { level = model.nodes[j].level, name = nm }
    end
    local out = apply_entries(lines, model, entries, opts)
    return out, i, name_start + pos - (pos - lead + 1)
  end

  if node.is_dir then
    return nil, nil, nil, true
  end

  local out = {}
  for k = 1, #lines do
    out[k] = lines[k]
  end
  table.remove(out, i)

  local entries = {}
  for j = 1, #model.nodes do
    if j ~= idx then
      entries[#entries + 1] = { level = model.nodes[j].level, name = model.nodes[j].name }
    end
  end
  out = apply_entries(out, model, entries, opts)
  return out, i - 1, #out[i - 1] + 1
end

---@param lines string[]
---@param i integer
---@param opts? arboreal.EditOpts
---@return string[]? new_lines
---@return boolean? was_dir
function M.delete_node(lines, i, opts)
  opts = resolve(opts)
  local model = detect.detect(lines, i, opts)
  if not model then
    return nil
  end
  local idx = node_index(model, i)
  if idx == nil then
    return nil
  end
  local node = model.nodes[idx]
  if node.level == 0 then
    return nil
  end

  local out = {}
  for k = 1, #lines do
    out[k] = lines[k]
  end
  table.remove(out, i)

  local entries = {}
  local in_subtree = false
  for j = 1, #model.nodes do
    if j == idx then
      in_subtree = node.is_dir
    else
      local lvl = model.nodes[j].level
      if in_subtree then
        if lvl > node.level then
          lvl = lvl - 1
        else
          in_subtree = false
        end
      end
      entries[#entries + 1] = { level = lvl, name = model.nodes[j].name }
    end
  end
  out = apply_entries(out, model, entries, opts)
  return out, node.is_dir
end

return M
