local config = require("spinner.config")
local event = require("spinner.event")
local pattern_map = require("spinner.pattern")
local ui = require("spinner.ui")
local utils = require("spinner.utils")

local STATUS = require("spinner.status")

---@alias spinner.UIScope
---| "statusline" -- Status line UI scope
---| "tabline" -- Tab line UI scope
---| "cursor" -- Cursor UI scope
---| string -- Custom UI scope

---@alias spinner.Kind
---| "custom" -- Custom UI kind
---| "statusline" -- Statusline spinner
---| "tabline" -- Tabline spinner
---| "winbar" -- Winbarspinner
---| "cursor" -- Cursor spinner
---| "extmark" -- Extmark spinner
---| "cmdline" -- CommandLine spinner

---@alias spinner.Opts
---| spinner.CoreOpts -- Core options
---| spinner.StatuslineOpts -- Status line options
---| spinner.TablineOpts -- Tabline options
---| spinner.WinbarOpts -- Winbar options
---| spinner.CursorOpts -- Cursor options
---| spinner.ExtmarkOpts -- Extmark options
---| spinner.CmdlineOpts -- CommandLine options
---
---@class spinner.CoreOpts
---@field kind? spinner.Kind -- Spinner kind
---@field pattern? string|spinner.Pattern -- Animation pattern
---@field ttl_ms? integer -- Time to live in ms
---@field initial_delay_ms? integer -- Initial delay in ms
---@field placeholder? string|boolean -- Placeholder text
---@field attach? spinner.Event -- Event attachment
---@field on_update_ui? fun(event: spinner.OnChangeEvent) -- UI update callback
---@field ui_scope? string custom ui_scope
---@field fmt? fun(event: spinner.OnChangeEvent): string -- Format function
---
---@class spinner.StatuslineOpts: spinner.CoreOpts
---@field kind "statusline" -- Statusline kind
---
---@class spinner.TablineOpts: spinner.CoreOpts
---@field kind "tabline" -- Tabline kind
---
---@class spinner.WinbarOpts: spinner.CoreOpts
---@field kind "winbar" -- Winbar kind
---
---@class spinner.CursorOpts: spinner.CoreOpts
---@field kind "cursor" -- Cursor kind
---@field hl_group? string -- Highlight group
---@field row? integer -- Position relative to cursor
---@field col? integer -- Position relative to cursor
---@field zindex? integer -- Z-index
---@field border? string -- Border style
---@field winblend? integer -- Window blend
---
---@class spinner.ExtmarkOpts: spinner.CoreOpts
---@field kind "extmark" -- Extmark kind
---@field bufnr integer -- Buffer number
---@field row integer -- Line position 0-based
---@field col integer -- Column position 0-based
---@field ns? integer -- Namespace
---@field hl_group? string -- Highlight group
---
---@class spinner.CmdlineOpts: spinner.CoreOpts
---@field kind "cmdline" -- CommandLine kind
---
---@class spinner.OnChangeEvent
---@field status spinner.Status -- Current status
---@field text string -- Current text

---@class spinner.State
---@field id string -- Spinner identifier
---@field started boolean -- Whether spinner is started
---@field index integer -- Current frame index
---@field active integer -- Active reference count
---@field status spinner.Status -- Current status
---@field start_time integer -- Start time in ms
---@field last_spin integer -- Last spin time in ms
---@field ui_scope spinner.UIScope -- UI scope
---@field ui_updater spinner.UIUpdater -- UI update function
---@field interval integer -- Animation interval
---@field frames string[] -- Animation frames
---@field opts spinner.Opts -- Configuration options
local M = {}
M.__index = M

