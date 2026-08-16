package.path = "./?.lua;" .. package.path
local t = require("tests.support")

local test = t.test
local buf_lines = t.buf_lines
local set_lines = t.set_lines
local keys = t.keys
local cursor = t.cursor
local setup_toggle = t.setup_toggle
local TREE = t.TREE

test("visual > moves subtree deeper", function()
  setup_toggle(true)
  set_lines({ "src", "├── a", "└── b", "    └── y" })
  cursor(3, 0)
  keys("Vj><Esc>")
  local r = buf_lines()
  assert(
    r[1] == "src"
      and r[2] == "└── a"
      and r[3] == "    └── b"
      and r[4] == "        └── y",
    table.concat(r, "|")
  )
end)

test("visual < moves subtree back", function()
  setup_toggle(true)
  set_lines({ "src", "└── a", "    └── b", "        └── y" })
  cursor(3, 0)
  keys("Vj<<Esc>")
  local r = buf_lines()
  assert(
    r[1] == "src" and r[2] == "├── a" and r[3] == "└── b" and r[4] == "    └── y",
    table.concat(r, "|")
  )
end)

test("visual < preserves blank lines inside the selection", function()
  setup_toggle(true)
  set_lines({ "src", "└── a", "    ├── b", "", "    └── c" })
  cursor(3, 0)
  keys("V2j<<Esc>")
  local r = buf_lines()
  assert(
    r[1] == "src"
      and r[2] == "├── a"
      and r[3] == "├── b"
      and r[4] == ""
      and r[5] == "└── c",
    table.concat(r, "|")
  )
end)

test("visual > blocked notifies and leaves buffer unchanged", function()
  setup_toggle(true)
  set_lines({ "src", "├── a", "└── b" })
  cursor(2, 0)
  local notified = false
  vim.notify = function(msg)
    if msg:find("cannot shift", 1, true) then
      notified = true
    end
  end
  keys("Vj><Esc>")
  assert(notified)
  local r = buf_lines()
  assert(r[2] == "├── a" and r[3] == "└── b", table.concat(r, "|"))
end)

test("visual > on plain text falls back to normal indent", function()
  setup_toggle(true)
  set_lines({ "one", "two" })
  cursor(1, 0)
  keys("Vj><Esc>")
  local r = buf_lines()
  assert(r[1]:find("^[ \t]+one$") and r[2]:find("^[ \t]+two$"), table.concat(r, "|"))
end)

test("visual d deletes selected nodes bottom-up", function()
  setup_toggle(true)
  set_lines({ "src", "├── a", "│   └── x", "└── b" })
  cursor(2, 0)
  keys("Vjd")
  local r = buf_lines()
  assert(r[1] == "src" and r[2] == "└── b", table.concat(r, "|"))
end)

