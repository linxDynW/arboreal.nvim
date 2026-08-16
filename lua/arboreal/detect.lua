---@class arboreal.DetectOpts
---@field branch? string Default "├──"
---@field leaf? string Default "└──"
---@field pipe? string Default "│"
---@field indent? integer Default 4

---@class arboreal.TreeNode
---@field line integer 1-based line number
---@field level integer 0-based level (root is 0)
---@field name string Node name (may be empty)
---@field margin string Outer margin (leading whitespace)
---@field is_dir boolean Whether the node has children
---@field is_last boolean Whether it is the last child of its parent

---@class arboreal.TreeModel
---@field start integer First line of the region (root line when present)
---@field finish integer Last line of the region
---@field nodes arboreal.TreeNode[] In line order; nodes[1] is the root (level 0)

local M = {}

local function make(opts)
  local branch = opts.branch or "├──"
  local leaf = opts.leaf or "└──"
  local pipe = opts.pipe or "│"
  local indent = math.max(opts.indent or 4, 1)
  local segpad = string.rep(" ", indent - 1)
  local segspace = string.rep(" ", indent)

  -- Strict parse of rest after the margin:
  --   (pipe+pad or indent spaces)* followed by connector + space + name,
  --   or segments* followed by a bare pipe (collapsed empty-name leaf).
  -- Returns level (segment count), name, and collapsed.
  local function strict(rest)
    if rest == "" then
      return nil
    end
    local level = 0
    while true do
      if rest:sub(1, #pipe) == pipe then
        local after = rest:sub(#pipe + 1)
        if after == "" then
          return level, "", true
        end
        if after:sub(1, indent - 1) ~= segpad then
          return nil
        end
        rest = after:sub(indent)
        level = level + 1
      elseif rest:sub(1, indent) == segspace then
        rest = rest:sub(indent + 1)
        level = level + 1
      else
        break
      end
    end
    local conn_len
    if rest:sub(1, #branch) == branch then
      conn_len = #branch
    elseif rest:sub(1, #leaf) == leaf then
      conn_len = #leaf
    else
      return nil
    end
    if rest:sub(conn_len + 1, conn_len + 1) ~= " " then
      return nil
    end
    return level, rest:sub(conn_len + 2), false
  end

  -- Tolerant parse for boundary scanning: strip the margin greedily, then strict.
  local function tolerant(line)
    local margin = line:match("^%s*") or ""
    return strict(line:sub(#margin + 1)) ~= nil
  end

  return strict, tolerant
end

---@param lines string[]
---@param i integer
---@param opts? arboreal.DetectOpts
---@return arboreal.TreeModel?
function M.detect(lines, i, opts)
  opts = opts or {}
  local line = lines[i]
  if not line or line:match("^%s*$") then
    return nil
  end
  local strict, tolerant = make(opts)

  local root_line, body_from, body_to
  if tolerant(line) then
    local top = i
    local j = i
    while j >= 1 and tolerant(lines[j]) do
      top = j
      j = j - 1
    end
    -- A plain line above is the root only when its margin matches the body
    -- margin; otherwise (deleted/indented root) the tree starts at the body.
    root_line = nil
    if j >= 1 and not lines[j]:match("^%s*$") then
      local m = lines[j]:match("^%s*") or ""
      local top_margin = lines[top]:match("^%s*") or ""
      if m == top_margin then
        root_line = j
      end
    end
    body_from = top
    local k = i + 1
    while k <= #lines and tolerant(lines[k]) do
      k = k + 1
    end
    body_to = k - 1
  else
    root_line = i
    if i + 1 > #lines or not tolerant(lines[i + 1]) then
      return nil
    end
    body_from = i + 1
    local k = i + 2
    while k <= #lines and tolerant(lines[k]) do
      k = k + 1
    end
    body_to = k - 1
  end

  local base_margin = lines[body_from]:match("^%s*") or ""
  if root_line then
    local root_margin = lines[root_line]:match("^%s*") or ""
    if root_margin ~= base_margin then
      root_line = nil
    end
  end

  local nodes = {}
  if root_line then
    nodes[1] = {
      line = root_line,
      level = 0,
      name = lines[root_line]:sub(#base_margin + 1),
      margin = base_margin,
      is_dir = false,
      is_last = false,
    }
  end

  local prev = 0
  for x = body_from, body_to do
    local l = lines[x]
    if l:sub(1, #base_margin) ~= base_margin then
      return nil
    end
    local level, name = strict(l:sub(#base_margin + 1))
    if level == nil then
      return nil
    end
    level = level + 1
    if level > prev + 1 then
      return nil
    end
    prev = level
    nodes[#nodes + 1] = {
      line = x,
      level = level,
      name = name,
      margin = base_margin,
      is_dir = false,
      is_last = false,
    }
  end

  local first_body = root_line and 2 or 1
  if #nodes < first_body or nodes[first_body].level ~= 1 then
    return nil
  end

  local count = #nodes
  for idx = 1, count do
    if idx < count and nodes[idx + 1].level > nodes[idx].level then
      nodes[idx].is_dir = true
    end
    if nodes[idx].level > 0 then
      local found = nil
      local fidx = idx + 1
      while fidx <= count do
        if nodes[fidx].level <= nodes[idx].level then
          found = nodes[fidx]
          break
        end
        fidx = fidx + 1
      end
      if found == nil or found.level < nodes[idx].level then
        nodes[idx].is_last = true
      end
    end
  end

  return {
    start = root_line or body_from,
    finish = nodes[count].line,
    nodes = nodes,
  }
end

return M
