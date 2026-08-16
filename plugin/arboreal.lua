if vim.g.loaded_arboreal or vim.fn.has("nvim-0.9") ~= 1 then
  return
end
vim.g.loaded_arboreal = true

local function convert_range_cmd(opts)
  local line1, line2 = opts.line1, opts.line2
  if opts.range == 0 and vim.fn.mode():match("[vV\22]") then
    local vpos = vim.fn.getpos("v")
    local cpos = vim.fn.getpos(".")
    line1 = math.min(vpos[2], cpos[2])
    line2 = math.max(vpos[2], cpos[2])
  end
  local ok, err_line, err_msg = require("arboreal.convert").convert_range(0, line1, line2)
  if not ok then
    vim.notify(
      "arboreal: " .. err_msg .. " (line " .. tostring(err_line) .. ")",
      vim.log.levels.ERROR
    )
  end
end

vim.api.nvim_create_user_command("ArborealConvert", convert_range_cmd, { range = true })

vim.api.nvim_create_user_command("Arb", function(opts)
  local sub = (opts.fargs[1] or ""):lower()
  if sub == "c" then
    convert_range_cmd(opts)
  elseif sub == "i" then
    require("arboreal.tree").insert_marker_cmd()
  elseif sub == "on" then
    require("arboreal.tree").set_enabled(true)
  elseif sub == "off" then
    require("arboreal.tree").set_enabled(false)
  else
    vim.notify("arboreal: usage: Arb c | i | on | off", vim.log.levels.ERROR)
  end
end, {
  nargs = 1,
  range = true,
  complete = function()
    return { "c", "i", "on", "off" }
  end,
  desc = "Arboreal: c=convert, i=insert entry, on/off=toggle editing",
})

vim.keymap.set("x", "<Plug>(arboreal-convert)", "<cmd>ArborealConvert<CR>")
