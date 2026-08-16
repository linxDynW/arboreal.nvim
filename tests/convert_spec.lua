vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.cmd("runtime plugin/arboreal.lua")

local convert = require("arboreal.convert")

local passed, failed = 0, 0
local failures = {}

local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
  else
    failed = failed + 1
    failures[#failures + 1] = name .. ": " .. tostring(err)
  end
end

local function buf_lines()
  return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

local function set_lines(lines)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
end

test("convert basic", function()
  set_lines({ "src", "    a", "    b", "    tests", "        c" })
  local ok = assert(convert.convert_range(0, 1, 5))
  assert(ok)
  local r = buf_lines()
  assert(r[1] == "src", r[1])
  assert(r[2] == "├── a", r[2])
  assert(r[3] == "├── b", r[3])
  assert(r[4] == "└── tests", r[4])
  assert(r[5] == "    └── c", r[5])
end)

test("convert preserves blank lines", function()
  set_lines({ "src", "", "    a", "", "    b" })
  local ok = assert(convert.convert_range(0, 1, 5))
  assert(ok)
  local r = buf_lines()
  assert(r[1] == "src")
  assert(r[2] == "", tostring(r[2]))
  assert(r[3] == "├── a")
  assert(r[4] == "")
  assert(r[5] == "└── b")
end)

test("convert error leaves buffer unchanged", function()
  set_lines({ "src", "    a", "            b" })
  local before = buf_lines()
  local ok, err_line, err_msg = convert.convert_range(0, 1, 3)
  assert(ok == false)
  assert(err_line == 3, tostring(err_line))
  assert(err_msg:match("jumps"), err_msg)
  assert(vim.deep_equal(buf_lines(), before))
end)

test("convert error maps line to absolute buffer position", function()
  set_lines({ "hello", "src", "    a", "            b", "world" })
  local ok, err_line, err_msg = convert.convert_range(0, 2, 4)
  assert(ok == false)
  assert(err_line == 4, tostring(err_line))
  assert(err_msg:match("jumps"), err_msg)
end)

test("convert multiple roots", function()
  set_lines({ "src", "    a", "other", "    b" })
  local ok = assert(convert.convert_range(0, 1, 4))
  assert(ok)
  local r = buf_lines()
  assert(r[1] == "src")
  assert(r[2] == "└── a")
  assert(r[3] == "other")
  assert(r[4] == "└── b")
end)

test("ArborealConvert command with range", function()
  set_lines({ "x", "src", "    a", "y" })
  vim.cmd("2,3ArborealConvert")
  local r = buf_lines()
  assert(r[1] == "x")
  assert(r[2] == "src")
  assert(r[3] == "└── a")
  assert(r[4] == "y")
end)

test("convert preserves base margin", function()
  set_lines({
    "    fioewjfowjeof",
    "        fioewjfowjeof",
    "        fioewjfowjeof",
    "            fioewjfowjeof",
  })
  local ok = assert(convert.convert_range(0, 1, 4))
  assert(ok)
  local r = buf_lines()
  assert(r[1] == "    fioewjfowjeof", string.format("%q", r[1]))
  assert(r[2] == "    ├── fioewjfowjeof", string.format("%q", r[2]))
  assert(r[3] == "    └── fioewjfowjeof", string.format("%q", r[3]))
  assert(r[4] == "        └── fioewjfowjeof", string.format("%q", r[4]))
end)

test("ArborealConvert from visual mode without range", function()
  set_lines({ "fioewjfowjeof", "\tfioewjfowjeof", "\tfioewjfowjeof", "\t\tfioewjfowjeof" })
  vim.fn.feedkeys(
    vim.api.nvim_replace_termcodes("ggV3j<cmd>ArborealConvert<CR>", true, false, true),
    "xt"
  )
  local r = buf_lines()
  assert(r[1] == "fioewjfowjeof", r[1])
  assert(r[2] == "├── fioewjfowjeof", r[2])
  assert(r[3] == "└── fioewjfowjeof", r[3])
  assert(r[4] == "    └── fioewjfowjeof", r[4])
end)

test("convert margin with multiple roots", function()
  set_lines({ "  a", "    b", "  c", "    d" })
  local ok = assert(convert.convert_range(0, 1, 4))
  assert(ok)
  local r = buf_lines()
  assert(r[1] == "  a", string.format("%q", r[1]))
  assert(r[2] == "  └── b", string.format("%q", r[2]))
  assert(r[3] == "  c", string.format("%q", r[3]))
  assert(r[4] == "  └── d", string.format("%q", r[4]))
end)

test("convert only blank lines errors without changes", function()
  set_lines({ "hello", "", "   ", "world" })
  local before = buf_lines()
  local ok, err_line, err_msg = convert.convert_range(0, 2, 3)
  assert(ok == false)
  assert(err_line == 2, tostring(err_line))
  assert(err_msg:find("no non-blank", 1, true))
  assert(vim.deep_equal(buf_lines(), before))
end)

test("convert extreme mixed margin unit", function()
  set_lines({ "   src", "     \t  a", "     \t  b", "     \t    \t  c" })
  local ok = assert(convert.convert_range(0, 1, 4))
  assert(ok)
  local r = buf_lines()
  assert(r[1] == "   src", string.format("%q", r[1]))
  assert(r[2] == "   ├── a", string.format("%q", r[2]))
  assert(r[3] == "   └── b", string.format("%q", r[3]))
  assert(r[4] == "       └── c", string.format("%q", r[4]))
end)

io.write(string.format("%d passed, %d failed\n", passed, failed))
for _, f in ipairs(failures) do
  io.write("FAIL: " .. f .. "\n")
end
vim.cmd("qa!")
