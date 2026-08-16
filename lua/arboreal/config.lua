local M = {}

---@class arboreal.Config
---@field branch string
---@field leaf string
---@field pipe string
---@field indent integer
---@field convert_key string|false
---@field insert_key string|false Optional mapping for :Arb i
---@field toggle_key string|false Optional mapping for :Arb on / :Arb off
---@field notify_on_limit boolean
---@field confirm_directory_delete boolean
---@field subtree_indent boolean

M.defaults = {
  branch = "├──",
  leaf = "└──",
  pipe = "│",
  indent = 4,
  convert_key = "<leader>at",
  insert_key = false,
  toggle_key = false,
  notify_on_limit = true,
  confirm_directory_delete = true,
  subtree_indent = false,
}

---@param user? table
---@return arboreal.Config
function M.merge(user)
  return vim.tbl_deep_extend("force", {}, M.defaults, user or {})
end

return M
