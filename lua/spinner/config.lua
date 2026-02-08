local M = {}

---@class spinner.Config
---@field pattern? string|spinner.Pattern
---@field ttl_ms? integer
---@field initial_delay_ms? integer
---@field placeholder? string|boolean
---@field cursor_spinner? spinner.CursorSpinnerConfig
---@field extmark_spinner? spinner.ExtmarkSpinnerConfig
---
---@class spinner.CursorSpinnerConfig
---@field hl_group? string
---@field winblend? integer
---@field zindex? integer
---@field row? integer
---@field col? integer
---@field border? string
---
---@class spinner.ExtmarkSpinnerConfig
---@field hl_group? string

---@type spinner.Config
local default_config = {
  -- Pre-defined pattern key name in lua/spinner/pattern.lua
  pattern = "dots",

  -- Time-to-live in milliseconds since the most recent start, after which the
  -- spinner stops, preventing it from running indefinitely.
  ttl_ms = 0,

  -- Milliseconds to wait after startup before showing the spinner.
  -- This helps prevent the spinner from briefly flashing for short-lived tasks.
  initial_delay_ms = 0,

  -- Text displayed when the spinner is inactive.
  -- Used in statusline/tabline/winbar/extmark/cursor
  --
  -- true: show an empty string, with length equal to spinner frames.
  -- false: equals to "".
  -- or string values
  --
  -- eg: show ✔ when lsp progress finished.
  placeholder = false,

  cursor_spinner = {
    -- Highlight group for text, use fg of `Comment` by default.
    hl_group = "Spinner",

    -- CursorSpinner window option.
    winblend = 60,

    -- CursorSpinner window option.
    zindex = 50,

    -- CursorSpinner window position, relative to cursor.
    row = -1,

    -- CursorSpinner window position, relative to cursor.
    col = 1,

    -- CursorSpinner window option.
    border = "none",
  },

  extmark_spinner = {
    -- Highlight group for text, use fg of `Comment` by default.
    hl_group = "Spinner",
  },
}

---@type spinner.Config
M.global = default_config

---Validate config options using vim.validate
---@param opts? spinner.Config
local function validate_config(opts)
  if not opts then
    return
  end

  vim.validate(
    "opts.pattern",
    opts.pattern,
    function(x)
      if x == nil then
        return true
      elseif type(x) == "string" then
        local patterns = require("spinner.pattern")
        return patterns[x] ~= nil
      elseif type(x) == "table" then
        -- If it's a table, validate that it has interval and frames
        return x.interval ~= nil
          and type(x.interval) == "number"
          and x.frames ~= nil
          and type(x.frames) == "table"
          and #x.frames > 0
      else
        return false
      end
    end,
    true,
    "pattern must be a string (existing pattern name) or a table with interval (number) and frames (non-empty table)"
  )

  vim.validate("opts.ttl_ms", opts.ttl_ms, function(x)
    return x == nil or (type(x) == "number" and x >= 0)
  end, true, "ttl_ms must be a number >= 0")
  vim.validate("opts.initial_delay_ms", opts.initial_delay_ms, function(x)
    return x == nil or (type(x) == "number" and x >= 0)
  end, true, "initial_delay_ms must be a number >= 0")
  vim.validate("opts.placeholder", opts.placeholder, function(x)
    return x == nil or type(x) == "string" or type(x) == "boolean"
  end, true, "placeholder must be a string or boolean")

  local cs = opts.cursor_spinner
  if cs ~= nil then
    vim.validate("cs.hl_group", cs.hl_group, function(x)
      return x == nil or type(x) == "string"
    end, true, "hl_group must be a string")

    vim.validate("cs.winblend", cs.winblend, function(x)
      return x == nil or (type(x) == "number" and x >= 0 and x <= 100)
    end, true, "winblend must be a number between 0 and 100")

    vim.validate("cs.zindex", cs.zindex, function(x)
      return x == nil or (type(x) == "number" and x >= 0)
    end, true, "zindex must be a number >= 0")

    vim.validate("cs.row", cs.row, function(x)
      return x == nil or type(x) == "number"
    end, true, "row must be a number")

    vim.validate("cs.col", cs.col, function(x)
      return x == nil or type(x) == "number"
    end, true, "col must be a number")

    vim.validate("cs.border", cs.border, function(x)
      return x == nil or type(x) == "string"
    end, true, "border must be a string")
  end

  local es = opts.extmark_spinner
  if es ~= nil then
    vim.validate("es.hl_group", es.hl_group, function(x)
      return x == nil or type(x) == "string"
    end, true, "hl_group must be a string")
  end
end

---Setup config.
---@param opts? spinner.Config
function M.setup(opts)
  validate_config(opts)
  M.global = vim.tbl_extend("force", default_config, opts or {})

  -- Get NormalFloat attributes and only apply foreground color
  local normal_float_hl =
    vim.api.nvim_get_hl(0, { name = "Comment", link = false })
  local spinner_hl = { fg = normal_float_hl.fg, default = true }
  vim.api.nvim_set_hl(0, "Spinner", spinner_hl)
end

return M
