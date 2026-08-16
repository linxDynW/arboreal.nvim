package.path = "./?.lua;" .. package.path
local t = require("tests.support")

local test = t.test
local buf_lines = t.buf_lines
local set_lines = t.set_lines
local keys = t.keys
local cursor = t.cursor
local setup_toggle = t.setup_toggle

test("leader ai marks entry and starts tree", function()
  setup_toggle(true)
  set_lines({ "src", "" })
  cursor(2, 0)
  keys("<leader>aifoo<Esc>")
  local r = buf_lines()
  assert(r[2] == "└── foo", table.concat(r, "|"))
end)

test("leader ai blocked without line above", function()
  setup_toggle(true)
  set_lines({ "", "x" })
  cursor(2, 0)
  local notified = false
  vim.notify = function(msg)
    if msg:find("above", 1, true) then
      notified = true
    end
  end
  keys("<leader>ai")
  assert(notified)
end)

test("leader ut toggles", function()
  setup_toggle(true)
  keys("<leader>ut")
  assert(vim.b.arboreal_enabled == false)
  keys("<leader>ut")
  assert(vim.b.arboreal_enabled == true)
end)

test("paste deep node under shallow blocked", function()
  setup_toggle(true)
  set_lines({ "exp", "└── a", "    └── b", "        └── c" })
  vim.fn.setreg('"', "        └── c\n", "V")
  cursor(2, 0)
  local notified = false
  vim.notify = function(msg)
    if msg:find("paste", 1, true) then
      notified = true
    end
  end
  keys("p")
  assert(notified)
  assert(#buf_lines() == 4)
end)

test("paste sibling node allowed and re-rendered", function()
  setup_toggle(true)
  set_lines({ "exp", "└── a", "    └── b" })
  vim.fn.setreg('"', "└── c\n", "V")
  cursor(2, 0)
  local notified = false
  vim.notify = function(msg)
    if msg:find("paste", 1, true) then
      notified = true
    end
  end
  keys("p")
  assert(not notified)
  local r = buf_lines()
  assert(
    r[1] == "exp" and r[2] == "├── a" and r[3] == "└── c" and r[4] == "    └── b",
    table.concat(r, "|")
  )
end)

test("paste sibling node above allowed and re-rendered", function()
  setup_toggle(true)
  set_lines({ "exp", "└── a", "└── b" })
  vim.fn.setreg('"', "└── c\n", "V")
  cursor(2, 0)
  keys("P")
  local r = buf_lines()
  assert(
    r[1] == "exp" and r[2] == "├── c" and r[3] == "├── a" and r[4] == "└── b",
    table.concat(r, "|")
  )
end)

test("paste deep node above shallow blocked", function()
  setup_toggle(true)
  set_lines({ "exp", "└── a", "    └── b", "        └── c" })
  vim.fn.setreg('"', "        └── c\n", "V")
  cursor(2, 0)
  local notified = false
  vim.notify = function(msg)
    if msg:find("paste", 1, true) then
      notified = true
    end
  end
  keys("P")
  assert(notified)
  assert(#buf_lines() == 4, table.concat(buf_lines(), "|"))
end)

test("Arb c converts selection range", function()
  setup_toggle(true)
  set_lines({ "x", "src", "    a", "y" })
  vim.cmd("2,3Arb c")
  local r = buf_lines()
  assert(r[2] == "src" and r[3] == "└── a", table.concat(r, "|"))
end)

test("Arb i inserts marker and enters insert", function()
  setup_toggle(true)
  set_lines({ "src", "" })
  cursor(2, 0)
  vim.cmd("Arb i")
  assert(buf_lines()[2] == "└── ", buf_lines()[2])
  assert(vim.api.nvim_win_get_cursor(0)[1] == 2)
end)

test("Arb i blocked without line above", function()
  setup_toggle(true)
  set_lines({ "", "x" })
  cursor(2, 0)
  local notified = false
  vim.notify = function(msg)
    if msg:find("above", 1, true) then
      notified = true
    end
  end
  vim.cmd("Arb i")
  assert(notified)
end)

test("Arb on and off toggle editing", function()
  setup_toggle(true)
  vim.cmd("Arb off")
  assert(vim.b.arboreal_enabled == false)
  vim.cmd("Arb on")
  assert(vim.b.arboreal_enabled == true)
end)

test("configured insert/toggle keys keep their descriptions", function()
  setup_toggle(true)
  local maps = vim.api.nvim_get_keymap("n")
  local function has_desc(desc)
    for _, m in ipairs(maps) do
      if m.desc == desc then
        return true
      end
    end
    return false
  end
  assert(has_desc("Arboreal: mark line as tree entry"))
  assert(has_desc("Arboreal: toggle tree editing"))
end)

test("default config leaves insert/toggle keys unmapped", function()
  local d = require("arboreal.config").defaults
  assert(d.insert_key == false and d.toggle_key == false)
  assert(d.convert_key == "<leader>at")
end)

t.finish()