---Validate spinner options using vim.validate
---@param opts spinner.Opts
local function validate_opts(opts)
  vim.validate(
    "opts.kind",
    opts.kind,
    function(x)
      if x == nil then
        return true
      end
      return type(x) == "string"
        and vim.tbl_contains({
          "statusline",
          "tabline",
          "winbar",
          "cursor",
          "extmark",
          "cmdline",
          "custom",
        }, x)
    end,
    true,
    "kind must be a string and one of: statusline, tabline, winbar, cursor, extmark, cmdline, custom"
  )

  vim.validate(
    "opts.pattern",
    opts.pattern,
    function(x)
      if x == nil then
        return true
      end
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
    return x == nil or (type(x) == "number" and x >= 0)
  end, true, "ttl_ms must be a number >= 0")

  vim.validate("opts.initial_delay_ms", opts.initial_delay_ms, function(x)
    return x == nil or (type(x) == "number" and x >= 0)
  end, true, "initial_delay_ms must be a number >= 0")

  vim.validate(
    "opts.placeholder",
    opts.placeholder,
    { "string", "boolean" },
    true,
    "placeholder must be a string or boolean"
  )

  if opts.kind == "cursor" then
    vim.validate(
      "opts.hl_group",
      opts.hl_group,
      "string",
      true,
      "hl_group must be a string"
    )
    vim.validate("opts.winblend", opts.winblend, function(x)
      return x == nil or (type(x) == "number" and x >= 0 and x <= 100)
    end, true, "winblend must be a number between 0 and 100")
    vim.validate("opts.zindex", opts.zindex, function(x)
      return x == nil or (type(x) == "number" and x >= 0)
    end, true, "zindex must be a number >= 0")
    vim.validate("opts.row", opts.row, "number", true, "row must be a number")
    vim.validate("opts.col", opts.col, "number", true, "col must be a number")
    vim.validate("opts.border", opts.border, { "string", "table" }, true)
  end

  if opts.kind == "extmark" then
    vim.validate(
      "opts.bufnr",
      opts.bufnr,
      "number",
      true,
      "bufnr must be a number"
    )
    vim.validate("opts.row", opts.row, "number", true, "row must be a number")
    vim.validate("opts.col", opts.col, "number", true, "col must be a number")
    vim.validate("opts.ns", opts.ns, "number", true, "ns must be a number")
    vim.validate(
      "opts.hl_group",
      opts.hl_group,
      "string",
      true,
      "hl_group must be a string"
    )
  end

  if opts.kind == "custom" and opts.on_update_ui == nil then
    vim.notify(
      "[spinner.nvim] custom spinner must provided option on_update_ui",
      vim.log.levels.WARN
    )
  end
end

---Merge Opts
---@param opts? spinner.Opts
local function merge_opts(opts)
  if opts then
    validate_opts(opts)
  end

  opts = opts or {}

  opts.kind = opts.kind or "custom"
  opts.pattern = vim.F.if_nil(opts.pattern, config.global.pattern)

  if type(opts.pattern) == "string" then
    opts.pattern = pattern_map[opts.pattern]
  end

  local placeholder = opts.placeholder
  if placeholder == false then
    -- disable placeholder
    opts.placeholder = nil
  elseif placeholder == true then
    -- use a empty string with same length of frames as placeholder
    local first_frame = opts.pattern.frames and opts.pattern.frames[1] or ""
    opts.placeholder = string.rep(" ", vim.fn.strdisplaywidth(first_frame))
  end

  opts.ttl_ms = vim.F.if_nil(opts.ttl_ms, config.global.ttl_ms)
  opts.initial_delay_ms =
    vim.F.if_nil(opts.initial_delay_ms, config.global.initial_delay_ms)

  if opts.kind == "cursor" then
    opts.hl_group =
      vim.F.if_nil(opts.hl_group, config.global.cursor_spinner.hl_group)
    opts.winblend =
      vim.F.if_nil(opts.winblend, config.global.cursor_spinner.winblend)
    opts.zindex = vim.F.if_nil(opts.zindex, config.global.cursor_spinner.zindex)
    opts.row = vim.F.if_nil(opts.row, config.global.cursor_spinner.row)
    opts.col = vim.F.if_nil(opts.col, config.global.cursor_spinner.col)
    opts.border = vim.F.if_nil(opts.border, config.global.cursor_spinner.border)
  end

  if opts.kind == "extmark" then
    opts.hl_group =
      vim.F.if_nil(opts.hl_group, config.global.extmark_spinner.hl_group)
  end

  return opts
end

---Render spinner as text
---@return string
function M:render()
  local text = ""

  if self.status == STATUS.DELAYED or self.status == STATUS.STOPPED then
    -- apply placeholder
    if self.opts.kind == "cmdline" then
      -- cmdline text do not support placeholder
      return ""
    end

    text = self.opts.placeholder or "" --[[@as string]]
  else
    text = self.opts.pattern.frames[self.index] or ""
  end

  if text ~= "" and self.opts.kind == "cmdline" then
    text = "{{SPINNER_HIGHLIGHT}}" .. text .. "{{END_HIGHLIGHT}}"
  end

  if self.opts.fmt then
    text = self.opts.fmt({
      text = text,
      status = self.status,
    })
  end

  return text or ""
end

