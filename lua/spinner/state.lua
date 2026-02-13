-- State Transition Diagram:
--
-- 1. Creation:
--    new() → INIT
--
-- 2. Start (start()):
--    INIT → DELAYED  (if initial_delay_ms > 0)
--    INIT → RUNNING  (if initial_delay_ms == 0)
--    STOPPED → DELAYED  (if initial_delay_ms > 0)
--    STOPPED → RUNNING  (if initial_delay_ms == 0)
--    PAUSED → RUNNING  (resume from pause)
--
-- 3. Stop (stop()):
--    RUNNING → STOPPED  (when active refs reach 0 or force stop)
--    DELAYED → STOPPED  (when active refs reach 0 or force stop)
--    PAUSED → STOPPED   (when active refs reach 0 or force stop)
--    INIT → STOPPED     (via stop() with force or active refs)
--
-- 4. Pause (pause()):
--    RUNNING → PAUSED
--    DELAYED → PAUSED
--
-- 5. Automatic transitions:
--    DELAYED → RUNNING  (after initial_delay_ms expires in step())
--    RUNNING → STOPPED  (when TTL expires in step())
--
-- State semantics:
-- - INIT: Configured but never started (no API calls yet)
-- - STOPPED: Previously started, then stopped
-- - DELAYED: Initial delay before animation starts
-- - RUNNING: Actively animating
-- - PAUSED: Animation paused (can be resumed)
--
-- Active reference counting:
-- - start() increments active count
-- - stop() decrements active count; state becomes STOPPED when count reaches 0
-- - force stop ignores active count and immediately stops

local config = require("spinner.config")
local event = require("spinner.event")
local pattern_map = require("spinner.pattern")
local set = require("spinner.set")
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
---| "window-title" -- WindowTitle spinner
---| "window-footer" -- WindowFooter spinner