test("visual d deletes whole tree including root", function()
  setup_toggle(true)
  set_lines(TREE)
  cursor(1, 0)
  keys("V3jd")
  local r = buf_lines()
  assert(#r == 1 and r[1] == "", table.concat(r, "|"))
end)

test("visual d on plain text falls back", function()
  setup_toggle(true)
  set_lines({ "one", "two", "three" })
  cursor(1, 0)
  keys("Vjd")
  local r = buf_lines()
  assert(#r == 1 and r[1] == "three", table.concat(r, "|"))
end)

test("blockwise visual d on connectors is blocked", function()
  setup_toggle(true)
  set_lines({ "src", "├── a", "└── b" })
  cursor(2, 0)
  local notified = false
  vim.notify = function(msg)
    if msg:find("damage", 1, true) then
      notified = true
    end
  end
  keys("<C-V>jd")
  assert(notified)
  assert(#buf_lines() == 3, table.concat(buf_lines(), "|"))
  assert(buf_lines()[2] == "├── a", buf_lines()[2])
end)

test("characterwise visual d on connectors is blocked", function()
  setup_toggle(true)
  set_lines({ "src", "├── a", "└── b" })
  cursor(2, 0)
  keys("vjd")
  assert(#buf_lines() == 3, table.concat(buf_lines(), "|"))
  assert(buf_lines()[2] == "├── a", buf_lines()[2])
end)

test("blockwise visual d inside names deletes the block", function()
  setup_toggle(true)
  set_lines({ "src", "├── ab", "└── cd" })
  cursor(2, 10)
  keys("<C-V>jd")
  local r = buf_lines()
  assert(r[2] == "├── b" and r[3] == "└── d", table.concat(r, "|"))
end)

test("operator >j shifts motion range structurally", function()
  setup_toggle(true)
  set_lines({ "src", "├── a", "└── b", "    └── y" })
  cursor(3, 0)
  keys(">j")
  local r = buf_lines()
  assert(
    r[1] == "src"
      and r[2] == "└── a"
      and r[3] == "    └── b"
      and r[4] == "        └── y",
    table.concat(r, "|")
  )
end)

test("operator <j shifts back", function()
  setup_toggle(true)
  set_lines({ "src", "└── a", "    └── b", "        └── y" })
  cursor(3, 0)
  keys("<j")
  local r = buf_lines()
  assert(
    r[1] == "src" and r[2] == "├── a" and r[3] == "└── b" and r[4] == "    └── y",
    table.concat(r, "|")
  )
end)

test("operator >j on plain text falls back to indent", function()
  setup_toggle(true)
  set_lines({ "one", "two" })
  cursor(1, 0)
  keys(">j")
  local r = buf_lines()
  assert(r[1]:find("^[ \t]+one$") and r[2]:find("^[ \t]+two$"), table.concat(r, "|"))
end)

test("operator >j blocked notifies and leaves buffer", function()
  setup_toggle(true)
  set_lines({ "src", "├── a", "└── b" })
  cursor(2, 0)
  local notified = false
  vim.notify = function(msg)
    if msg:find("cannot shift", 1, true) then
      notified = true
    end
  end
  keys(">j")
  assert(notified)
  local r = buf_lines()
  assert(r[2] == "├── a" and r[3] == "└── b", table.concat(r, "|"))
end)

test("visual d confirms when children would merge", function()
  setup_toggle(true)
  require("arboreal").setup({ confirm_directory_delete = true })
  set_lines({ "src", "├── a", "│   ├── x", "│   └── y", "└── b" })
  cursor(2, 0)
  local asked = false
  vim.fn.confirm = function(msg)
    asked = msg:find("merge", 1, true) ~= nil
    return 1
  end
  keys("Vjd")
  assert(asked)
  local r = buf_lines()
  assert(r[1] == "src" and r[2] == "├── y" and r[3] == "└── b", table.concat(r, "|"))
end)

test("visual d cancel keeps selection content", function()
  setup_toggle(true)
  require("arboreal").setup({ confirm_directory_delete = true })
  set_lines({ "src", "├── a", "│   ├── x", "│   └── y", "└── b" })
  cursor(2, 0)
  vim.fn.confirm = function()
    return 2
  end
  keys("Vjd<Esc>")
  assert(#buf_lines() == 5)
end)

test("visual d no confirm without merge", function()
  setup_toggle(true)
  set_lines({ "src", "├── a", "│   └── x", "└── b" })
  cursor(2, 0)
  local asked = false
  vim.fn.confirm = function()
    asked = true
    return 1
  end
  keys("V2jd")
  assert(not asked)
  local r = buf_lines()
  assert(#r == 1 and r[1] == "src", table.concat(r, "|"))
end)

test("operator dj deletes structurally with confirm", function()
  setup_toggle(true)
  require("arboreal").setup({ confirm_directory_delete = true })
  set_lines({ "src", "├── a", "│   ├── x", "│   └── y", "└── b" })
  cursor(2, 0)
  local asked = false
  vim.fn.confirm = function(msg)
    asked = msg:find("merge", 1, true) ~= nil
    return 1
  end
  keys("dj")
  assert(asked)
  local r = buf_lines()
  assert(r[1] == "src" and r[2] == "├── y" and r[3] == "└── b", table.concat(r, "|"))
end)

test("operator dj on plain text falls back to native delete", function()
  setup_toggle(true)
  set_lines({ "one", "two", "three" })
  cursor(1, 0)
  keys("dj")
  local r = buf_lines()
  assert(#r == 1 and r[1] == "three", table.concat(r, "|"))
end)

test("operator d with blockwise motion on tree is blocked", function()
  setup_toggle(true)
  set_lines({ "src", "├── a", "└── b" })
  cursor(2, 0)
  local notified = false
  vim.notify = function(msg)
    if msg:find("damage", 1, true) then
      notified = true
    end
  end
  keys("d<C-V>j")
  assert(notified)
  assert(buf_lines()[2] == "├── a", buf_lines()[2])
  assert(#buf_lines() == 3, table.concat(buf_lines(), "|"))
end)

test("operator dw on plain text falls back to native delete", function()
  setup_toggle(true)
  set_lines({ "one two" })
  cursor(1, 0)
  keys("dw")
  assert(buf_lines()[1] == "two", buf_lines()[1])
end)

test("operator dw inside name deletes word natively", function()
  setup_toggle(true)
  set_lines({ "src", "├── aaa bbb", "└── c" })
  cursor(2, 10)
  keys("dw")
  assert(buf_lines()[2] == "├── bbb", buf_lines()[2])
end)

test("operator d0 into connector is blocked", function()
  setup_toggle(true)
  set_lines({ "src", "├── aaa", "└── c" })
  cursor(2, 12)
  local notified = false
  vim.notify = function(msg)
    if msg:find("damage", 1, true) then
      notified = true
    end
  end
  keys("d0")
  assert(notified)
  assert(buf_lines()[2] == "├── aaa", buf_lines()[2])
end)

test("visual > on directory moves line, children stay", function()
  setup_toggle(true)
  set_lines({
    "src",
    "├── a",
    "│   └── b",
    "├── c",
    "│   └── d",
    "└── e",
  })
  cursor(4, 0)
  keys("V><Esc>")
  local r = buf_lines()
  assert(
    r[2] == "├── a"
      and r[3] == "│   ├── b"
      and r[4] == "│   ├── c"
      and r[5] == "│   └── d"
      and r[6] == "└── e",
    table.concat(r, "|")
  )
end)

test("visual J joins selection top-down", function()
  setup_toggle(true)
  set_lines({ "src", "├── a", "├── b", "└── c" })
  cursor(2, 0)
  keys("V2jJ")
  local r = buf_lines()
  assert(r[2] == "└── a b c", table.concat(r, "|"))
end)

test("visual c on format symbols blocked", function()
  setup_toggle(true)
  set_lines(TREE)
  cursor(2, 0)
  local notified = false
  vim.notify = function(msg)
    if msg:find("damage", 1, true) then
      notified = true
    end
  end
  keys("vjjc<Esc>")
  assert(notified)
  assert(buf_lines()[2] == "├── a", buf_lines()[2])
end)

test("visual c within name changes", function()
  setup_toggle(true)
  set_lines({ "src", "├── aaa bbb", "└── c" })
  cursor(2, 10)
  keys("vecX<Esc>")
  assert(buf_lines()[2] == "├── Xa bbb", buf_lines()[2])
end)

test("visual x on format blocked, in name deletes", function()
  setup_toggle(true)
  set_lines({ "src", "├── aaa", "└── c" })
  cursor(2, 0)
  local notified = false
  vim.notify = function(msg)
    if msg:find("damage", 1, true) then
      notified = true
    end
  end
  keys("vllx<Esc>")
  assert(notified)
  assert(buf_lines()[2] == "├── aaa")
  notified = false
  cursor(2, 10)
  keys("vllx")
  assert(not notified)
  assert(buf_lines()[2] == "├── ", buf_lines()[2])
end)

test("V-line c on tree lines blocked", function()
  setup_toggle(true)
  set_lines(TREE)
  cursor(2, 0)
  local notified = false
  vim.notify = function(msg)
    if msg:find("damage", 1, true) then
      notified = true
    end
  end
  keys("Vjc<Esc>")
  assert(notified)
  assert(#buf_lines() == 4)
end)

test("visual gJ joins selected nodes without separator", function()
  setup_toggle(true)
  set_lines({ "src", "├── a", "└── b" })
  cursor(2, 0)
  keys("VjgJ")
  local r = buf_lines()
  assert(r[1] == "src" and r[2] == "└── ab", table.concat(r, "|"))
end)

test("visual C changes to end of name line", function()
  setup_toggle(true)
  set_lines({ "src", "├── abc", "└── c" })
  cursor(2, 11)
  keys("vllCX<Esc>")
  assert(buf_lines()[2] == "├── Xa", buf_lines()[2])
end)

test("visual D deletes selected name chars safely", function()
  setup_toggle(true)
  set_lines({ "src", "├── abc", "└── c" })
  cursor(2, 11)
  keys("vllD")
  local r = buf_lines()
  assert(r[1] == "src" and r[2] == "├── a" and r[3] == "└── c", table.concat(r, "|"))
end)

test("blocked visual r c s C swallow pending keys", function()
  setup_toggle(true)
  set_lines({ "src", "├── abc", "└── c" })
  cursor(2, 0)
  cursor(2, 0)
  keys("vllrX")
  assert(buf_lines()[2] == "├── abc", buf_lines()[2])
  cursor(2, 0)
  keys("vllcXYZ<Esc>")
  assert(buf_lines()[2] == "├── abc", buf_lines()[2])
  cursor(2, 0)
  keys("vllsXYZ<Esc>")
  assert(buf_lines()[2] == "├── abc", buf_lines()[2])
  cursor(2, 0)
  keys("vllCXYZ<Esc>")
  assert(buf_lines()[2] == "├── abc", buf_lines()[2])
  assert(vim.fn.mode() == "n", vim.fn.mode())
end)

test("visual paste on format blocked, in name pastes", function()
  setup_toggle(true)
  set_lines({ "src", "├── abc", "└── c" })
  vim.fn.setreg('"', "XYZ", "v")
  cursor(2, 0)
  local notified = false
  vim.notify = function(msg)
    if msg:find("paste", 1, true) then
      notified = true
    end
  end
  keys("vllp")
  assert(notified)
  assert(buf_lines()[2] == "├── abc", buf_lines()[2])
  cursor(2, 11)
  keys("vlp")
  assert(buf_lines()[2] == "├── aXYZ", buf_lines()[2])
end)

test("visual P on format blocked, in name pastes", function()
  setup_toggle(true)
  set_lines({ "src", "├── abc", "└── c" })
  vim.fn.setreg('"', "XYZ", "v")
  cursor(2, 0)
  local notified = false
  vim.notify = function(msg)
    if msg:find("paste", 1, true) then
      notified = true
    end
  end
  keys("vllP")
  assert(notified)
  assert(buf_lines()[2] == "├── abc", buf_lines()[2])
  cursor(2, 11)
  keys("vlP")
  assert(buf_lines()[2] == "├── aXYZ", buf_lines()[2])
end)

test("visual c zero-width selection deletes char under cursor", function()
  setup_toggle(true)
  set_lines({ "src", "├── abc", "└── c" })
  cursor(2, 11)
  keys("vcX<Esc>")
  assert(buf_lines()[2] == "├── aXc", buf_lines()[2])
end)

test("visual > with root indents selection only", function()
  setup_toggle(true)
  set_lines({ "src", "└── a" })
  cursor(1, 0)
  keys("V><Esc>")
  local r = buf_lines()
  assert(r[1]:find("^[ \t]+src$") and r[2] == "└── a", table.concat(r, "|"))
end)

test("visual < on last deep line outdents structurally", function()
  setup_toggle(true)
  set_lines({ "k", "├── k", "│   └── k", "└── k", "    └── k" })
  cursor(5, 0)
  keys("V<<Esc>")
  local r = buf_lines()
  assert(
    r[1] == "k"
      and r[2] == "├── k"
      and r[3] == "│   └── k"
      and r[4] == "├── k"
      and r[5] == "└── k",
    table.concat(r, "|")
  )
  assert(vim.api.nvim_win_get_cursor(0)[1] == 5, vim.inspect(vim.api.nvim_win_get_cursor(0)))
end)

test("visual > on last deep line is blocked, tree intact", function()
  setup_toggle(true)
  set_lines({ "k", "├── k", "│   └── k", "└── k", "    └── k" })
  cursor(5, 0)
  local notified = false
  vim.notify = function(msg)
    if msg:find("cannot shift", 1, true) then
      notified = true
    end
  end
  keys("V><Esc>")
  assert(notified)
  local r = buf_lines()
  assert(r[5] == "    └── k" and r[1] == "k", table.concat(r, "|"))
end)

t.finish()
