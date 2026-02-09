local has_lualine, lualine = pcall(require, "lualine")

return function()
  if has_lualine and lualine then
    lualine.refresh({
      place = { "tabline" },
    })
    return
  end

  if vim.api.nvim__redraw then
    vim.api.nvim__redraw({ tabeline = true })
    return
  end

  vim.cmd.redrawtabline()
end
