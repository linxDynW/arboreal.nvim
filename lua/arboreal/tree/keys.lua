local M = {}

local registry = {}

function M.reset()
  registry = {}
end

-- Built-in tree mappings are recorded here and applied per buffer when a tree
-- is active. This avoids stealing common keys such as visual > from the user
-- in buffers without a tree.
function M.tree_map(mode, lhs, rhs, opts)
  opts = opts or {}
  if not opts.desc then
    opts.desc = "which_key_ignore"
  end
  registry[#registry + 1] = { mode = mode, lhs = lhs, rhs = rhs, opts = opts }
end

function M.apply_buffer(bufnr)
  for _, spec in ipairs(registry) do
    local opts = vim.tbl_extend("force", { buffer = bufnr }, spec.opts)
    vim.keymap.set(spec.mode, spec.lhs, spec.rhs, opts)
  end
end

function M.clear_buffer(bufnr)
  for _, spec in ipairs(registry) do
    pcall(vim.keymap.del, spec.mode, spec.lhs, { buffer = bufnr })
  end
end

-- User-configured keys (insert_key/toggle_key) stay global.
function M.global_map(mode, lhs, rhs, opts)
  opts = opts or {}
  if not opts.desc then
    opts.desc = "which_key_ignore"
  end
  vim.keymap.set(mode, lhs, rhs, opts)
end

return M
