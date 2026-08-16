local render = require("arboreal.render")

--- Internal helpers shared with arboreal.edit: option resolution, node lookup, rendering and region write-back.

local function resolve(opts)
  opts = opts or {}
  opts.branch = opts.branch or "├──"
  opts.leaf = opts.leaf or "└──"
  opts.pipe = opts.pipe or "│"
  opts.indent = math.max(opts.indent or 4, 1)
  return opts
end

local function node_index(model, line)
  for idx = 1, #model.nodes do
    if model.nodes[idx].line == line then
      return idx
    end
  end
  return nil
end

-- Derive is_dir / is_last from {level, name} entries (same rules as detect).
---@param entries {level:integer, name:string}[]
---@return arboreal.EditNode[]
local function annotate(entries)
  local n = #entries
  local nodes = {}
  for i = 1, n do
    local is_dir = i < n and entries[i + 1].level > entries[i].level
    local is_last = false
    if i > 1 then
      is_last = true
      for j = i + 1, n do
        if entries[j].level <= entries[i].level then
          if entries[j].level == entries[i].level then
            is_last = false
          end
          break
        end
      end
    end
    nodes[i] = {
      level = entries[i].level,
      name = entries[i].name,
      is_dir = is_dir,
      is_last = is_last,
      focus = entries[i].focus,
    }
  end
  return nodes
end

-- Render nodes with empty-name collapse rules and the outer margin.
---@param nodes arboreal.EditNode[]
---@param opts arboreal.EditOpts
---@return string[]
local function rebuild_nodes(nodes, opts)
  local simple = {}
  for i = 1, #nodes do
    simple[i] = { level = nodes[i].level, name = nodes[i].name }
  end
  local rendered = render.render(simple, opts)
  local margin = (nodes[1] and nodes[1].margin) or ""
  local out = {}
  for i = 1, #nodes do
    local line = rendered[i]
    local node = nodes[i]
    if node.name == "" and not node.is_dir and node.is_last == false and node.level > 0 then
      local prefix = line:sub(1, #line - #opts.branch - 1)
      if node.focus then
        line = prefix .. opts.branch .. " "
      else
        line = prefix .. opts.pipe
      end
    end
    out[i] = margin .. line
  end
  return out
end

-- Render entries back into the tree region of lines (outside lines unchanged).
---@param lines string[]
---@param model arboreal.TreeModel
---@param entries {level:integer, name:string}[]
---@param opts arboreal.EditOpts
---@return string[]
local function apply_entries(lines, model, entries, opts)
  local nodes = annotate(entries)
  local rendered = rebuild_nodes(nodes, opts)
  local out = {}
  for k = 1, #lines do
    out[k] = lines[k]
  end
  local s = model.start
  for j = 1, #rendered do
    out[s + j - 1] = rendered[j]
  end
  return out
end

return {
  resolve = resolve,
  node_index = node_index,
  annotate = annotate,
  rebuild_nodes = rebuild_nodes,
  apply_entries = apply_entries,
}
