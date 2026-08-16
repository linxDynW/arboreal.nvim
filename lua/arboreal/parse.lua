---@class arboreal.ParseOpts
---@field indent? integer Fallback when the indent unit cannot be derived; default 4
---@field multiple_roots? boolean Allow multiple roots (lines at the base indent start a new tree); default true

---@class arboreal.Node
---@field line_index integer 1-based line number in the original lines array
---@field level integer Relative level; 0 = tree root
---@field name string Text after the leading whitespace

---@class arboreal.ParseResult
---@field nodes arboreal.Node[] Nodes for non-blank lines, in original order
---@field unit integer Derived indent unit
---@field base integer Base leading-whitespace length
---@field base_str string Base leading-whitespace string (outer margin, preserved on output)

---@param lines string[] Plain indented text lines
---@param opts? arboreal.ParseOpts
---@return arboreal.ParseResult? Parsed result on success
---@return integer? 1-based line number of the failure
---@return string? Failure message (no line number; returned separately)
local M = {}

function M.parse(lines, opts)
  opts = opts or {}
  local multiple_roots = opts.multiple_roots
  if multiple_roots == nil then
    multiple_roots = true
  end
  local fallback = math.max(opts.indent or 4, 1)

  local entries = {}
  for i = 1, #lines do
    local line = lines[i]
    if not line:match("^%s*$") then
      local leading = line:match("^%s*")
      entries[#entries + 1] = {
        line_index = i,
        indent = #leading,
        leading = leading,
        name = line:sub(#leading + 1),
      }
    end
  end

  if #entries == 0 then
    return nil, 1, "no non-blank lines"
  end

  local base = entries[1].indent
  local base_str = entries[1].leading

  local rels = { [1] = 0 }
  for i = 2, #entries do
    local leading = entries[i].leading
    if leading:sub(1, #base_str) ~= base_str then
      return nil, entries[i].line_index, "indent does not start with the base indent"
    end
    rels[i] = #leading - #base_str
  end

  local unit = fallback
  if #entries > 1 then
    local second_r = rels[2]
    if second_r > 0 then
      unit = second_r
    end
  end

  local nodes = {}
  local prev_k = 0
  for i = 1, #entries do
    local entry = entries[i]
    local r = rels[i]
    local k
    if r == 0 then
      if i > 1 and not multiple_roots then
        return nil, entry.line_index, "multiple roots are not allowed"
      end
      k = 0
    elseif r > 0 then
      if r % unit ~= 0 then
        return nil, entry.line_index, "indent is not a multiple of the indent unit"
      end
      k = r / unit
      if k > prev_k + 1 then
        return nil, entry.line_index, "indent jumps more than one level"
      end
    end
    nodes[#nodes + 1] = {
      line_index = entry.line_index,
      level = k,
      name = entry.name,
    }
    prev_k = k
  end

  return { nodes = nodes, unit = unit, base = base, base_str = base_str }
end

return M
