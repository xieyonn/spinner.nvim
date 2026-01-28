local uv = vim.uv

---@class spinner.Event
---@field text string
---@field enabled boolean

---@class spinner.Opts
---@field texts? string[]
---@field interval? integer millisecond
---@field ttl? integer millisecond
---@field initial_delay? integer millisecond
---@field on_change? fun(event: spinner.Event)

---@class spinner.Spinner
---@field private timer uv.uv_timer_t|nil
---@field opts spinner.Opts
local Spinner = {}
Spinner.__index = Spinner

---Create a new spinner.
---
---@param o? spinner.Opts
---@return spinner.Spinner
local function new(o)
  local opts = require("spinner.config").opts
  return setmetatable({
    opts = vim.tbl_extend("force", opts, o or {}),
    idx = 0,
    timer = nil,
    enabled = false,
    start_time = 0,
    active = 0,
  }, Spinner)
end

---Start spinner.
function Spinner:start()
  if self.enabled then
    return
  end

  self.enabled = true

  local start = function()
    if not self.enabled then
      return
    end

    -- spinner really start here
    self.active = self.active + 1

    if self.opts.ttl > 0 then
      self.start_time = uv.now()
    end
    self.timer = uv.new_timer()
    assert(self.timer, "Failed to create spinner timer")

    local length = #self.opts.texts

    self.timer:start(
      0,
      self.opts.interval,
      vim.schedule_wrap(function()
        --- spinner may have been stopped
        if not self.enabled then
          return
        end

        if self.opts.on_change then
          self.opts.on_change({
            text = tostring(self),
            enabled = self.enabled,
          })
        end

        self.idx = (self.idx % length) + 1
        if self.opts.ttl > 0 then
          if uv.now() - self.start_time >= self.opts.ttl then
            self:stop()
          end
        end
      end)
    )
  end

  if self.opts.initial_delay > 0 then
    vim.defer_fn(start, self.opts.initial_delay)
  else
    start()
  end
end

---Stop spinner.
function Spinner:stop()
  if not self.enabled then
    return
  end

  self.enabled = false

  self.active = self.active - 1
  if self.active > 0 then
    return
  end

  -- spinner really stop here.
  if self.active < 0 then
    self.active = 0
  end

  if self.timer then
    self.timer:stop()
    self.timer:close()
    self.timer = nil
  end

  if self.opts.on_change then
    self.opts.on_change({
      text = tostring(self),
      enabled = self.enabled,
    })
  end
  self.idx = 0
end

function Spinner:__tostring()
  return self.enabled and self.opts.texts[self.idx] or ""
end

---@class spinner.CursorOpts: spinner.Opts
---@field hl_group? string
---@field winblend? integer
---@field width? integer
---@field row? integer
---@field col? integer
---@field zindex? integer

---Create cursor spinner.
---
---@param o? spinner.CursorOpts
---@return spinner.Spinner
local function cursor_spinner(o)
  local opts = require("spinner.config").opts
  opts = vim.tbl_extend("force", opts, o or {})
  local sp = new(opts)

  local buf = vim.api.nvim_create_buf(false, true)
  local win = nil
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"

  if sp.opts.on_change ~= nil then
    return sp
  end

  sp.opts.on_change = function(event)
    if event.text ~= "" then
      local screen_col = vim.fn.win_screenpos(0)[2] + vim.fn.wincol() - 1
      local row = opts.row
      local col = opts.col
      if screen_col + opts.width > vim.o.columns then
        col = -col
      end

      if not win or not vim.api.nvim_win_is_valid(win) then
        win = vim.api.nvim_open_win(buf, false, {
          relative = "cursor",
          row = row,
          col = col,
          width = opts.width,
          height = 1,
          style = "minimal",
          focusable = false,
          border = "none",
          zindex = opts.zindex,
          noautocmd = true,
        })

        vim.wo[win].winhighlight = "Normal:" .. opts.hl_group
        vim.wo[win].winblend = opts.winblend
      else
        vim.api.nvim_win_set_config(win, {
          relative = "cursor",
          row = row,
          col = col,
        })
      end

      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { tostring(sp) })
      return
    end

    if win ~= nil and vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
      win = nil
    end
  end

  return sp
end

---Create tabline spinner.
---@param o? spinner.Opts
local function tabline_spinner(o)
  local opts = require("spinner.config").opts
  opts = vim.tbl_extend("force", opts, o or {})
  local sp = new(opts)
  if sp.opts.on_change == nil then
    sp.opts.on_change = function()
      vim.cmd("redrawtabline")
    end
  end
  return sp
end

---Create statusline spinner.
---@param o? spinner.Opts
local function statusline_spinner(o)
  local opts = require("spinner.config").opts
  opts = vim.tbl_extend("force", opts, o or {})
  local sp = new(opts)
  if sp.opts.on_change == nil then
    sp.opts.on_change = function()
      vim.cmd("redrawstatus")
    end
  end
  return sp
end

---@class spinner
local M = {
  new = new,
  cursor_spinner = cursor_spinner,
  tabline_spinner = tabline_spinner,
  statusline_spinner = statusline_spinner,
  setup = require("spinner.config").setup,
}
return M