---@alias spinner.Opts
---| spinner.CoreOpts -- Core options
---| spinner.CustomOpts -- Custom options
---| spinner.StatuslineOpts -- Status line options
---| spinner.TablineOpts -- Tabline options
---| spinner.WinbarOpts -- Winbar options
---| spinner.CursorOpts -- Cursor options
---| spinner.ExtmarkOpts -- Extmark options
---| spinner.CmdlineOpts -- CommandLine options
---| spinner.WindowTitleOpts -- WindowTitle options
---| spinner.WindowFooterOpts -- WindowFooter options
---
---@class spinner.CoreOpts
---@field kind? spinner.Kind -- Spinner kind
---@field pattern? string|spinner.Pattern -- Animation pattern
---@field ttl_ms? integer -- Time to live in ms
---@field initial_delay_ms? integer -- Initial delay in ms
---@field placeholder? string|boolean|spinner.Placeholder -- Placeholder text
---@field attach? spinner.Event -- Event attachment
---@field on_update_ui? fun(event: spinner.OnChangeEvent) -- UI update callback
---@field ui_scope? string custom ui_scope, used to improve UI refresh performance
---@field fmt? fun(event: spinner.OnChangeEvent): string -- Format function
---
---@class spinner.Placeholder
---@field init? string -- when status == init (new create)
---@field stopped? string -- when status == stopped
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
---@field row? integer -- Position relative to cursor
---@field col? integer -- Position relative to cursor
---@field hl_group? string|spinner.HighlightGroup -- Highlight group
---@field zindex? integer -- Z-index
---@field winblend? integer -- Window blend
---
---@class spinner.HighlightGroup
---@field init? string -- used in init status
---@field running? string -- used in running status
---@field paused? string -- used in paused status
---@field stopped? string -- used in stopped status
---
---@class spinner.ExtmarkOpts: spinner.CoreOpts
---@field kind "extmark" -- Extmark kind
---@field bufnr integer -- Buffer number
---@field row integer -- Line position 0-based
---@field col integer -- Column position 0-based
---@field ns? integer -- Namespace
---@field virt_text_pos? string -- options for vim.api.nvim_buf_set_extmark
---@field virt_text_win_col? integer -- options for `vim.api.nvim_buf_set_extmarks`
---
---@class spinner.CmdlineOpts: spinner.CoreOpts
---@field kind "cmdline" -- CommandLine kind
---
---@class spinner.WindowTitleOpts: spinner.CoreOpts
---@field kind "window-title"
---@field win integer -- target win id
---@field pos? string -- position, can be on of "left", "center" or "right"
---
---@class spinner.WindowFooterOpts: spinner.CoreOpts
---@field kind "window-footer"
---@field win integer -- target win id
---@field pos? string -- position, can be on of "left", "center" or "right"
---
---@class spinner.CustomOpts: spinner.CoreOpts
---@field kind "custom"
---@field on_update_ui fun(event: spinner.OnChangeEvent) -- UI update callback
---@field ui_scope? string custom ui_scope, use spinner id by default
---
---@class spinner.OnChangeEvent
---@field status spinner.Status -- Current status
---@field text string -- Current text
---@field hl_group? string -- Current hl_group

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
      return type(x) == "string"
        and vim.list_contains({
          "statusline",
          "tabline",
          "winbar",
          "cursor",
          "extmark",
          "cmdline",
          "custom",
          "window-title",
          "window-footer",
        }, x)
    end,
    true,
    "kind must be a string and one of: statusline, tabline, winbar, cursor, extmark, cmdline, custom, window-title, window-footer"
  )

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
          and x.frames ~= nil
          and type(x.frames) == "table"
          and #x.frames > 0
      end
      return false
    end,
    true,
    "pattern must be a string (existing pattern name) or a table with interval (number) and frames (non-empty table)"
  )

  vim.validate(
    "opts.fmt",
    opts.fmt,
    "callable",
    true,
    "fmt must be a function or callable function"
  )

  vim.validate("opts.ttl_ms", opts.ttl_ms, function(x)
    return x == nil or (type(x) == "number" and x >= 0)
  end, true, "ttl_ms must be a number >= 0")

  vim.validate("opts.initial_delay_ms", opts.initial_delay_ms, function(x)
    return x == nil or (type(x) == "number" and x >= 0)
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

  if opts.kind == "cursor" then
    vim.validate("opts.winblend", opts.winblend, function(x)
      return x == nil or (type(x) == "number" and x >= 0 and x <= 100)
    end, true, "winblend must be a number between 0 and 100")
    vim.validate("opts.zindex", opts.zindex, function(x)
      return x == nil or (type(x) == "number" and x >= 0)
    end, true, "zindex must be a number >= 0")
    vim.validate("opts.row", opts.row, "number", true, "row must be a number")
    vim.validate("opts.col", opts.col, "number", true, "col must be a number")
  end

  if opts.kind == "extmark" then
    vim.validate(
      "opts.bufnr",
      opts.bufnr,
      "number",
      false,
      "bufnr must be a number"
    )
    vim.validate("opts.row", opts.row, "number", false, "row must be a number")
    vim.validate("opts.col", opts.col, "number", false, "col must be a number")
    vim.validate("opts.ns", opts.ns, "number", true, "ns must be a number")
    vim.validate(
      "opts.virt_text_pos",
      opts.virt_text_pos,
      "string",
      true,
      "virt_text_pos must be a string"
    )
    vim.validate(
      "opts.virt_text_win_col",
      opts.virt_text_win_col,
      "number",
      true,
      "virt_text_win_col must be a number"
    )
  end

  if opts.kind == "custom" then
    vim.validate(
      "opts.ui_scope",
      opts.ui_scope,
      "string",
      true,
      "ui_scope must be a string"
    )
    vim.validate(
      "opts.on_update_ui",
      opts.on_update_ui,
      "callable",
      false,
      "custom spinner must provided on_update_ui, and must be a function or callable"
    )
  end

  if opts.kind == "window-title" or opts.kind == "window-footer" then
    vim.validate("opts.win", opts.win, "number", false, "win must be a number")
    vim.validate("opts.pos", opts.pos, function(x)
      return type(x) == "string"
        and vim.list_contains({ "left", "center", "right" }, x)
    end, true, "pos must be a string and one of: left, center, right")
  end
end

---Merge Opts
---@param opts? spinner.Opts
---@return spinner.Opts opts
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
    opts.placeholder = (" "):rep(vim.fn.strdisplaywidth(first_frame))
  end

  opts.ttl_ms = vim.F.if_nil(opts.ttl_ms, config.global.ttl_ms)
  opts.initial_delay_ms =
    vim.F.if_nil(opts.initial_delay_ms, config.global.initial_delay_ms)

  if opts.kind == "cursor" then
    opts.winblend =
      vim.F.if_nil(opts.winblend, config.global.cursor_spinner.winblend)
    opts.zindex = vim.F.if_nil(opts.zindex, config.global.cursor_spinner.zindex)
    opts.row = vim.F.if_nil(opts.row, config.global.cursor_spinner.row)
    opts.col = vim.F.if_nil(opts.col, config.global.cursor_spinner.col)
  end

  if opts.kind == "window-title" or opts.kind == "window-footer" then
    opts.pos = opts.pos or "center"
  end

  --for backward compatibility, statusline/tabline/winbar do not use global hl_group
  --before v1.0.4
  if
    not vim.list_contains({ "statusline", "tabline", "winbar" }, opts.kind)
  then
    opts.hl_group = vim.F.if_nil(opts.hl_group, config.global.hl_group)
  end

  return opts
end

---Get placeholder
---@return string
---@private
function M:get_placeholder()
  if nil == self.opts.placeholder then
    return ""
  end

  local t = type(self.opts.placeholder)
  if t == "string" then
    return self.opts.placeholder --[[@as string]]
  end

  if t == "table" then
    if STATUS.INIT == self.status then
      return self.opts.placeholder.init or "" --[[@as string]]
    end

    if STATUS.STOPPED == self.status then
      return self.opts.placeholder.stopped or "" --[[@as string]]
    end
  end

  return ""
end

---Get hl_group value, base on kind or status
---@return string|nil
function M:get_hl_group()
  if nil == self.opts.hl_group then
    return nil
  end

  local t = type(self.opts.hl_group)
  if t == "string" then
    return self.opts.hl_group --[[@as string]]
  end
  if t == "table" then
    if STATUS.INIT == self.status then
      return self.opts.hl_group.init
    end
    if STATUS.PAUSED == self.status then
      return self.opts.hl_group.paused
    end
    if STATUS.RUNNING == self.status then
      return self.opts.hl_group.running
    end
    if STATUS.STOPPED == self.status then
      return self.opts.hl_group.stopped
    end
  end

  return nil
end

---@type spinner.Set used in render()
local hl_group_line = set.new({
  "statusline",
  "tabline",
  "winbar",
})

---Render spinner as text
---@return string text
function M:render()
  local text = ""

  if
    self.status == STATUS.DELAYED
    or self.status == STATUS.STOPPED
    or self.status == STATUS.INIT
  then
    text = self:get_placeholder()
  else
    text = self.opts.pattern.frames[self.index] or ""
  end

  -- apply hl_group
  local hl = self:get_hl_group()
  if text ~= "" and hl and hl ~= "" then
    if self.opts.kind == "cmdline" then
      -- cmdline should separate text and format text
      text = ("{{SPINNER_HIGHLIGHT}}%s{{END_HIGHLIGHT}}"):format(text)
    end

    -- apply hl_group format for lines: %#hl_group# text %*
    if hl_group_line:has(self.opts.kind) then
      text = string.format("%%#%s#%s%%*", hl, text)
    end
  end

  if self.opts.fmt then
    text = self.opts.fmt({
      text = text,
      status = self.status,
      hl_group = hl,
    })
  end

  return text or ""
end

---Start spinner.
---@return boolean need_refresh_ui
---@return integer|nil next_time, nil means no schedule.
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
    -- INIT/STOPPED -> DELAYED
    self.status = STATUS.DELAYED
    return false, self.opts.initial_delay_ms
  end

  -- INIT/STOPPED -> RUNNING
  self.status = STATUS.RUNNING
  return true, self.opts.pattern.interval
end

---Do stop
---@private
---
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
    if self.status == STATUS.STOPPED or self.status == STATUS.INIT then
      -- Already stopped or never started, no UI refresh needed
      return true, false
    end
    do_stop(self)
    return true, true -- Fully stopped, needs UI refresh
  end

  if self.status == STATUS.STOPPED then
    -- Already stopped, no UI refresh needed
    return true, false
  end

  if self.status == STATUS.INIT then
    -- Never started, converts INIT to STOPPED, need ui refresh
    do_stop(self)
    return true, true
  end

  if self.active <= 0 then
    -- No active references, not fully stopped but no UI refresh needed
    return false, false
  end

  self.active = self.active - 1
  if self.active > 0 then
    -- no enough call times for stop(), spinner still running
    return false, false
  end

  do_stop(self)
  return true, true -- Fully stopped, needs UI refresh
end

---Pause status
function M:pause()
  if STATUS.RUNNING == self.status or STATUS.DELAYED == self.status then
    self.status = STATUS.PAUSED
    self.last_spin = 0
  end
end

---Run on every schedule tick.
---@param now_ms integer
---@return boolean need_refresh_ui
---@return integer|nil next_time, nil means no schedule.
function M:step(now_ms)
  if
    STATUS.STOPPED == self.status
    or STATUS.PAUSED == self.status
    or STATUS.INIT == self.status
  then
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

---Spin frames
---@private
---
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
  --for backward compatibility, statusline/tabline/winbar do not use global hl_group
  --before v1.0.4
  if
    opts and vim.list_contains({ "statusline", "tabline", "winbar" }, opts.kind)
  then
    self.opts.hl_group = opts.hl_group
  end

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
    status = STATUS.INIT,
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
