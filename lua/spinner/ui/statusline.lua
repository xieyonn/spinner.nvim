local has_lualine, lualine = pcall(require, "lualine")
local api = vim.api

if has_lualine and lualine then
  return function()
    lualine.refresh({
      place = { "statusline" },
    })
  end
end

if api.nvim__redraw then
  return function()
    api.nvim__redraw({ statusline = true })
  end
end

return function()
  vim.cmd.redrawstatus()
end
