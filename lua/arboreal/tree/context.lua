local detect = require("arboreal.detect")
local state = require("arboreal.tree.state")

local M = {}

function M.char_len_at(line, col)
  local b = line:byte(col)
  if not b then
    return 1
  end
  if b >= 0xF0 then
    return 4
  elseif b >= 0xE0 then
    return 3
  elseif b >= 0xC0 then
    return 2
  end
  return 1
end

function M.node_at(lines, r)
  local model = detect.detect(lines, r, state.current_opts())
  if not model then
    return nil, nil
  end
  for _, n in ipairs(model.nodes) do
    if n.line == r then
      return model, n
    end
  end
  return model, nil
end

function M.name_start_at(line, node)
  return #line - #node.name + 1
end

function M.on_connector_area(lines, r)
  local _, node = M.node_at(lines, r)
  if not node or node.level == 0 then
    return false
  end
  local name_start = M.name_start_at(lines[r], node)
  local c = vim.api.nvim_win_get_cursor(0)
  return c[2] < name_start - 1
end

return M
