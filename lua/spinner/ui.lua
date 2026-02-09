local cmdline = require("spinner.ui.cmdline")
local cursor = require("spinner.ui.cursor")
local extmark = require("spinner.ui.extmark")
local statusline = require("spinner.ui.statusline")
local tabline = require("spinner.ui.tabline")
local winbar = require("spinner.ui.winbar")

---@class spinner.ui
local M = {}

---@alias spinner.UIUpdater function

---Get UIUpdater.
---@param state spinner.State
---@return spinner.UIScope scope
---@return spinner.UIUpdater updater
local function get_ui_updater(state)
  local kind = state.opts.kind or "custom"

  if kind == "statusline" then
    return "statusline", statusline
  end
  if kind == "winbar" then
    return "winbar", winbar
  end
  if kind == "tabline" then
    return "tabline", tabline
  end
  if kind == "cursor" then
    return ("cursor:%d:%s"):format(
      state.opts and state.opts.row or 0,
      state.opts and state.opts.col or 0
    ),
      cursor(state)
  end
  if kind == "extmark" then
    return ("extmark:%d:%d:%d"):format(
      state.opts and state.opts.bufnr or 0,
      state.opts and state.opts.row or 0,
      state.opts and state.opts.col or 0
    ),
      extmark(state)
  end
  if kind == "cmdline" then
    return "cmdline", cmdline(state)
  end

  return (state.opts.ui_scope or "custom"),
    (state.opts.on_update_ui or function() end)
end

---Get UIUpdater
---@param state spinner.State
---@return spinner.UIScope scope
---@return spinner.UIUpdater updater
function M.get_ui_updater(state)
  local ui_scope, ui_updater = get_ui_updater(state)

  -- if provided a on_change method, call that instead.
  if state.opts.on_update_ui then
    return ui_scope,
      function()
        state.opts.on_update_ui({
          text = state:render(),
          status = state.status,
        })
      end
  end

  return ui_scope, ui_updater
end

return M
