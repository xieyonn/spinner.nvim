---@class spinner.Config
---@field opts spinner.Opts
local M = {}

---@class spinner.Opts
---@field chars? string[] spinner chars
---@field speed? integer millisecond
---@field ttl? integer millisecond
---
---@field hl_group? string spinner chars hl_group in CursorSpinner
---@field winblend? integer spinner window winblend
---@field zindex? integer spinner window zindex
---@field width? integer single frame char width
---@field row? integer CursorSpinner window position, relative to cursor
---@field col? integer CursorSpinner window position, relative to cursor

local default_opts = {
  chars = {
    "⠋",
    "⠙",
    "⠹",
    "⠸",
    "⠼",
    "⠴",
    "⠦",
    "⠧",
    "⠇",
    "⠏",
  },
  speed = 80, -- refresh millisecond.
  ttl = 0, -- the spinner will automatically stop after that {ttl} millisecond.

  -- CursorSpinner
  hl_group = "Spinner", -- link to NormalFloat by default.
  winblend = 60, -- CursorSpinner window option.
  width = 3, -- CursorSpinner window option.
  zindex = 50, -- CursorSpinner window option.
  row = -1, -- CursorSpinner window position, relative to cursor.
  col = 1, -- CursorSpinner window position, relative to cursor.
}

M.opts = default_opts

---Setup config.
---@param opts? spinner.Config
function M.setup(opts)
  M.opts = vim.tbl_extend("force", default_opts, opts or {})

  vim.api.nvim_set_hl(0, "Spinner", { link = "NormalFloat", default = true })
end

return M
