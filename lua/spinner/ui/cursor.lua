local STATUS = require("spinner.status")

local function create_buf()
  local buf = vim.api.nvim_create_buf(false, true)

  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  vim.api.nvim_set_option_value("filetype", "spinner", { buf = buf })
  vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
  vim.api.nvim_set_option_value("undofile", false, { buf = buf })
  return buf
end

---@param state spinner.State
---@return function
return function(state)
  local win, buf = nil, nil ---@type integer|nil, integer|nil

  return function()
    local opts = state.opts

    if STATUS.STOPPED == state.status then
      if win and vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
        win, buf = nil, nil
      end
      return
    end

    if not (buf and vim.api.nvim_buf_is_valid(buf)) then
      buf = create_buf()
    end
    local text = state:render()
    local width = vim.fn.strdisplaywidth(text)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { text })

    if not (win and vim.api.nvim_win_is_valid(win)) then
      win = vim.api.nvim_open_win(buf, false, {
        relative = "cursor",
        row = opts.row,
        col = opts.col,
        width = width,
        height = 1,
        style = "minimal",
        focusable = false,
        border = opts.border,
        zindex = opts.zindex,
        noautocmd = true,
      })

      vim.api.nvim_set_option_value(
        "winhighlight",
        "Normal:" .. opts.hl_group,
        { win = win }
      )
      vim.api.nvim_set_option_value("winblend", opts.winblend, { win = win })
      return
    end

    vim.api.nvim_win_set_config(win, {
      relative = "cursor",
      row = opts.row,
      col = opts.col,
      width = width,
    })
  end
end
