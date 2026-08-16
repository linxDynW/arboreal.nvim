package.path = "./lua/?.lua;" .. package.path
local parse = require("arboreal.parse")
local render = require("arboreal.render")
local detect = require("arboreal.detect")
local edit = require("arboreal.edit")

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

local function assert_fail(msg, res, line, err)
  assert(res == nil, msg)
  assert(type(line) == "number", msg .. " (line)")
  assert(type(err) == "string", msg .. " (msg)")
end

-- parse: basic 4-space
test("parse basic", function()
  local r = assert(parse.parse({ "src", "    main.rs", "    lib.rs", "    tests", "        a.rs" }))
  assert(r.unit == 4 and r.base == 0)
  assert(#r.nodes == 5)
  assert(r.nodes[1].level == 0 and r.nodes[1].name == "src" and r.nodes[1].line_index == 1)
  assert(r.nodes[2].level == 1 and r.nodes[2].name == "main.rs")
  assert(r.nodes[3].level == 1 and r.nodes[3].name == "lib.rs")
  assert(r.nodes[4].level == 1 and r.nodes[4].name == "tests")
  assert(r.nodes[5].level == 2 and r.nodes[5].name == "a.rs")
end)

-- parse: tab indent (unit = 1 char per level)
test("parse tab", function()
  local r = assert(parse.parse({ "src", "\ta", "\tb" }))
  assert(r.unit == 1 and r.nodes[2].level == 1 and r.nodes[3].level == 1)
end)

-- parse: odd unit (5 spaces)
test("parse odd unit", function()
  local r = assert(parse.parse({ "src", "     a", "          b" }))
  assert(r.unit == 5 and r.nodes[2].level == 1 and r.nodes[3].level == 2)
end)

-- parse: jump error
test("parse jump", function()
  local res, line, err = parse.parse({ "src", "    a", "            b" })
  assert_fail("jump", res, line, err)
  assert(line == 3 and err:match("jumps"))
end)

-- parse: non-multiple error
test("parse non-multiple", function()
  local res, line, err = parse.parse({ "src", "    a", "     b" })
  assert_fail("non-multiple", res, line, err)
  assert(line == 3 and err:match("multiple"))
end)

-- parse: line not starting with base margin error
test("parse shallower", function()
  local res, line, err = parse.parse({ "    src", "  a" })
  assert_fail("shallower", res, line, err)
  assert(line == 2 and err:find("base indent", 1, true))
end)

-- parse: base margin preserved
test("parse base margin", function()
  local r = assert(parse.parse({ "    src", "        a", "        b" }))
  assert(r.unit == 4 and r.base_str == "    ")
  assert(r.nodes[2].level == 1 and r.nodes[2].name == "a")
  assert(r.nodes[3].level == 1 and r.nodes[3].name == "b")
end)

-- parse: tab margin
test("parse tab margin", function()
  local r = assert(parse.parse({ "\tsrc", "\t\ta" }))
  assert(r.base_str == "\t" and r.unit == 1)
  assert(r.nodes[2].level == 1 and r.nodes[2].name == "a")
end)

-- parse: margin mismatch (different whitespace chars)
test("parse margin mismatch", function()
  local res, line, err = parse.parse({ "\tsrc", "    a" })
  assert_fail("margin mismatch", res, line, err)
  assert(line == 2 and err:find("base indent", 1, true))
end)

-- parse: multiple roots
test("parse multiple roots", function()
  local r = assert(parse.parse({ "src", "    a", "other", "    b" }))
  assert(#r.nodes == 4 and r.unit == 4)
  assert(r.nodes[3].level == 0 and r.nodes[3].name == "other")
  assert(r.nodes[4].level == 1 and r.nodes[4].name == "b")
end)

-- parse: multiple roots disabled
test("parse multiple roots disabled", function()
  local res, line, err = parse.parse({ "src", "    a", "other" }, { multiple_roots = false })
  assert_fail("roots disabled", res, line, err)
  assert(line == 3 and err:match("multiple roots"))
end)

-- parse: second root immediately -> unit fallback
test("parse unit fallback", function()
  local r = assert(parse.parse({ "src", "other", "    a" }, { indent = 4 }))
  assert(r.unit == 4)
  assert(r.nodes[2].level == 0 and r.nodes[3].level == 1)
end)

-- parse: blank lines skipped, line_index preserved
test("parse blank lines", function()
  local r = assert(parse.parse({ "src", "", "    a", "   ", "    b" }))
  assert(#r.nodes == 3)
  assert(r.nodes[2].line_index == 3)
  assert(r.nodes[3].line_index == 5)
end)

-- parse: single line
test("parse single line", function()
  local r = assert(parse.parse({ "src" }))
  assert(#r.nodes == 1 and r.unit == 4 and r.nodes[1].level == 0)
end)

-- parse: no non-blank lines
test("parse empty", function()
  local res, line, err = parse.parse({ "", "  " })
  assert_fail("empty", res, line, err)
  assert(err:find("no non-blank", 1, true))
end)

-- render: canonical example
test("render canonical", function()
  local nodes = {
    { level = 0, name = "src" },
    { level = 1, name = "b" },
    { level = 2, name = "c" },
    { level = 3, name = "d" },
    { level = 3, name = "e" },
    { level = 2, name = "f" },
    { level = 1, name = "g" },
  }
  local expected = {
    "src",
    "├── b",
    "│   ├── c",
    "│   │   ├── d",
    "│   │   └── e",
    "│   └── f",
    "└── g",
  }
  local out = render.render(nodes)
  assert(#out == #expected)
  for i = 1, #expected do
    assert(out[i] == expected[i], "line " .. i .. ": " .. tostring(out[i]))
  end
end)

-- render: multiple roots
test("render multiple roots", function()
  local out = render.render({
    { level = 0, name = "src" },
    { level = 1, name = "a" },
    { level = 0, name = "other" },
    { level = 1, name = "b" },
  })
  assert(
    out[1] == "src" and out[2] == "└── a" and out[3] == "other" and out[4] == "└── b",
    table.concat(out, "\n")
  )
end)

-- render: back to parent level
test("render back to parent", function()
  local out = render.render({
    { level = 0, name = "src" },
    { level = 1, name = "a" },
    { level = 1, name = "b" },
    { level = 2, name = "c" },
    { level = 1, name = "d" },
  })
  local expected = { "src", "├── a", "├── b", "│   └── c", "└── d" }
  for i = 1, #expected do
    assert(out[i] == expected[i], "line " .. i .. ": " .. tostring(out[i]))
  end
end)

-- render: empty name
test("render empty name", function()
  local out = render.render({
    { level = 0, name = "src" },
    { level = 1, name = "" },
    { level = 1, name = "x" },
  })
  assert(out[2] == "├── " and out[3] == "└── x")
end)

-- render: custom opts
test("render custom opts", function()
  local out = render.render({
    { level = 0, name = "src" },
    { level = 1, name = "a" },
    { level = 2, name = "b" },
    { level = 1, name = "c" },
  }, { branch = "+-", leaf = "`-", pipe = "|", indent = 2 })
  assert(out[1] == "src")
  assert(out[2] == "+- a")
  assert(out[3] == "| `- b")
  assert(out[4] == "`- c")
end)

-- parse: extreme - mixed margin + mixed unit (user's case: 3sp margin, "  \t  " unit)
test("parse extreme mixed margin unit", function()
  local lines = {
    "   src",
    "     \t  a",
    "     \t  b",
    "     \t    \t  c",
  }
  local r = assert(parse.parse(lines))
  assert(r.base_str == "   " and r.base == 3)
  assert(r.unit == 5, tostring(r.unit))
  assert(r.nodes[2].level == 1 and r.nodes[2].name == "a")
  assert(r.nodes[4].level == 2 and r.nodes[4].name == "c")
end)

-- parse: tab margin + space unit
test("parse tab margin space unit", function()
  local r = assert(parse.parse({ "\tsrc", "\t    a" }))
  assert(r.base_str == "\t" and r.unit == 4)
  assert(r.nodes[2].level == 1)
end)

-- parse: margin + multiple roots
test("parse margin with multiple roots", function()
  local r = assert(parse.parse({ "  a", "    b", "  c", "    d" }))
  assert(r.base_str == "  " and r.unit == 2)
  assert(#r.nodes == 4)
  assert(r.nodes[3].level == 0 and r.nodes[3].name == "c")
  assert(r.nodes[4].level == 1 and r.nodes[4].name == "d")
end)

-- parse: jump inside second tree
test("parse jump in second tree", function()
  local res, line, err = parse.parse({ "a", "    b", "c", "            d" })
  assert_fail("jump in second tree", res, line, err)
  assert(line == 4 and err:find("jumps", 1, true))
end)

-- parse: global unit enforced across trees
test("parse unit enforced across trees", function()
  local res, line, err = parse.parse({ "a", "    b", "c", "  d" })
  assert_fail("unit across trees", res, line, err)
  assert(line == 4 and err:find("multiple", 1, true))
end)

-- parse: single line with margin
test("parse single line with margin", function()
  local r = assert(parse.parse({ "   root" }))
  assert(r.base_str == "   " and #r.nodes == 1 and r.nodes[1].level == 0)
end)

-- parse: fallback unit from opts
test("parse fallback unit from opts", function()
  local r = assert(parse.parse({ "src", "other", "  a" }, { indent = 2 }))
  assert(r.unit == 2 and r.nodes[3].level == 1)
end)

-- parse: unicode names
test("parse unicode names", function()
  local r = assert(parse.parse({ "src", "    目录", "    文件" }))
  assert(r.nodes[2].name == "目录" and r.nodes[3].name == "文件")
end)

-- parse: deep chain 6 levels
test("parse deep chain", function()
  local lines =
    { "a", "    b", "        c", "            d", "                e", "                    f" }
  local r = assert(parse.parse(lines))
  assert(#r.nodes == 6 and r.unit == 4)
  for i = 1, 6 do
    assert(r.nodes[i].level == i - 1, "node " .. i .. " level " .. r.nodes[i].level)
  end
end)

test("parse indent zero clamps to one", function()
  local r = assert(parse.parse({ "a", " b" }, { indent = 0 }))
  assert(r.unit == 1 and r.nodes[2].level == 1)
end)

test("detect indent zero clamps to one", function()
  local m = assert(detect.detect({ "a", "└── b" }, 2, { indent = 0 }))
  assert(#m.nodes == 2 and m.nodes[2].level == 1)
end)

test("edit indent zero clamps to one", function()
  local nl = assert(edit.new_sibling({ "a", "└── b" }, 2, { indent = 0 }))
  assert(nl[2] == "├── b" and nl[3] == "└── ", table.concat(nl, "|"))
end)

-- render: indent = 0 clamps to 1
test("render indent clamp", function()
  local out = render.render({
    { level = 0, name = "src" },
    { level = 1, name = "a" },
    { level = 2, name = "b" },
  }, { indent = 0 })
  assert(out[1] == "src")
  assert(out[2] == "└── a")
  assert(out[3] == " └── b", string.format("%q", out[3]))
end)

-- render: indent = 1
test("render indent one", function()
  local out = render.render({
    { level = 0, name = "src" },
    { level = 1, name = "a" },
    { level = 1, name = "b" },
  }, { indent = 1 })
  assert(out[1] == "src")
  assert(out[2] == "├── a")
  assert(out[3] == "└── b")
end)

-- render: single root only
test("render single root", function()
  local out = render.render({ { level = 0, name = "src" } })
  assert(#out == 1 and out[1] == "src")
end)

-- render: deep chain
test("render deep chain", function()
  local out = render.render({
    { level = 0, name = "a" },
    { level = 1, name = "b" },
    { level = 2, name = "c" },
    { level = 3, name = "d" },
    { level = 4, name = "e" },
  })
  local expected =
    { "a", "└── b", "    └── c", "        └── d", "            └── e" }
  for i = 1, #expected do
    assert(out[i] == expected[i], string.format("line %d: %q", i, out[i]))
  end
end)

-- render: unicode names
test("render unicode names", function()
  local out = render.render({
    { level = 0, name = "src" },
    { level = 1, name = "目录" },
    { level = 1, name = "文件" },
  })
  assert(out[2] == "├── 目录" and out[3] == "└── 文件")
end)

-- render: many siblings
test("render many siblings", function()
  local nodes = { { level = 0, name = "src" } }
  for i = 1, 10 do
    nodes[#nodes + 1] = { level = 1, name = "f" .. i }
  end
  local out = render.render(nodes)
  for i = 2, 10 do
    assert(out[i] == "├── f" .. (i - 1), string.format("line %d: %q", i, out[i]))
  end
  assert(out[11] == "└── f10")
end)

-- ============ detect ============

local TREE = { "src", "├── a", "│   └── x", "└── b" }

test("detect body line", function()
  local m = assert(detect.detect(TREE, 2))
  assert(m.start == 1 and m.finish == 4 and #m.nodes == 4)
  assert(m.nodes[1].level == 0 and m.nodes[1].name == "src" and m.nodes[1].is_dir == true)
  assert(
    m.nodes[2].level == 1
      and m.nodes[2].name == "a"
      and m.nodes[2].is_dir == true
      and m.nodes[2].is_last == false
  )
  assert(
    m.nodes[3].level == 2
      and m.nodes[3].name == "x"
      and m.nodes[3].is_dir == false
      and m.nodes[3].is_last == true
  )
  assert(m.nodes[4].level == 1 and m.nodes[4].is_last == true)
end)

test("detect root line", function()
  local m = assert(detect.detect(TREE, 1))
  assert(m.start == 1 and m.finish == 4)
end)

test("detect rejects non-tree lines", function()
  assert(detect.detect(TREE, 5) == nil)
  assert(detect.detect({ "plain", "text" }, 1) == nil)
  local m = assert(detect.detect({ "src", "├── a", "", "└── b" }, 4))
  assert(m.start == 4 and #m.nodes == 1 and m.nodes[1].level == 1)
end)

test("detect rejects malformed tree", function()
  assert(detect.detect({ "src", "├── a", "│   └ x" }, 3) == nil)
  assert(detect.detect({ "src", "├── a", "│  └── x" }, 3) == nil)
end)

test("detect blank breaks region upward", function()
  local m = assert(detect.detect({ "src", "├── a", "", "└── b" }, 2))
  assert(m.finish == 2)
end)

test("detect margin tree", function()
  local m = assert(detect.detect({ "  src", "  ├── a", "  └── b" }, 2))
  assert(m.nodes[1].margin == "  " and m.nodes[2].name == "a")
end)

test("detect empty names", function()
  local m = assert(detect.detect({ "src", "├── ", "└── b" }, 2))
  assert(m.nodes[2].name == "" and m.nodes[2].is_last == false)
end)

test("detect multi-root shared margin", function()
  local m = assert(detect.detect({ "src", "├── a", "other", "└── c" }, 4))
  assert(m.start == 3 and m.finish == 4 and m.nodes[1].name == "other")
  assert(m.nodes[2].level == 1 and m.nodes[2].name == "c")
end)

test("detect space-segment deep tree", function()
  local m = assert(detect.detect({ "src", "└── a", "    └── x" }, 3))
  assert(m.nodes[3].level == 2 and m.nodes[3].name == "x", tostring(m.nodes[3].level))
  assert(m.nodes[2].is_dir == true and m.nodes[2].is_last == true)
end)

test("detect space-segment deep tree from root", function()
  local m = assert(detect.detect({ "src", "└── a", "    ├── x", "    └── y" }, 1))
  assert(m.finish == 4 and m.nodes[3].level == 2 and m.nodes[4].level == 2)
end)

test("detect collapsed empty leaves", function()
  local m = assert(detect.detect({ "src", "│", "│", "└── " }, 2))
  assert(#m.nodes == 4 and m.nodes[2].level == 1 and m.nodes[2].name == "")
  assert(m.nodes[3].level == 1 and m.nodes[3].is_last == false)
end)

test("detect collapsed deeper level", function()
  local m = assert(detect.detect({ "src", "├── a", "│   │", "└── b" }, 3))
  assert(m.nodes[3].level == 2 and m.nodes[3].name == "")
  assert(m.nodes[3].is_dir == false and m.nodes[3].is_last == true)
end)

-- ============ edit ============

test("edit new_sibling after dir node", function()
  local nl, pos = assert(edit.new_sibling(TREE, 2))
  assert(
    nl[1] == "src"
      and nl[2] == "├── a"
      and nl[3] == "│   └── x"
      and nl[4] == "│"
      and nl[5] == "└── b"
      and pos == 4,
    table.concat(nl, "|")
  )
end)

test("edit new_sibling on root", function()
  local nl, pos = assert(edit.new_sibling(TREE, 1))
  assert(
    nl[1] == "src"
      and nl[2] == "├── a"
      and nl[3] == "│   └── x"
      and nl[4] == "├── b"
      and nl[5] == "└── "
      and pos == 5,
    table.concat(nl, "|")
  )
end)

test("edit new_sibling after leaf flips last", function()
  local nl = assert(edit.new_sibling(TREE, 4))
  assert(nl[4] == "├── b" and nl[5] == "└── ", table.concat(nl, "|"))
end)

test("edit new_sibling on non-tree line", function()
  assert(edit.new_sibling({ "hello", "world" }, 1) == nil)
end)

test("edit shift deeper", function()
  local nl = assert(edit.shift(TREE, 4, 1))
  assert(
    nl[1] == "src"
      and nl[2] == "└── a"
      and nl[3] == "    ├── x"
      and nl[4] == "    └── b",
    table.concat(nl, "|")
  )
end)

test("edit shift deeper blocked at limit", function()
  assert(edit.shift(TREE, 3, 1) == nil)
  assert(edit.shift(TREE, 2, 1) == nil)
  assert(edit.shift(TREE, 1, 1) == nil)
end)

test("edit shift shallower", function()
  local lines = { "src", "├── a", "│   └── x", "└── b" }
  local nl = assert(edit.shift(lines, 3, -1))
  assert(
    nl[1] == "src" and nl[2] == "├── a" and nl[3] == "├── x" and nl[4] == "└── b",
    table.concat(nl, "|")
  )
end)

test("edit shift shallower blocked", function()
  assert(edit.shift(TREE, 4, -1) == nil)
  assert(edit.shift(TREE, 2, -1) == nil)
  assert(edit.shift(TREE, 1, -1) == nil)
end)

test("edit backspace deletes name char", function()
  local nl, l, c = assert(edit.backspace(TREE, 3, 99))
  assert(l == 3 and nl[3] == "│   └── ", table.concat(nl, "|"))
  assert(c == 17, tostring(c))
end)

test("edit backspace unicode name", function()
  local lines = { "src", "├── 目录", "└── b" }
  local nl = assert(edit.backspace(lines, 2, 99))
  assert(nl[2] == "├── 目", table.concat(nl, "|"))
end)

test("edit backspace mid unicode name deletes char before cursor", function()
  local lines = { "src", "├── 目录x", "└── b" }
  local name_start = #lines[2] - #"目录x" + 1
  local nl, l, c = assert(edit.backspace(lines, 2, name_start + 6))
  assert(nl[2] == "├── 目x", table.concat(nl, "|"))
  assert(l == 2 and c == name_start + 3, tostring(c))
end)

test("edit backspace empty leaf deletes line", function()
  local lines = { "src", "├── a", "│   └── ", "└── b" }
  local nl, l, c = assert(edit.backspace(lines, 3, 99))
  assert(l == 2 and nl[2] == "├── a" and nl[3] == "└── b", table.concat(nl, "|"))
  assert(c == #nl[2] + 1, tostring(c))
end)

test("edit backspace empty dir blocked", function()
  local lines = { "src", "├── ", "│   └── x", "└── b" }
  local blocked = select(4, edit.backspace(lines, 2, 99))
  assert(blocked == true)
end)

test("edit backspace in connector area blocked", function()
  local blocked = select(4, edit.backspace(TREE, 3, 3))
  assert(blocked == true)
end)

test("edit backspace mid name deletes char before cursor", function()
  local lines = { "src", "├── abc", "└── b" }
  local name_start = #lines[2] - #"abc" + 1
  local nl, l, c, blocked = edit.backspace(lines, 2, name_start + 1)
  assert(nl and nl[2] == "├── bc", table.concat(nl or {}, "|"))
  assert(l == 2 and c == name_start, tostring(c))
  assert(blocked == nil)
end)

test("edit delete_node leaf", function()
  local nl, was_dir = assert(edit.delete_node(TREE, 4))
  assert(was_dir == false and #nl == 3)
  assert(nl[2] == "└── a" and nl[3] == "    └── x", table.concat(nl, "|"))
end)

test("edit delete_node dir merges children", function()
  local nl, was_dir = assert(edit.delete_node(TREE, 2))
  assert(was_dir == true)
  assert(
    nl[1] == "src" and nl[2] == "├── x" and nl[3] == "└── b",
    table.concat(nl, "|")
  )
end)

test("edit delete_node root blocked", function()
  assert(edit.delete_node(TREE, 1) == nil)
end)

test("edit delete_node on non-tree line", function()
  assert(edit.delete_node({ "hello" }, 1) == nil)
end)

test("edit insert_marker starts tree", function()
  local nl = assert(edit.insert_marker({ "src", "" }, 2))
  assert(nl[1] == "src" and nl[2] == "└── ", table.concat(nl, "|"))
end)

test("edit insert_marker with content", function()
  local nl = assert(edit.insert_marker({ "src", "notes" }, 2))
  assert(nl[2] == "└── notes", table.concat(nl, "|"))
end)

test("edit insert_marker with margin", function()
  local nl = assert(edit.insert_marker({ "  src", "  " }, 2))
  assert(nl[2] == "  └── ", table.concat(nl, "|"))
end)

test("edit insert_marker blocked", function()
  assert(edit.insert_marker({ "src" }, 1) == nil)
  assert(edit.insert_marker({ "", "x" }, 2) == nil)
  assert(edit.insert_marker(TREE, 2) == nil)
end)

test("edit operation chain builds valid tree", function()
  local lines = { "src", "" }
  local nl = assert(edit.insert_marker(lines, 2))
  nl = assert(edit.new_sibling(nl, 2))
  nl = assert(edit.new_sibling(nl, 2))
  nl = assert(edit.shift(nl, 4, 1))
  nl = assert(edit.new_sibling(nl, 3))
  assert(
    nl[1] == "src"
      and nl[2] == "│"
      and nl[3] == "├── "
      and nl[4] == "│   └── "
      and nl[5] == "└── ",
    table.concat(nl, "|")
  )
end)

-- ============ focus rendering ============

test("render_region expands focused empty leaf", function()
  local lines = { "src", "├── a", "│", "└── b" }
  local nl = assert(edit.render_region(lines, 3, 3))
  assert(nl[3] == "├── ", table.concat(nl, "|"))
  assert(nl[2] == "├── a" and nl[4] == "└── b", table.concat(nl, "|"))
end)

test("render_region without focus keeps collapse", function()
  local lines = { "src", "├── a", "│", "└── b" }
  local nl = assert(edit.render_region(lines, 2, nil))
  assert(nl[3] == "│", table.concat(nl, "|"))
end)

test("render_region focus on non-empty line unchanged", function()
  local lines = { "src", "├── a", "└── b" }
  local nl = assert(edit.render_region(lines, 2, 2))
  assert(nl[2] == "├── a", table.concat(nl, "|"))
end)

test("render_region outside tree returns nil", function()
  assert(edit.render_region({ "hello" }, 1, 1) == nil)
end)

test("render_region focus on root unchanged", function()
  local lines = { "src", "├── a", "└── b" }
  local nl = assert(edit.render_region(lines, 1, 1))
  assert(nl[1] == "src" and nl[2] == "├── a", table.concat(nl, "|"))
end)

-- ============ shift_lines (visual batch) ============

test("shift_lines outdent leaf", function()
  local lines = { "src", "├── a", "│   └── x", "└── b" }
  local nl = assert(edit.shift_lines(lines, 3, 3, -1))
  assert(
    nl[2] == "├── a" and nl[3] == "├── x" and nl[4] == "└── b",
    table.concat(nl, "|")
  )
end)

test("shift_lines moves subtree deeper", function()
  local lines = { "src", "├── a", "└── b", "    └── y" }
  local nl = assert(edit.shift_lines(lines, 3, 4, 1))
  assert(
    nl[1] == "src"
      and nl[2] == "└── a"
      and nl[3] == "    └── b"
      and nl[4] == "        └── y",
    table.concat(nl, "|")
  )
end)

test("shift_lines deeper allows unselected children", function()
  local lines = { "src", "├── a", "├── b", "│   └── y", "└── c" }
  local nl = assert(edit.shift_lines(lines, 3, 3, 1))
  assert(
    nl[1] == "src"
      and nl[2] == "├── a"
      and nl[3] == "│   ├── b"
      and nl[4] == "│   └── y"
      and nl[5] == "└── c",
    table.concat(nl, "|")
  )
  assert(edit.shift_lines(lines, 3, 3, -1) == nil)
end)

test("shift_lines atomic block on partial subtree", function()
  local lines = { "src", "├── a", "│   └── x", "└── b" }
  assert(edit.shift_lines(lines, 2, 3, -1) == nil)
end)

test("shift_lines blocked at boundaries", function()
  local lines = { "src", "├── a", "└── b" }
  assert(edit.shift_lines(lines, 2, 3, 1) == nil)
  assert(edit.shift_lines(lines, 2, 3, -1) == nil)
  assert(edit.shift_lines(lines, 1, 1, 1) == nil)
  assert(edit.shift_lines(lines, 1, 1, -1) == nil)
  assert(edit.shift_lines(lines, 2, 2, 0) == nil)
  assert(edit.shift_lines({ "plain" }, 1, 1, 1) == nil)
end)

-- ============ delete_lines (visual multi-delete) ============

test("delete_lines removes multiple leaves", function()
  local lines = { "src", "├── a", "├── x", "└── b" }
  local nl = assert(edit.delete_lines(lines, 2, 3))
  assert(nl[1] == "src" and nl[2] == "└── b", table.concat(nl, "|"))
end)

test("delete_lines merges children of deleted dir", function()
  local lines = { "src", "├── a", "│   └── x", "└── b" }
  local nl = assert(edit.delete_lines(lines, 2, 2))
  assert(
    nl[1] == "src" and nl[2] == "├── x" and nl[3] == "└── b",
    table.concat(nl, "|")
  )
end)

test("delete_lines dir with its only child", function()
  local lines = { "src", "├── a", "│   └── x", "└── b" }
  local nl = assert(edit.delete_lines(lines, 2, 3))
  assert(nl[1] == "src" and nl[2] == "└── b", table.concat(nl, "|"))
end)

test("delete_lines whole subtree leaves dir empty", function()
  local lines = { "src", "├── a", "│   ├── x", "│   └── y", "└── b" }
  local nl = assert(edit.delete_lines(lines, 3, 4))
  assert(nl[2] == "├── a" and nl[3] == "└── b", table.concat(nl, "|"))
end)

test("delete_lines deletes whole tree including root", function()
  local lines = { "src", "├── a", "└── b" }
  local nl, merged = assert(edit.delete_lines(lines, 1, 3))
  assert(merged == false and #nl == 0)
end)

test("delete_lines non-tree returns nil", function()
  assert(edit.delete_lines({ "one", "two" }, 1, 2) == nil)
end)

test("delete_lines reports merge when children survive", function()
  local lines = { "src", "├── a", "│   └── x", "└── b" }
  local _, merged = assert(edit.delete_lines(lines, 2, 2))
  assert(merged == true)
  local _, merged2 = assert(edit.delete_lines(lines, 2, 3))
  assert(merged2 == false)
  local _, merged3 = assert(edit.delete_lines(lines, 4, 4))
  assert(merged3 == false)
end)

-- ============ shift semantics ============

test("shift deeper moves line, children stay (user model)", function()
  local lines =
    { "src", "├── a", "│   └── b", "├── c", "│   └── d", "└── e" }
  local nl = assert(edit.shift(lines, 4, 1))
  assert(
    nl[1] == "src"
      and nl[2] == "├── a"
      and nl[3] == "│   ├── b"
      and nl[4] == "│   ├── c"
      and nl[5] == "│   └── d"
      and nl[6] == "└── e",
    table.concat(nl, "|")
  )
end)

test("shift deeper still blocked at limit", function()
  local lines =
    { "src", "├── a", "│   └── b", "├── c", "│   └── d", "└── e" }
  assert(edit.shift(lines, 2, 1) == nil)
  assert(edit.shift(lines, 3, 1) == nil)
end)

-- ============ join ============

test("join_line merges sibling name", function()
  local lines = { "src", "├── a", "└── b" }
  local nl = assert(edit.join_line(lines, 2, " "))
  assert(nl[1] == "src" and nl[2] == "└── a b", table.concat(nl, "|"))
end)

test("join_line merges child and keeps its subtree", function()
  local lines = { "src", "├── a", "│   └── x", "└── b" }
  local nl = assert(edit.join_line(lines, 2, " "))
  assert(
    nl[1] == "src" and nl[2] == "├── a x" and nl[3] == "└── b",
    table.concat(nl, "|")
  )
end)

test("join_line joins shallower node and shifts its subtree down", function()
  local lines = { "src", "├── a", "│   └── x", "└── b", "    └── y" }
  local nl = assert(edit.join_line(lines, 3, " "))
  assert(
    nl[1] == "src"
      and nl[2] == "└── a"
      and nl[3] == "    └── x b"
      and nl[4] == "        └── y",
    table.concat(nl, "|")
  )
end)

test("join_line on root merges first child", function()
  local lines = { "src", "├── a", "│   └── x" }
  local nl = assert(edit.join_line(lines, 1, " "))
  assert(nl[1] == "src a" and nl[2] == "└── x", table.concat(nl, "|"))
end)

test("join_line no separator", function()
  local lines = { "src", "├── a", "└── b" }
  local nl = assert(edit.join_line(lines, 2, ""))
  assert(nl[2] == "└── ab", table.concat(nl, "|"))
end)

test("join_line blocked on last node or non-tree", function()
  assert(edit.join_line({ "src", "└── a" }, 2, " ") == nil)
  assert(edit.join_line({ "one", "two" }, 1, " ") == nil)
end)

-- ============ rootless trees ============

test("detect rootless tree with detached root line", function()
  local m = assert(detect.detect({ "    src", "└── a", "└── b" }, 2))
  assert(m.start == 2 and #m.nodes == 2)
  assert(m.nodes[1].level == 1 and m.nodes[1].name == "a")
  assert(m.nodes[2].level == 1 and m.nodes[2].name == "b")
end)

test("detect rootless tree at buffer start", function()
  local m = assert(detect.detect({ "└── a", "└── b" }, 1))
  assert(m.start == 1 and m.nodes[1].level == 1 and m.nodes[1].is_last == false)
end)

test("backspace on root line returns nil", function()
  assert(edit.backspace({ "src", "└── a" }, 1, 2) == nil)
end)

test("delete_node on first body node of rootless tree", function()
  local lines = { "└── a", "    └── x", "└── b" }
  local nl, was_dir = assert(edit.delete_node(lines, 1))
  assert(was_dir == true)
  assert(nl[1] == "├── x" and nl[2] == "└── b", table.concat(nl, "|"))
end)

test("delete_lines allows full rootless tree deletion", function()
  local lines = { "└── a", "└── b" }
  local nl, merged = assert(edit.delete_lines(lines, 1, 2))
  assert(merged == false and #nl == 0)
end)

io.write(string.format("%d passed, %d failed\n", passed, failed))
for _, f in ipairs(failures) do
  io.write("FAIL: " .. f .. "\n")
end
if failed > 0 then
  os.exit(1)
end
