local M = {}

local function notify(msg, level)
  vim.notify("arboreal: " .. msg, level or vim.log.levels.INFO)
end

M.notify = notify

-- Frequent single-key blocks should not notify on every press; the same key notifies once per cooldown.
local uv = vim.uv or vim.loop
local BLOCK_NOTIFY_COOLDOWN_MS = 2000
local last_block_notify = {}

function M.blocked(key, msg)
  local now = uv.hrtime() / 1e6
  local last = last_block_notify[key]
  if last and now - last < BLOCK_NOTIFY_COOLDOWN_MS then
    return
  end
  last_block_notify[key] = now
  notify(msg, vim.log.levels.WARN)
end

function M.reset_throttle()
  last_block_notify = {}
end

return M
