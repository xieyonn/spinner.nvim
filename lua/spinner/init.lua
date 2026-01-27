local uv = vim.uv

---@class spinner.SpinnerOpts
---@field chars? string[]
---@field speed? integer millisecond
---@field ttl? integer millisecond

---@class spinner.Spinner
---@field private timer uv.uv_timer_t|nil
local Spinner = {}
Spinner.__index = Spinner

---Create a new spinner.
---
---@param o? spinner.SpinnerOpts
---@return spinner.Spinner
function Spinner:new(o)
  local opts = require("spinner.config").opts
  opts = vim.tbl_extend("force", opts, o or {})

  ---@class spinner.Spinner
  local sp = setmetatable({
    opts = opts,
    idx = 0,
    timer = nil,
    enabled = false,
    start_time = 0,
  }, self)

  return sp
end

---Start spinner.
---
---@param on_frame? function called when spinner move to next frame.
function Spinner:start(on_frame)
  if self.enabled then
    return
  end

  self.enabled = true
  if self.opts.ttl > 0 then
    self.start_time = uv.now()
  end
  self.timer = uv.new_timer()
  assert(self.timer, "Failed to create spinner timer")

  self.timer:start(
    0,
    self.opts.speed,
    vim.schedule_wrap(function()
      if on_frame then
        on_frame()
      end
      self.idx = (self.idx % #self.opts.chars) + 1

      if self.opts.ttl > 0 then
        if uv.now() - self.start_time >= self.opts.ttl then
          self:stop()
        end
      end
    end)
  )
end

---Stop spinner.
function Spinner:stop()
  if self.timer then
    self.timer:stop()
    self.timer:close()
    self.timer = nil
  end

  self.enabled = false
end

function Spinner:__tostring()
  return self.enabled and self.opts.chars[self.idx] or ""
end

---@class spinner.CursorOpts: spinner.SpinnerOpts
---@field hl_group? string
---@field winblend? integer
---@field width? integer
---@field row? integer
---@field col? integer
---@field zindex? integer

---@class spinner.CursorSpinner: spinner.Spinner
local CursorSpinner = {}
CursorSpinner.__index = CursorSpinner
CursorSpinner.__tostring = Spinner.__tostring
setmetatable(CursorSpinner, { __index = Spinner })

---Create cursor spinner.
---
---@param o? spinner.CursorOpts
---@return spinner.CursorSpinner
function CursorSpinner:new(o)
  local opts = require("spinner.config").opts
  opts = vim.tbl_extend("force", opts, o or {})
  ---@class spinner.CursorSpinner
  local sp = Spinner.new(self, opts)

  sp.opts = opts
  sp.buf = vim.api.nvim_create_buf(false, true)
  sp.win = nil
  vim.bo[sp.buf].buftype = "nofile"
  vim.bo[sp.buf].bufhidden = "wipe"

  return sp
end

---Start spinner.
---
---@param on_frame? function called when spinner move to next frame.
function CursorSpinner:start(on_frame)
  Spinner.start(self, function()
    if on_frame then
      on_frame()
    end

    local screen_col = vim.fn.win_screenpos(0)[2] + vim.fn.wincol() - 1
    local row = self.opts.row
    local col = self.opts.col
    if screen_col + self.opts.width > vim.o.columns then
      col = -col
    end

    if not self.win or not vim.api.nvim_win_is_valid(self.win) then
      self.win = vim.api.nvim_open_win(self.buf, false, {
        relative = "cursor",
        row = row,
        col = col,
        width = self.opts.width,
        height = 1,
        style = "minimal",
        focusable = false,
        border = "none",
        zindex = self.opts.zindex,
        noautocmd = true,
      })

      vim.wo[self.win].winhighlight = "Normal:" .. self.opts.hl_group
      vim.wo[self.win].winblend = self.opts.winblend
    else
      vim.api.nvim_win_set_config(self.win, {
        relative = "cursor",
        row = row,
        col = col,
      })
    end

    vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, { tostring(self) })
  end)
end

---Stop spinner.
function CursorSpinner:stop()
  Spinner.stop(self)
  if self.win ~= nil and vim.api.nvim_win_is_valid(self.win) then
    vim.api.nvim_win_close(self.win, true)
    self.win = nil
  end
end

function CursorSpinner:__tostring()
  return self.enabled and " " .. Spinner.__tostring(self) .. " " or ""
end

---@class spinner.StatuslineSpinner: spinner.Spinner
local StatuslineSpinner = {}
StatuslineSpinner.__index = Spinner
StatuslineSpinner.__tostring = Spinner.__tostring
setmetatable(StatuslineSpinner, { __index = Spinner })

---Create StatuslineSpinner.
---
---@param opts spinner.SpinnerOpts
---@return spinner.Spinner
function StatuslineSpinner:new(opts)
  ---@class spinner.StatuslineSpinner
  return Spinner.new(self, opts)
end

---Start spinner.
---
---@param on_frame? function
function StatuslineSpinner:start(on_frame)
  Spinner.start(self, function()
    if on_frame then
      on_frame()
    end

    vim.cmd("redrawstatus")
  end)
end

---@class spinner.TablineSpinner: spinner.Spinner
local TablineSpinner = {}
TablineSpinner.__index = Spinner
TablineSpinner.__tostring = Spinner.__tostring
setmetatable(TablineSpinner, { __index = Spinner })

---Create TablineSpinner.
---
---@param opts spinner.SpinnerOpts
---@return spinner.Spinner
function TablineSpinner:new(opts)
  ---@class spinner.TablineSpinner
  return Spinner.new(self, opts)
end

---Start spinner.
---
---@param on_frame? function
function TablineSpinner:start(on_frame)
  Spinner.start(self, function()
    if on_frame then
      on_frame()
    end

    vim.cmd("redrawtabline")
  end)
end

---@class spinner
local M = {
  Spinner = Spinner,
  CursorSpinner = CursorSpinner,
  StatuslineSpinner = StatuslineSpinner,
  TablineSpinner = TablineSpinner,
  setup = require("spinner.config").setup,
}
return M
