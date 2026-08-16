vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.cmd("runtime plugin/arboreal.lua")
vim.g.mapleader = " "

local M = {}

local passed, failed = 0, 0
local failures = {}

function M.test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
  else
    failed = failed + 1
    failures[#failures + 1] = name .. ": " .. tostring(err)
  end
end

function M.buf_lines()
  return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

function M.set_lines(lines)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
end

function M.keys(s)
  vim.fn.feedkeys(vim.api.nvim_replace_termcodes(s, true, false, true), "xt")
end

function M.cursor(l, c)
  vim.api.nvim_win_set_cursor(0, { l, c })
end

function M.setup_toggle(on)
  require("arboreal").setup({
    confirm_directory_delete = false,
    insert_key = "<leader>ai",
    toggle_key = "<leader>ut",
  })
  vim.b.arboreal_enabled = on
  vim.fn.confirm = function()
    return 1
  end
end

M.TREE = { "src", "├── a", "│   └── x", "└── b" }

function M.finish()
  io.write(string.format("%d passed, %d failed\n", passed, failed))
  for _, f in ipairs(failures) do
    io.write("FAIL: " .. f .. "\n")
  end
  if failed > 0 then
    vim.cmd("cquit!")
  else
    vim.cmd("qa!")
  end
end

return M
