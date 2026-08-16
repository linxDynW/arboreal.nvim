local config = require("arboreal.config")

local M = {}

function M.config()
  return require("arboreal").config or config.defaults
end

function M.enabled()
  return vim.b.arboreal_enabled ~= false
end

function M.get_lines()
  return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

function M.set_lines(lines)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
end

function M.row()
  return vim.fn.line(".")
end

function M.col()
  return vim.fn.col(".")
end

function M.fallback(key)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(key, true, false, true), "in", false)
end

function M.current_opts()
  return {
    branch = M.config().branch,
    leaf = M.config().leaf,
    pipe = M.config().pipe,
    indent = M.config().indent,
  }
end

return M
