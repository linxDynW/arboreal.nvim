local config = require("arboreal.config")

local M = {}

M.config = nil

---@param opts? table
function M.setup(opts)
  M.config = config.merge(opts)
  if M.config.convert_key then
    vim.keymap.set("x", M.config.convert_key, "<Plug>(arboreal-convert)", {
      desc = "Arboreal: convert selection to directory tree",
    })
  end
  require("arboreal.tree").setup_mappings()
end

return M
