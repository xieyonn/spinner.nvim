local uv = vim.uv or vim.loop
local heap = require("spinner.heap")
local utils = require("spinner.utils")

local SCHEDULE_WINDOW_MS = 10
local IDLE_RELEASE_MS = 10000

---@class spinner.SchedulerTask
---@field at number
---@field job spinner.SchedulerJob

---@alias spinner.SchedulerJob fun(): nil|integer

---@class spinner.Scheduler
---@field private timer uv.uv_timer_t|nil
---@field private tasks spinner.Heap<spinner.SchedulerTask>
local M = {}
M.__index = M

function M.new()
  return setmetatable({
    timer = nil,
    tasks = heap.new(function(a, b)
      -- Use strict less-than to maintain FIFO order for tasks with same time
      return a.at < b.at
    end),
  }, M)
end

---Attempt to stop the timer after IDLE_RELEASE_MS if no tasks remain, Otherwise
---reschedule the next task.
---@private
function M:_try_stop()
  if not self.timer then
    return
  end

  self.timer:stop()
  self.timer:start(
    IDLE_RELEASE_MS,
    0,
    vim.schedule_wrap(function()
      if self.tasks:is_empty() then
        self.timer:stop()
        self.timer:close()
        self.timer = nil
      else
        self:_schedule_next()
      end
    end)
  )
end

---Start or restart the timer with the given delay.
---@private
---@param delay integer milliseconds
function M:_start_timer(delay)
  if self.timer then
    self.timer:stop()
    self.timer:start(
      delay,
      0,
      vim.schedule_wrap(function()
        self:_tick()
      end)
    )
    return
  end

  local ok, timer = pcall(uv.new_timer)
  if not ok or not timer then
    vim.notify("[spinner.nvim]: failed to create uv timer", vim.log.levels.WARN)
    return
  end

  self.timer = timer
  self.timer:start(
    delay,
    0,
    vim.schedule_wrap(function()
      self:_tick()
    end)
  )
end

---Schedule the next timer based on the heap top task. If the heap is empty,
---attempt to stop the timer.
---@private
function M:_schedule_next()
  if self.tasks:is_empty() then
    self:_try_stop()
    return
  end

  local task = self.tasks:peek() --[[@as spinner.SchedulerTask]]
  local delay = math.max(SCHEDULE_WINDOW_MS, task.at - utils.now_ms())
  self:_start_timer(delay)
end

---Executes all tasks ready within SCHEDULE_WINDOW_MS, If a task returns a
---number, it is rescheduled as a periodic task.
---@private
function M:_tick()
  local now = utils.now_ms()
  local ready = {}

  while not self.tasks:is_empty() do
    local task = self.tasks:peek() --[[@as spinner.SchedulerTask]]
    if task.at - now <= SCHEDULE_WINDOW_MS then
      table.insert(ready, task)
      self.tasks:pop()
    else
      break
    end
  end

  for _, task in ipairs(ready) do
    local ok, next_interval = pcall(task.job)
    if ok and type(next_interval) == "number" and next_interval > 0 then
      task.at = now + next_interval
      self.tasks:push(task)
    end
  end

  self:_schedule_next()
end

---schedule {job} to be invoked at absolute time {at} (ms)
---@param job spinner.SchedulerJob
---@param at? integer
function M:schedule(job, at)
  local now = utils.now_ms()
  at = at or now
  at = math.max(at, now + SCHEDULE_WINDOW_MS)

  local task = { job = job, at = at }
  self.tasks:push(task)

  local next_task = self.tasks:peek()
  if next_task == task then
    -- cut in - this task is now the earliest in the heap
    self:_schedule_next()
  end
end

return M
