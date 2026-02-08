local has_lualine, lualine = pcall(require, "lualine")

if has_lualine and lualine then
  return function()
    lualine.refresh({
      place = { "tabline" },
    })
  end
end

if vim.api.nvim__redraw then
  return function()
    vim.api.nvim__redraw({ tabeline = true })
  end
end

return function()
  vim.cmd("redrawtabline")
end
