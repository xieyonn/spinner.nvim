---@class spinner.Config: spinner.Opts, spinner.CursorOpts
---@field opts spinner.Opts
local M = {}

---@type spinner.Opts
local default_opts = {
  texts = {
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
  interval = 80, -- refresh millisecond.
  ttl = 0, -- the spinner will automatically stop after that {ttl} millisecond.
  initial_delay = 200, -- delay display spinner after {initial_delay} millisecond.

  -- CursorSpinner Options
  hl_group = "Spinner", -- highlight group for spinner text, link to NormalFloat by default.
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
