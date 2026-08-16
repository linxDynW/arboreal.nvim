local M = {}

-- Built-in tree mappings default to which_key_ignore to stay out of which-key menus.
function M.tree_map(mode, lhs, rhs, opts)
  opts = opts or {}
  if not opts.desc then
    opts.desc = "which_key_ignore"
  end
  vim.keymap.set(mode, lhs, rhs, opts)
end

return M
