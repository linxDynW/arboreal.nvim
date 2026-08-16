package.path = "./?.lua;" .. package.path
local t = require("tests.support")

local test = t.test
local buf_lines = t.buf_lines
local set_lines = t.set_lines
local keys = t.keys
local cursor = t.cursor
local setup_toggle = t.setup_toggle
local TREE = t.TREE

test("o on last tree line escapes with blank line", function()
  setup_toggle(true)
  set_lines(TREE)
  cursor(4, 0)
  keys("onew<Esc>")
  local r = buf_lines()
  assert(r[4] == "└── b" and r[5] == "new", table.concat(r, "|"))
end)

test("o on last node with text below creates node", function()
  setup_toggle(true)
  set_lines({ "src", "├── a", "└── b", "after" })
  cursor(3, 0)
  keys("onew<Esc>")
  local r = buf_lines()
  assert(
    r[3] == "├── b" and r[4] == "└── new" and r[5] == "after",
    table.concat(r, "|")
  )
end)

test("3o creates three siblings", function()
  setup_toggle(true)
  set_lines({ "src", "├── a", "└── b" })
  cursor(2, 0)
  keys("3o<Esc>")
  local r = buf_lines()
  assert(
    #r == 6
      and r[1] == "src"
      and r[2] == "├── a"
      and r[3] == "│"
      and r[4] == "│"
      and r[5] == "│"
      and r[6] == "└── b",
    table.concat(r, "|")
  )
end)

test("O creates sibling above", function()
  setup_toggle(true)
  set_lines({ "src", "├── a", "└── b" })
  cursor(3, 0)
  keys("Onew<Esc>")
  local r = buf_lines()
  assert(
    r[1] == "src" and r[2] == "├── a" and r[3] == "├── new" and r[4] == "└── b",
    table.concat(r, "|")
  )
end)

test("O on root falls back to blank line above", function()
  setup_toggle(true)
  set_lines(TREE)
  cursor(1, 0)
  keys("O")
  local r = buf_lines()
  assert(r[1] == "" and r[2] == "src", table.concat(r, "|"))
end)

test("normal o on plain line falls back", function()
  setup_toggle(true)
  set_lines({ "hello" })
  cursor(1, 0)
  keys("o")
  local r = buf_lines()
  assert(r[1] == "hello" and r[2] == "", table.concat(r, "|"))
end)

test("normal dd merges dir children", function()
  setup_toggle(true)
  set_lines(TREE)
  cursor(2, 0)
  keys("dd")
  local r = buf_lines()
  assert(r[2] == "├── x" and r[3] == "└── b", table.concat(r, "|"))
end)

