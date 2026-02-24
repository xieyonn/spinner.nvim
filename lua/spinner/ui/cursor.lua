local api = vim.api
local fn = vim.fn

local STATUS = require("spinner.status")
local utils = require("spinner.utils")

---@param state spinner.State
---@return function
return function(state)
  local win, buf = nil, nil ---@type integer|nil, integer|nil

  return function()
    local opts = state.opts

    local close = function()
      if win and api.nvim_win_is_valid(win) then
        api.nvim_win_close(win, true)
        win, buf = nil, nil
      end
    end

    if
      STATUS.STOPPED == state.status
      or STATUS.INIT == state.status
      or STATUS.DELAYED == state.status
      or STATUS.FAILED == state.status
    then
      close()
      return
    end

    local text = state:render()
    if text == "" then
      close()
      return
    end

    if not (buf and api.nvim_buf_is_valid(buf)) then
      buf = utils.create_scratch_buffer()
    end
    local width = fn.strdisplaywidth(text)
    api.nvim_buf_set_lines(buf, 0, -1, false, { text })

    if not (win and api.nvim_win_is_valid(win)) then
      win = api.nvim_open_win(buf, false, {
        relative = "cursor",
        row = opts.row,
        col = opts.col,
        width = width,
        height = 1,
        style = "minimal",
        focusable = false,
        border = "none",
        zindex = opts.zindex,
        noautocmd = true,
      })

      local hl = state:get_hl_group()
      if hl then
        api.nvim_set_option_value(
          "winhighlight",
          "Normal:" .. hl,
          { win = win }
        )
      end
      api.nvim_set_option_value("winblend", opts.winblend, { win = win })
      return
    end

    api.nvim_win_set_config(win, {
      relative = "cursor",
      row = opts.row,
      col = opts.col,
      width = width,
    })
  end
end
