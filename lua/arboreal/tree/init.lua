local detect = require("arboreal.detect")
local edit = require("arboreal.edit")
local state = require("arboreal.tree.state")
local notify_mod = require("arboreal.tree.notify")
local keys = require("arboreal.tree.keys")
local context = require("arboreal.tree.context")

local M = {}

local cfg = state.config
local enabled = state.enabled
local get_lines = state.get_lines
local set_lines = state.set_lines
local row = state.row
local col = state.col
local fallback = state.fallback
local current_opts = state.current_opts
local tree_map = keys.tree_map
local global_map = keys.global_map
local notify = notify_mod.notify
local notify_blocked = notify_mod.blocked
local char_len_at = context.char_len_at
local node_at = context.node_at
local name_start_at = context.name_start_at
local on_connector_area = context.on_connector_area

-- Re-render the tree around the cursor and clamp the cursor to the name area.
-- Write to the buffer only when rendering changes it (avoids undo noise).
-- Driven by autocmds (CursorMovedI/TextChangedI/InsertEnter/CursorMoved/InsertLeave)
-- and callable directly from tests. focus_line nil means no focused line;
-- clamp_cursor is only used in insert-mode contexts.
function M.refresh(focus_line, clamp_cursor)
  if vim.b.arboreal_refreshing then
    return
  end
  local lines = get_lines()
  local r = row()
  local model = detect.detect(lines, r, current_opts())
  M.sync_mappings(model)
  if not model then
    return
  end
  local nl = edit.render_region(lines, r, focus_line, current_opts())
  if not nl then
    return
  end
  local changed = false
  if #nl ~= #lines then
    changed = true
  else
    for k = 1, #nl do
      if nl[k] ~= lines[k] then
        changed = true
        break
      end
    end
  end
  if changed then
    vim.b.arboreal_refreshing = true
    set_lines(nl)
    vim.b.arboreal_refreshing = false
  end
  if not clamp_cursor then
    return
  end
  local node = nil
  for _, n in ipairs(model.nodes) do
    if n.line == r then
      node = n
      break
    end
  end
  if node and node.level > 0 then
    local name_start = name_start_at(nl[r], node)
    local c = vim.api.nvim_win_get_cursor(0)
    if c[2] < name_start - 1 then
      vim.api.nvim_win_set_cursor(0, { r, name_start - 1 })
    end
  end
end

function M.sync_mappings(model)
  if model == nil then
    model = detect.detect(get_lines(), row(), current_opts())
  end
  local active = vim.b.arboreal_mappings_active
  if enabled() and model then
    if not active then
      keys.apply_buffer(0)
      vim.b.arboreal_mappings_active = true
    end
  elseif active then
    keys.clear_buffer(0)
    vim.b.arboreal_mappings_active = false
  end
end

function M.clear_mappings()
  keys.clear_buffer(0)
  vim.b.arboreal_mappings_active = false
end

function M.toggle()
  vim.b.arboreal_enabled = vim.b.arboreal_enabled == false
  if vim.b.arboreal_enabled then
    M.sync_mappings()
  else
    M.clear_mappings()
  end
  notify(vim.b.arboreal_enabled and "tree editing enabled" or "tree editing disabled (plain text)")
end

function M.set_enabled(on)
  vim.b.arboreal_enabled = on and true or false
  if on then
    M.sync_mappings()
  else
    M.clear_mappings()
  end
  notify(on and "tree editing enabled" or "tree editing disabled (plain text)")
end

function M.insert_marker_cmd()
  local r = row()
  local nl = edit.insert_marker(get_lines(), r, current_opts())
  if not nl then
    notify("marker requires a non-blank line above", vim.log.levels.WARN)
    return
  end
  set_lines(nl)
  vim.cmd("startinsert")
  vim.api.nvim_win_set_cursor(0, { r, #nl[r] })
  M.refresh(row(), true)
end

function M.setup_mappings()
  notify_mod.reset_throttle()
  keys.clear_buffer(0)
  vim.b.arboreal_mappings_active = false
  keys.reset()
  local group = vim.api.nvim_create_augroup("ArborealTree", { clear = true })

  vim.api.nvim_create_autocmd({ "CursorMovedI", "TextChangedI", "InsertEnter" }, {
    group = group,
    callback = function()
      if not enabled() then
        return
      end
      M.refresh(row(), true)
    end,
  })
  vim.api.nvim_create_autocmd("TextChanged", {
    group = group,
    callback = function()
      if not enabled() then
        return
      end
      M.refresh(nil, false)
    end,
  })
  vim.api.nvim_create_autocmd("InsertLeave", {
    group = group,
    callback = function()
      if not enabled() then
        return
      end
      M.refresh(nil, false)
    end,
  })

  vim.api.nvim_create_autocmd({ "CursorMoved", "BufEnter", "WinEnter" }, {
    group = group,
    callback = function()
      if not enabled() then
        M.clear_mappings()
        return
      end
      M.sync_mappings()
    end,
  })

  vim.api.nvim_create_autocmd("BufLeave", {
    group = group,
    callback = function(event)
      keys.clear_buffer(event.buf)
    end,
  })

  local ctx = {
    enabled = enabled,
    get_lines = get_lines,
    set_lines = set_lines,
    row = row,
    col = col,
    fallback = fallback,
    notify = notify,
    notify_blocked = notify_blocked,
    current_opts = current_opts,
    cfg = cfg,
    detect = detect,
    edit = edit,
    node_at = node_at,
    name_start_at = name_start_at,
    on_connector_area = on_connector_area,
    char_len_at = char_len_at,
    tree_map = tree_map,
    refresh = M.refresh,
  }

  local common = require("arboreal.tree.mappings.common").setup(ctx)
  ctx.indent_lines = common.indent_lines
  ctx.preserve_visual = common.preserve_visual
  ctx.selection_is_body = common.selection_is_body
  ctx.shift_visual = common.shift_visual
  ctx.shift_line = common.shift_line
  ctx.delete_selection = common.delete_selection
  ctx.delete_char_range = common.delete_char_range

  require("arboreal.tree.mappings.insert").setup(ctx)
  require("arboreal.tree.mappings.normal").setup(ctx)
  require("arboreal.tree.mappings.visual").setup(ctx)
  require("arboreal.tree.mappings.paste").setup(ctx)

  local op = require("arboreal.tree.mappings.operator").setup(ctx)
  M.op_shift_right = op.shift_right
  M.op_shift_left = op.shift_left
  M.op_delete = op.delete
  M.op_change = op.change

  local insert_key = cfg().insert_key
  if insert_key then
    global_map("n", insert_key, function()
      local r = row()
      local nl = edit.insert_marker(get_lines(), r, current_opts())
      if not nl then
        notify("marker requires a non-blank line above", vim.log.levels.WARN)
        return
      end
      set_lines(nl)
      vim.cmd("startinsert")
      vim.api.nvim_win_set_cursor(0, { r, #nl[r] })
      M.refresh(row(), true)
    end, { desc = "Arboreal: mark line as tree entry" })
  end

  local toggle_key = cfg().toggle_key
  if toggle_key then
    global_map("n", toggle_key, M.toggle, { desc = "Arboreal: toggle tree editing" })
  end

  M.sync_mappings()
end

return M