test("normal dd on leaf", function()
  setup_toggle(true)
  set_lines(TREE)
  cursor(4, 0)
  keys("dd")
  local r = buf_lines()
  assert(#r == 3 and r[2] == "└── a", table.concat(r, "|"))
end)

test("normal dd on root deletes line natively", function()
  setup_toggle(true)
  set_lines(TREE)
  cursor(1, 0)
  keys("dd")
  local r = buf_lines()
  assert(#r == 3 and r[1] == "├── a", table.concat(r, "|"))
end)

test("normal dd on plain line falls back", function()
  setup_toggle(true)
  set_lines({ "hello", "world" })
  cursor(1, 0)
  keys("dd")
  local r = buf_lines()
  assert(#r == 1 and r[1] == "world")
end)

test("2dd deletes two physical lines", function()
  setup_toggle(true)
  set_lines({ "src", "├── a", "│   └── x", "└── b" })
  cursor(2, 0)
  keys("2dd")
  local r = buf_lines()
  assert(r[1] == "src" and r[2] == "└── b", table.concat(r, "|"))
end)

test("normal x blocked in tree", function()
  setup_toggle(true)
  set_lines(TREE)
  cursor(2, 0)
  keys("x")
  assert(buf_lines()[2] == "├── a")
end)

test("repeated connector block notifies once with Arb off hint", function()
  setup_toggle(true)
  set_lines(TREE)
  cursor(2, 0)
  local orig = vim.notify
  local count = 0
  local msg = nil
  vim.notify = function(m)
    count = count + 1
    msg = m
  end
  keys("xxx")
  vim.notify = orig
  assert(count == 1, "expected one notification, got " .. tostring(count))
  assert(msg and msg:find(":Arb off", 1, true) ~= nil, tostring(msg))
  assert(msg and msg:find("\n", 1, true) ~= nil, tostring(msg))
  assert(buf_lines()[2] == "├── a", buf_lines()[2])
end)

test("normal x works outside tree", function()
  setup_toggle(true)
  set_lines({ "hello" })
  cursor(1, 0)
  keys("x")
  assert(buf_lines()[1] == "ello")
end)

test("toggle off restores plain text behavior", function()
  setup_toggle(false)
  set_lines(TREE)
  cursor(2, 0)
  keys("i<CR>")
  local r = buf_lines()
  assert(r[2] == "" and r[3] == "├── a", table.concat(r, "|"))
end)

test("normal mode cursor move does not expand empty leaf", function()
  setup_toggle(true)
  set_lines({ "src", "├── a", "│", "└── b" })
  cursor(3, 0)
  assert(buf_lines()[3] == "│", buf_lines()[3])
end)

test("r and s blocked in tree", function()
  setup_toggle(true)
  set_lines(TREE)
  cursor(2, 0)
  keys("rX")
  assert(buf_lines()[2] == "├── a")
  keys("sY")
  assert(buf_lines()[2] == "├── a")
end)

test("normal r blocked consumes replacement char", function()
  setup_toggle(true)
  set_lines({ "src", "├── abc", "└── c" })
  cursor(2, 3)
  keys("rX")
  assert(buf_lines()[2] == "├── abc", buf_lines()[2])
end)

test("normal >> and << shift line", function()
  setup_toggle(true)
  set_lines({ "src", "├── a", "│   └── x", "└── b" })
  cursor(3, 0)
  keys("<<")
  local r = buf_lines()
  assert(
    r[2] == "├── a" and r[3] == "├── x" and r[4] == "└── b",
    table.concat(r, "|")
  )
  cursor(3, 0)
  keys(">>")
  r = buf_lines()
  assert(r[3] == "│   └── x", table.concat(r, "|"))
end)

test("normal >> on plain text falls back", function()
  setup_toggle(true)
  set_lines({ "one", "two" })
  cursor(1, 0)
  keys(">>")
  local r = buf_lines()
  assert(r[1]:find("^[ \t]+one$"), table.concat(r, "|"))
end)

test("2<< outdents two sibling lines", function()
  setup_toggle(true)
  set_lines({ "src", "└── a", "    ├── b", "    └── c" })
  cursor(3, 0)
  keys("2<<")
  local r = buf_lines()
  assert(
    r[1] == "src" and r[2] == "├── a" and r[3] == "├── b" and r[4] == "└── c",
    table.concat(r, "|")
  )
end)

test("D blocked in connector area", function()
  setup_toggle(true)
  set_lines({ "src", "├── aaa", "└── c" })
  cursor(2, 0)
  local notified = false
  vim.notify = function(msg)
    if msg:find("blocked", 1, true) then
      notified = true
    end
  end
  keys("D")
  assert(notified)
  assert(buf_lines()[2] == "├── aaa", buf_lines()[2])
end)

test("D in name area deletes to end", function()
  setup_toggle(true)
  set_lines({ "src", "├── aaa", "└── c" })
  cursor(2, 11)
  keys("D")
  assert(buf_lines()[2] == "├── a", buf_lines()[2])
end)

test(">> on directory moves line, children stay", function()
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
  keys(">>")
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

test("J merges sibling names", function()
  setup_toggle(true)
  set_lines({ "src", "├── a", "└── b" })
  cursor(2, 0)
  keys("J")
  local r = buf_lines()
  assert(r[2] == "└── a b", table.concat(r, "|"))
end)

test("J with count merges multiple", function()
  setup_toggle(true)
  set_lines({ "src", "├── a", "├── b", "├── c", "└── d" })
  cursor(2, 0)
  keys("3J")
  local r = buf_lines()
  assert(r[2] == "├── a b c" and r[3] == "└── d", table.concat(r, "|"))
end)

test("gJ merges without space", function()
  setup_toggle(true)
  set_lines({ "src", "├── a", "└── b" })
  cursor(2, 0)
  keys("gJ")
  assert(buf_lines()[2] == "└── ab", buf_lines()[2])
end)

test("J on dir attaches its children", function()
  setup_toggle(true)
  set_lines({ "src", "├── a", "│   └── x", "└── b" })
  cursor(2, 0)
  keys("J")
  local r = buf_lines()
  assert(r[2] == "├── a x" and r[3] == "└── b", table.concat(r, "|"))
end)

test("J on plain text falls back", function()
  setup_toggle(true)
  set_lines({ "one", "two" })
  cursor(1, 0)
  keys("J")
  assert(buf_lines()[1] == "one two")
end)

test("cw inside name changes natively", function()
  setup_toggle(true)
  set_lines({ "src", "├── aaa bbb", "└── c" })
  cursor(2, 10)
  keys("cwXXX<Esc>")
  assert(buf_lines()[2] == "├── XXX bbb", buf_lines()[2])
end)

test("c0 into connector is blocked", function()
  setup_toggle(true)
  set_lines({ "src", "├── aaa", "└── c" })
  cursor(2, 12)
  local notified = false
  vim.notify = function(msg)
    if msg:find("damage", 1, true) then
      notified = true
    end
  end
  keys("c0")
  assert(notified)
  assert(buf_lines()[2] == "├── aaa", buf_lines()[2])
end)

test("cc on node clears name and inserts", function()
  setup_toggle(true)
  set_lines({ "src", "├── abc", "└── c" })
  cursor(2, 10)
  keys("ccXYZ<Esc>")
  assert(buf_lines()[2] == "├── XYZ", buf_lines()[2])
end)

test("cc undo restores the original name in one step", function()
  setup_toggle(true)
  set_lines({ "src", "├── abc", "└── c" })
  cursor(2, 10)
  keys("ccXYZ<Esc>")
  assert(buf_lines()[2] == "├── XYZ", buf_lines()[2])
  keys("u")
  assert(buf_lines()[2] == "├── abc", buf_lines()[2])
end)

test("cc redo and dot repeat work", function()
  setup_toggle(true)
  set_lines({ "src", "├── abc", "└── d" })
  cursor(2, 10)
  keys("ccXYZ<Esc>")
  keys("u")
  assert(buf_lines()[2] == "├── abc", buf_lines()[2])
  keys("<C-r>")
  assert(buf_lines()[2] == "├── XYZ", buf_lines()[2])
  cursor(3, 10)
  keys(".")
  assert(buf_lines()[3] == "└── XYZ", buf_lines()[3])
end)

test("cw on plain text changes natively", function()
  setup_toggle(true)
  set_lines({ "one two" })
  cursor(1, 0)
  keys("cwXXX<Esc>")
  assert(buf_lines()[1] == "XXX two", buf_lines()[1])
end)

test("cc on plain text changes line natively", function()
  setup_toggle(true)
  set_lines({ "one", "two" })
  cursor(1, 0)
  keys("ccXXX<Esc>")
  local r = buf_lines()
  assert(r[1] == "XXX" and r[2] == "two", table.concat(r, "|"))
end)

test("C S R blocked in tree, work on plain text", function()
  setup_toggle(true)
  set_lines({ "src", "├── aaa", "└── c" })
  cursor(2, 0)
  local blocked = false
  vim.notify = function(msg)
    if msg:find("blocked", 1, true) then
      blocked = true
    end
  end
  keys("C")
  assert(blocked and buf_lines()[2] == "├── aaa")
  blocked = false
  keys("S")
  assert(blocked and buf_lines()[2] == "├── aaa")
  blocked = false
  keys("R")
  assert(blocked and buf_lines()[2] == "├── aaa")
  set_lines({ "hello" })
  cursor(1, 0)
  keys("Cworld<Esc>")
  assert(buf_lines()[1] == "world")
end)

test("cc on node clears name and inserts", function()
  setup_toggle(true)
  set_lines({ "src", "├── abc", "└── c" })
  cursor(2, 10)
  keys("ccXYZ<Esc>")
  assert(buf_lines()[2] == "├── XYZ", buf_lines()[2])
end)

test("cc on root falls back to native", function()
  setup_toggle(true)
  set_lines({ "src", "└── a" })
  cursor(1, 0)
  keys("ccXYZ<Esc>")
  assert(buf_lines()[1] == "XYZ", buf_lines()[1])
end)

test("x on name deletes char, blocked on connector", function()
  setup_toggle(true)
  set_lines({ "src", "├── abc", "└── c" })
  cursor(2, 11)
  keys("x")
  assert(buf_lines()[2] == "├── ac", buf_lines()[2])
  cursor(2, 0)
  local notified = false
  vim.notify = function(msg)
    if msg:find("connector", 1, true) then
      notified = true
    end
  end
  keys("x")
  assert(notified)
  assert(buf_lines()[2] == "├── ac", buf_lines()[2])
end)

test("r on name replaces, blocked on connector", function()
  setup_toggle(true)
  set_lines({ "src", "├── abc", "└── c" })
  cursor(2, 11)
  keys("rX")
  assert(buf_lines()[2] == "├── aXc", buf_lines()[2])
  cursor(2, 0)
  local notified = false
  vim.notify = function(msg)
    if msg:find("connector", 1, true) then
      notified = true
    end
  end
  keys("rY")
  assert(notified)
  assert(buf_lines()[2] == "├── aXc", buf_lines()[2])
end)

test("s on name substitutes and inserts", function()
  setup_toggle(true)
  set_lines({ "src", "├── abc", "└── c" })
  cursor(2, 11)
  keys("sX<Esc>")
  assert(buf_lines()[2] == "├── aXc", buf_lines()[2])
end)

test("s undo restores the original name in one step", function()
  setup_toggle(true)
  set_lines({ "src", "├── abc", "└── c" })
  cursor(2, 11)
  keys("sXYZ<Esc>")
  assert(buf_lines()[2] == "├── aXYZc", buf_lines()[2])
  keys("u")
  assert(buf_lines()[2] == "├── abc", buf_lines()[2])
end)

test(">> on root indents only the root line", function()
  setup_toggle(true)
  set_lines({ "src", "└── a" })
  cursor(1, 0)
  keys(">>")
  local r = buf_lines()
  assert(r[1]:find("^[ \t]+src$") and r[2] == "└── a", table.concat(r, "|"))
  keys("<<")
  r = buf_lines()
  assert(r[1] == "src" and r[2] == "└── a", table.concat(r, "|"))
end)

test("o on root opens blank line natively", function()
  setup_toggle(true)
  set_lines({ "src", "└── a" })
  cursor(1, 0)
  keys("onew<Esc>")
  local r = buf_lines()
  assert(r[1] == "src" and r[2] == "new" and r[3] == "└── a", table.concat(r, "|"))
end)

test("I on root inserts at line start", function()
  setup_toggle(true)
  set_lines({ "exp", "└── a" })
  cursor(1, 0)
  keys("IX<Esc>")
  assert(buf_lines()[1] == "Xexp", buf_lines()[1])
end)

test("S on name clears name and inserts", function()
  setup_toggle(true)
  set_lines({ "src", "├── abc", "└── c" })
  cursor(2, 10)
  keys("SXYZ<Esc>")
  assert(buf_lines()[2] == "├── XYZ", buf_lines()[2])
end)

test("S undo restores the original name in one step", function()
  setup_toggle(true)
  set_lines({ "src", "├── abc", "└── c" })
  cursor(2, 10)
  keys("SXYZ<Esc>")
  assert(buf_lines()[2] == "├── XYZ", buf_lines()[2])
  keys("u")
  assert(buf_lines()[2] == "├── abc", buf_lines()[2])
end)

test("C on name changes to end of line", function()
  setup_toggle(true)
  set_lines({ "src", "├── abc", "└── c" })
  cursor(2, 11)
  keys("CX<Esc>")
  assert(buf_lines()[2] == "├── aX", buf_lines()[2])
end)

test("R on plain text replaces", function()
  setup_toggle(true)
  set_lines({ "hello" })
  cursor(1, 0)
  keys("RXY<Esc>")
  assert(buf_lines()[1] == "XYllo", buf_lines()[1])
end)

test("o on indented root opens blank line without error", function()
  setup_toggle(true)
  set_lines({ "    src", "└── a", "└── b" })
  cursor(1, 0)
  keys("onew<Esc>")
  local r = buf_lines()
  assert(
    r[1] == "    src" and r[2] == "new" and r[3] == "├── a" and r[4] == "└── b",
    table.concat(r, "|")
  )
end)

test("dd on indented root deletes natively", function()
  setup_toggle(true)
  set_lines({ "    src", "└── a" })
  cursor(1, 0)
  keys("dd")
  local r = buf_lines()
  assert(#r == 1 and r[1] == "└── a", table.concat(r, "|"))
end)

test("diw empties name and collapses line", function()
  setup_toggle(true)
  set_lines({ "src", "├── aaa", "├── bbb", "└── c" })
  cursor(2, 10)
  keys("diw")
  assert(buf_lines()[2] == "│", buf_lines()[2])
  assert(
    buf_lines()[1] == "src" and buf_lines()[4] == "└── c",
    table.concat(buf_lines(), "|")
  )
end)

test("refresh collapses name emptied by normal edit", function()
  setup_toggle(true)
  set_lines({ "src", "├── ", "├── bbb", "└── c" })
  cursor(2, 0)
  require("arboreal.tree").refresh(nil, false)
  assert(buf_lines()[2] == "│", buf_lines()[2])
end)

t.finish()
