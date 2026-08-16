package.path = "./?.lua;" .. package.path
local t = require("tests.support")

local test = t.test
local buf_lines = t.buf_lines
local set_lines = t.set_lines
local keys = t.keys
local cursor = t.cursor
local setup_toggle = t.setup_toggle
local TREE = t.TREE

test("insert Enter creates sibling", function()
  setup_toggle(true)
  set_lines(TREE)
  cursor(2, 0)
  keys("i<CR>")
  local r = buf_lines()
  assert(
    r[1] == "src"
      and r[2] == "├── a"
      and r[3] == "│   └── x"
      and r[4] == "│"
      and r[5] == "└── b",
    table.concat(r, "|")
  )
  assert(vim.api.nvim_win_get_cursor(0)[1] == 4)
end)

test("insert Enter on non-tree line falls back", function()
  setup_toggle(true)
  set_lines({ "hello", "world" })
  cursor(1, 5)
  keys("a<CR>")
  local r = buf_lines()
  assert(r[1] == "hello" and r[2] == "" and r[3] == "world", table.concat(r, "|"))
end)

test("insert Tab deepens node", function()
  setup_toggle(true)
  set_lines(TREE)
  cursor(4, 7)
  keys("i<Tab>")
  assert(buf_lines()[4] == "    └── b", buf_lines()[4])
end)

test("insert Tab blocked at limit notifies", function()
  setup_toggle(true)
  set_lines(TREE)
  cursor(3, 10)
  local notified = false
  vim.notify = function(msg)
    if msg:find("limit", 1, true) then
      notified = true
    end
  end
  keys("i<Tab>")
  assert(notified)
  assert(buf_lines()[3] == "│   └── x")
end)

test("insert Shift-Tab outdents node", function()
  setup_toggle(true)
  set_lines(TREE)
  cursor(3, 16)
  keys("a<S-Tab>")
  local r = buf_lines()
  assert(
    r[1] == "src" and r[2] == "├── a" and r[3] == "├── x" and r[4] == "└── b",
    table.concat(r, "|")
  )
end)

test("insert Shift-Tab blocked on directory", function()
  setup_toggle(true)
  set_lines(TREE)
  cursor(2, 9)
  local notified = false
  vim.notify = function(msg)
    if msg:find("children", 1, true) then
      notified = true
    end
  end
  keys("a<S-Tab>")
  assert(notified)
  assert(buf_lines()[2] == "├── a", buf_lines()[2])
end)

test("insert Backspace deletes name char", function()
  setup_toggle(true)
  set_lines(TREE)
  cursor(3, 16)
  keys("a<BS>")
  assert(buf_lines()[3] == "│   └── ", buf_lines()[3])
end)

test("insert Backspace on empty leaf deletes line", function()
  setup_toggle(true)
  set_lines({ "src", "├── a", "│   └── ", "└── b" })
  cursor(3, 0)
  keys("a<BS>")
  local r = buf_lines()
  assert(r[2] == "├── a" and r[3] == "└── b", table.concat(r, "|"))
  assert(vim.api.nvim_win_get_cursor(0)[1] == 2)
end)

test("insert Backspace outside tree falls back", function()
  setup_toggle(true)
  set_lines({ "hello" })
  cursor(1, 5)
  keys("a<BS>")
  assert(buf_lines()[1] == "hell")
end)

test("insert Backspace at name start is blocked silently", function()
  setup_toggle(true)
  set_lines({ "src", "├── abc", "└── b" })
  cursor(2, 10)
  local orig = vim.notify
  local notified = 0
  vim.notify = function()
    notified = notified + 1
  end
  keys("i<BS><Esc>")
  vim.notify = orig
  assert(notified == 0, "expected no notification, got " .. tostring(notified))
  assert(buf_lines()[2] == "├── abc", buf_lines()[2])
end)

test("insert Backspace on empty directory is blocked", function()
  setup_toggle(true)
  set_lines({ "src", "├── ", "│   └── x", "└── b" })
  cursor(2, 10)
  keys("a<BS><Esc>")
  assert(buf_lines()[2] == "├── ", buf_lines()[2])
end)

test("insert Backspace mid name deletes char before cursor", function()
  setup_toggle(true)
  set_lines({ "src", "├── abc", "└── b" })
  cursor(2, 11)
  keys("i<BS><Esc>")
  assert(buf_lines()[2] == "├── bc", buf_lines()[2])
end)

test("normal o creates sibling and enters insert", function()
  setup_toggle(true)
  set_lines(TREE)
  cursor(2, 0)
  keys("onew<Esc>")
  local r = buf_lines()
  assert(
    r[2] == "├── a"
      and r[3] == "│   └── x"
      and r[4] == "├── new"
      and r[5] == "└── b",
    table.concat(r, "|")
  )
end)

