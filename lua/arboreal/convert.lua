local parse = require("arboreal.parse")
local render = require("arboreal.render")
local config = require("arboreal.config")

local M = {}

---@param bufnr integer 0 means the current buffer
---@param start_line integer 1-based, inclusive
---@param end_line integer 1-based, inclusive
---@return boolean ok
---@return integer? err_line Absolute 1-based buffer line for error reporting
---@return string? err_msg
function M.convert_range(bufnr, start_line, end_line)
  local cfg = require("arboreal").config or config.defaults
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
  local result, err_line, err_msg = parse.parse(lines, { indent = cfg.indent })
  if not result then
    return false, start_line + err_line - 1, err_msg
  end
  local rendered = render.render(result.nodes, {
    branch = cfg.branch,
    leaf = cfg.leaf,
    pipe = cfg.pipe,
    indent = cfg.indent,
  })
  local out = {}
  local ni = 1
  for i = 1, #lines do
    if lines[i]:match("^%s*$") then
      out[i] = lines[i]
    else
      out[i] = result.base_str .. rendered[ni]
      ni = ni + 1
    end
  end
  vim.api.nvim_buf_set_lines(bufnr, start_line - 1, end_line, false, out)
  return true
end

return M