---Start spinner.
---@return boolean need refresh UI
---@return integer|nil next schedule time, nil means no schedule.
function M:start()
  if STATUS.PAUSED == self.status then
    local now_ms = utils.now_ms()
    -- NO active + 1
    self.status = STATUS.RUNNING
    self.last_spin = 0

    if
      self.opts.initial_delay_ms > 0
      and now_ms - self.start_time < self.opts.initial_delay_ms
    then
      -- call start() when PAUSED, but already started, just wait for delay.
      return false, nil
    end

    -- PAUSED -> RUNNING
    self.start_time = now_ms

    -- let spinner animated immediately
    return self:spin(now_ms)
  end

  self.active = self.active + 1

  -- prevent start twice
  if self.started then
    return false, nil
  end
  self.started = true

  self.start_time = utils.now_ms()
  self.last_spin = 0

  if self.opts.initial_delay_ms > 0 then
    -- STOPPED -> DELAYED
    self.status = STATUS.DELAYED
    return false, self.opts.initial_delay_ms
  end

  -- STOPPED -> RUNNING
  self.status = STATUS.RUNNING
  return true, self.opts.pattern.interval
end

---Do stop
---@param self spinner.State
local function do_stop(self)
  self.started = false
  self.active = 0
  self.status = STATUS.STOPPED
  self.start_time = 0
  self.last_spin = 0
end

---Stop spinner.
---@param force? boolean
---@return boolean true if spinner is fully stopped, false if still running with active refs
---@return boolean true if spinner needs UI refresh, false if no refresh needed
function M:stop(force)
  if force == true then
    if self.status == STATUS.STOPPED then
      -- Already stopped, no UI refresh needed
      return true, false -- Fully stopped, no UI refresh
    end
    do_stop(self)
    return true, true -- Fully stopped, needs UI refresh
  end

  if self.status == STATUS.STOPPED then
    -- Already stopped, no UI refresh needed
    return true, false -- Fully stopped, no UI refresh
  end

  if self.active <= 0 then
    -- No active references, not fully stopped but no UI refresh needed
    return false, false -- Not fully stopped, no UI refresh
  end

  self.active = self.active - 1
  if self.active > 0 then
    -- no enough call times for stop(), spinner still running
    return false, false -- Not fully stopped, no UI refresh
  end

  do_stop(self)
  return true, true -- Fully stopped, needs UI refresh
end

function M:pause()
  if STATUS.RUNNING == self.status or STATUS.DELAYED == self.status then
    self.status = STATUS.PAUSED
    self.last_spin = 0
  end
end

---comment
---@param now_ms integer
---@return boolean
---@return integer|nil
function M:step(now_ms)
  if STATUS.STOPPED == self.status or STATUS.PAUSED == self.status then
    return false, nil
  end

  -- check ttl
  if self.opts.ttl_ms > 0 and now_ms >= self.start_time + self.opts.ttl_ms then
    local was_fully_stopped, needs_ui_refresh = self:stop()
    if was_fully_stopped then
      -- Spinner has fully stopped due to TTL expiration
      return needs_ui_refresh, nil
    end
  end

  if STATUS.DELAYED == self.status then
    local delay_end = self.start_time + self.opts.initial_delay_ms
    if now_ms < delay_end then
      return false, delay_end - now_ms
    end

    self.status = STATUS.RUNNING
    self.last_spin = 0
  end

  return self:spin(now_ms)
end

---Spin
---@param now_ms integer current schedule time
---@return boolean true means need update UI.
---@return integer|nil next schedule time, relative time
function M:spin(now_ms)
  local length = #self.opts.pattern.frames or 1
  self.index = (self.index % length) + 1

  local interval = self.opts.pattern.interval
  local next_spin = interval
  if self.last_spin > 0 then
    -- a make up for timer if last schedule elaspse > interval
    local drift = now_ms - self.last_spin - interval
    if drift > 0 and drift < interval / 2 then
      -- schedule as soon as possible
      next_spin = self.opts.pattern.interval - drift
    end
  end

  self.last_spin = now_ms

  return true, next_spin
end

function M:config(opts)
  opts = vim.tbl_extend("force", self.opts or {}, opts or {})
  self.opts = merge_opts(opts)

  self.ui_scope, self.ui_updater = ui.get_ui_updater(self)

  if self.opts.attach then
    event.attach(self.id, self.opts.attach)
  end
end

---Create a state
---
---@param id string
---@param opts? spinner.Opts
---@return spinner.State
local function new(id, opts)
  local s = setmetatable({
    id = id,
    started = false,
    index = 1,
    active = 0,
    status = STATUS.STOPPED,
    start_time = 0,
    last_spin = 0,
    opts = merge_opts(opts),
  }, M)

  s.ui_scope, s.ui_updater = ui.get_ui_updater(s)

  return s
end

return {
  new = new,
}
