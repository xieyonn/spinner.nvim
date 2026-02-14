---@class spinner.config
local M = {}

---@class spinner.Config
---@field pattern? string|spinner.Pattern
---@field ttl_ms? integer
---@field initial_delay_ms? integer
---@field placeholder? string|boolean
---@field hl_group? string|spinner.HighlightGroup
---@field cursor_spinner? spinner.CursorSpinnerConfig
---
---@class spinner.CursorSpinnerConfig
---@field winblend? integer
---@field zindex? integer
---@field row? integer
---@field col? integer

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

  -- Text displayed when the spinner is idle/stoped.
  --
  -- true: show an empty string, with length equal to spinner frames.
  -- false: equals to "".
  -- or string value, eg: show ✔ when lsp progress finished.
  -- or a table value, eg: { init = "", stopped = "" }
  placeholder = false,

  -- Highlight group for text, use fg of `Comment` by default.
  -- or be a table { init = "", running = "", paused = "", stopped = "" }
  hl_group = "Spinner",

  cursor_spinner = {
    -- CursorSpinner window option.
    winblend = 60,

    -- CursorSpinner window option.
    zindex = 50,

    -- CursorSpinner window position, relative to cursor.
    row = -1,

    -- CursorSpinner window position, relative to cursor.
    col = 1,
  },
}

M.global = default_config ---@type spinner.Config

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
      if type(x) == "string" then
        ---@cast x string
        local patterns = require("spinner.pattern")
        return patterns[x] ~= nil
      end
      if type(x) == "table" then
        -- If it's a table, validate that it has interval and frames
        ---@cast x spinner.Pattern
        return x.interval ~= nil
          and type(x.interval) == "number"
          and x.interval > 0
          and x.frames ~= nil
          and type(x.frames) == "table"
          and #x.frames > 0
      end
      return false
    end,
    true,
    "pattern must be a string (existing pattern name) or a table with interval (number) and frames (non-empty table)"
  )

  vim.validate("opts.ttl_ms", opts.ttl_ms, function(x)
    return (type(x) == "number" and x >= 0)
  end, true, "ttl_ms must be a number >= 0")
  vim.validate("opts.initial_delay_ms", opts.initial_delay_ms, function(x)
    return (type(x) == "number" and x >= 0)
  end, true, "initial_delay_ms must be a number >= 0")

  vim.validate("opts.placeholder", opts.placeholder, function(x)
    local t = type(x)
    if t == "string" then
      return true
    end
    if t == "boolean" then
      return true
    end
    if t == "table" then
      if x.init and type(x.init) ~= "string" then
        return false, "placeholder.init must be nil or string"
      end
      if x.stopped and type(x.stopped) ~= "string" then
        return false, "placeholder.stopped must be nil or string"
      end

      return true
    end
    return false,
      "placeholder must be a string or boolean or table with optional field init, stopped"
  end, true)

  vim.validate("opts.hl_group", opts.hl_group, function(x)
    local t = type(x)
    if t == "string" then
      return true
    end
    if t == "table" then
      if x.init and type(x.init) ~= "string" then
        return false, "hl_group.init must be nil or string"
      end
      if x.paused and type(x.paused) ~= "string" then
        return false, "hl_group.paused must be nil or string"
      end
      if x.running and type(x.running) ~= "string" then
        return false, "hl_group.running must be nil or string"
      end
      if x.stopped and type(x.stopped) ~= "string" then
        return false, "hl_group.stopped must be nil or string"
      end
      return true
    end
    return false,
      "hl_group must be a string or table with optional field init, paused, running, stopped"
  end, true)

  if opts.cursor_spinner then
    vim.validate(
      "opts.cursor_spinner.winblend",
      opts.cursor_spinner.winblend,
      function(x)
        return (type(x) == "number" and x >= 0 and x <= 100)
      end,
      true,
      "winblend must be a number between 0 and 100"
    )

    vim.validate(
      "opts.cursor_spinner.zindex",
      opts.cursor_spinner.zindex,
      function(x)
        return (type(x) == "number" and x >= 0)
      end,
      true,
      "zindex must be a number >= 0"
    )

    vim.validate(
      "opts.cursor_spinner.row",
      opts.cursor_spinner.row,
      "number",
      true,
      "row must be a number"
    )

    vim.validate(
      "opts.cursor_spinner.col",
      opts.cursor_spinner.col,
      "number",
      true,
      "col must be a number"
    )
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
  vim.api.nvim_set_hl(0, "Spinner", { fg = normal_float_hl.fg, default = true })
end

return M
