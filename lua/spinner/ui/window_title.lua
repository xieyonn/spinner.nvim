local api = vim.api

local utils = require("spinner.utils")

---@param state spinner.State
---@return function
return function(state, kind)
  local win = state.opts.win

  utils.on_win_closed(win, function()
    require("spinner").stop(state.id, true)
  end)

  return function()
    if not (win and api.nvim_win_is_valid(win)) then
      -- prevent useless schedule
      require("spinner").stop(state.id, true)
      return
    end

    local cfg = api.nvim_win_get_config(win)
    if cfg.relative == "" then
      vim.notify_once(
        ("[spinner.nvim] can not display spinner in win: %d, this is no a float window"):format(
          win
        ),
        vim.log.levels.ERROR
      )
      require("spinner").stop(state.id, true)
    end

    local text = state:render()
    ---@type vim.api.keyset.win_config
    local win_config = {}
    if kind == "title" then
      win_config.title = { { text, state:get_hl_group() } }
      win_config.title_pos = state.opts.pos or "center"
    end
    if kind == "footer" then
      win_config.footer = { { text, state:get_hl_group() } }
      win_config.footer_pos = state.opts.pos or "center"
    end

    api.nvim_win_set_config(win, win_config)
  end
end
