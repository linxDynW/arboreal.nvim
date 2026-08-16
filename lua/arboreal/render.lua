---@class arboreal.RenderOpts
---@field branch? string Non-last-child connector; default "├──"
---@field leaf? string Last-child connector; default "└──"
---@field pipe? string Vertical pipe; default "│"
---@field indent? integer Indent width per level; default 4

---@class arboreal.RenderNode
---@field level integer 0-based relative level (0 = root, no connector)
---@field name string

---@param nodes arboreal.RenderNode[] Valid level sequence: first node level 0, adjacent level delta <= 1, multiple roots allowed
---@param opts? arboreal.RenderOpts
---@return string[] Rendered lines, one per node
local M = {}

function M.render(nodes, opts)
  opts = opts or {}
  local branch = opts.branch or "├──"
  local leaf = opts.leaf or "└──"
  local pipe = opts.pipe or "│"
  local indent = opts.indent or 4
  if indent < 1 then
    indent = 1
  end
  local out = {}
  for i = 1, #nodes do
    local level = nodes[i].level
    if level == 0 then
      out[i] = nodes[i].name
    else
      local prefix = ""
      for d = 1, level - 1 do
        local open = false
        for j = i + 1, #nodes do
          if nodes[j].level <= d then
            if nodes[j].level == d then
              open = true
            end
            break
          end
        end
        if open then
          prefix = prefix .. pipe .. string.rep(" ", indent - 1)
        else
          prefix = prefix .. string.rep(" ", indent)
        end
      end
      local last = true
      for j = i + 1, #nodes do
        if nodes[j].level <= level then
          if nodes[j].level == level then
            last = false
          end
          break
        end
      end
      out[i] = prefix .. (last and leaf or branch) .. " " .. nodes[i].name
    end
  end
  return out
end

return M