test("full editing session builds valid tree", function()
  setup_toggle(true)
  set_lines({ "src", "" })
  cursor(2, 0)
  keys("<leader>aimain.rs<CR>lib.rs<CR>tests<CR><Tab>integration.rs<Esc>")
  local r = buf_lines()
  assert(
    r[1] == "src"
      and r[2] == "├── main.rs"
      and r[3] == "├── lib.rs"
      and r[4] == "└── tests"
      and r[5] == "    └── integration.rs",
    table.concat(r, "|")
  )
end)

test("typing into collapsed line expands connector", function()
  setup_toggle(true)
  set_lines({ "src", "├── a", "│", "└── b" })
  cursor(3, 0)
  keys("iabc<Esc>")
  local r = buf_lines()
  assert(r[3] == "├── abc", table.concat(r, "|"))
  assert(r[2] == "├── a" and r[4] == "└── b", table.concat(r, "|"))
end)

test("collapsed line re-collapses when cursor leaves", function()
  setup_toggle(true)
  set_lines({ "src", "├── a", "│", "└── b" })
  cursor(3, 0)
  require("arboreal.tree").refresh(3, false)
  assert(buf_lines()[3] == "├── ", buf_lines()[3])
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  require("arboreal.tree").refresh(2, false)
  assert(buf_lines()[3] == "│", buf_lines()[3])
end)

test("InsertLeave collapses focus", function()
  setup_toggle(true)
  set_lines({ "src", "├── a", "│", "└── b" })
  cursor(3, 0)
  require("arboreal.tree").refresh(3, true)
  assert(buf_lines()[3] == "├── ", buf_lines()[3])
  require("arboreal.tree").refresh(nil, false)
  assert(buf_lines()[3] == "│", buf_lines()[3])
end)

test("Left blocked at name start", function()
  setup_toggle(true)
  set_lines({ "src", "├── abc", "└── b" })
  cursor(2, 0)
  keys("I<Left>x<Esc>")
  assert(buf_lines()[2] == "├── xabc", buf_lines()[2])
end)

test("Home moves to name start", function()
  setup_toggle(true)
  set_lines({ "src", "├── abc", "└── b" })
  cursor(2, 0)
  keys("a<Home>z<Esc>")
  assert(buf_lines()[2] == "├── zabc", buf_lines()[2])
end)

test("Down onto tree line clamps into name area", function()
  setup_toggle(true)
  set_lines(TREE)
  cursor(2, 0)
  keys("i")
  vim.api.nvim_win_set_cursor(0, { 3, 9 })
  require("arboreal.tree").refresh(3, true)
  local c = vim.api.nvim_win_get_cursor(0)
  assert(c[1] == 3 and c[2] == 16, vim.inspect(c))
end)

test("i on connector lands in name area", function()
  setup_toggle(true)
  set_lines({ "src", "├── a", "└── b" })
  cursor(2, 0)
  keys("iz<Esc>")
  assert(buf_lines()[2] == "├── za", buf_lines()[2])
end)

test("a on connector appends at name end", function()
  setup_toggle(true)
  set_lines({ "src", "├── a", "└── b" })
  cursor(2, 0)
  keys("az<Esc>")
  assert(buf_lines()[2] == "├── az", buf_lines()[2])
end)

test("Tab outside tree inserts tab", function()
  setup_toggle(true)
  set_lines({ "hello" })
  cursor(1, 5)
  keys("a<Tab>")
  assert(buf_lines()[1]:find("hello[ \t]"), string.format("%q", buf_lines()[1]))
end)

test("Tab on root line inserts tab", function()
  setup_toggle(true)
  set_lines({ "src", "└── a" })
  cursor(1, 3)
  keys("a<Tab>")
  assert(buf_lines()[1]:find("src[ \t]"), string.format("%q", buf_lines()[1]))
end)

test("backspace mid root name deletes char natively", function()
  setup_toggle(true)
  set_lines({ "exp", "└── a" })
  cursor(1, 1)
  keys("i<BS>")
  assert(buf_lines()[1] == "xp", buf_lines()[1])
end)

test("rootless tree still editable after root indent", function()
  setup_toggle(true)
  set_lines({ "    src", "└── a", "└── b" })
  cursor(2, 0)
  keys("onew<Esc>")
  local r = buf_lines()
  assert(
    r[1] == "    src"
      and r[2] == "├── a"
      and r[3] == "├── new"
      and r[4] == "└── b",
    table.concat(r, "|")
  )
end)

test("rootless tree at buffer start is editable", function()
  setup_toggle(true)
  set_lines({ "└── a", "└── b" })
  cursor(1, 0)
  keys("onew<Esc>")
  local r = buf_lines()
  assert(
    r[1] == "├── a" and r[2] == "├── new" and r[3] == "└── b",
    table.concat(r, "|")
  )
end)

test("Enter on indented root falls back natively", function()
  setup_toggle(true)
  set_lines({ "    src", "└── a" })
  cursor(1, 6)
  keys("a<CR>")
  local r = buf_lines()
  assert(r[1] == "    src" and r[2] == "" and r[3] == "└── a", table.concat(r, "|"))
end)

t.finish()
