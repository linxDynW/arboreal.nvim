local M = {}

--- Linewise paste protection: simulate the insertion, re-detect, and block when the tree would break.
function M.setup(ctx)
  local enabled = ctx.enabled
  local get_lines = ctx.get_lines
  local set_lines = ctx.set_lines
  local row = ctx.row
  local fallback = ctx.fallback
  local notify = ctx.notify
  local current_opts = ctx.current_opts
  local detect = ctx.detect
  local refresh = ctx.refresh
  local tree_map = ctx.tree_map

  local function paste_lines(above)
    local lines = get_lines()
    local r = row()
    if not detect.detect(lines, r, current_opts()) then
      return nil
    end
    local regtype = vim.fn.getregtype('"')
    if regtype ~= "V" then
      return nil
    end
    local reg = vim.fn.getreg('"')
    local reglines = vim.split(reg, "\n", { plain = true })
    if reglines[#reglines] == "" then
      table.remove(reglines)
    end
    local at = above and r or r + 1
    local sim = {}
    for k = 1, #lines do
      sim[k] = lines[k]
    end
    for n = #reglines, 1, -1 do
      table.insert(sim, at, reglines[n])
    end
    if not detect.detect(sim, r, current_opts()) then
      notify(
        "paste would break the tree structure\n(use :Arb off to edit raw text)",
        vim.log.levels.WARN
      )
      return true
    end
    set_lines(sim)
    vim.api.nvim_win_set_cursor(0, { at, 0 })
    refresh(nil, false)
    return true
  end

  tree_map("n", "p", function()
    if not enabled() then
      return fallback("p")
    end
    if paste_lines(false) == nil then
      fallback("p")
    end
  end)

  tree_map("n", "P", function()
    if not enabled() then
      return fallback("P")
    end
    if paste_lines(true) == nil then
      fallback("P")
    end
  end)
end

return M
