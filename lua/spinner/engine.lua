local new_state = require("spinner.state").new
local utils = require("spinner.utils")

---@class spinner.Engine
---@field scheduler spinner.Scheduler
---@field pending_ui_updater table<string, fun()>
---@field state_map table<string, spinner.State>
local M = {}
M.__index = M

---@param scheduler spinner.Scheduler
---@return spinner.Engine engine
function M.new(scheduler)
  local self = setmetatable({
    scheduler = scheduler,
    pending_ui_updater = {},
    state_map = setmetatable({}, {
      __index = function(self, k)
        local v = rawget(self, k)
        if not v then
          v = new_state(k)
          rawset(self, k, v)
        end

        return v
      end,
    }),
  }, M)

  return self
end

---Batch update UI, combine updaters by UIScope
---@param state spinner.State
function M:update_ui(state)
  local had_existing_updater = self.pending_ui_updater[state.ui_scope] ~= nil
  if had_existing_updater then
    return
  end

  self.pending_ui_updater[state.ui_scope] = state.ui_updater

  self.scheduler:schedule(function()
    -- Collect keys to avoid modifying table during iteration
    local keys_to_remove = {}
    for k, updater in pairs(self.pending_ui_updater) do
      table.insert(keys_to_remove, k)
      local ok, err = pcall(updater)
      if not ok then
        vim.notify_once(
          ("[spinner.nvim]: fail to refresh ui: %s"):format(err),
          vim.log.levels.ERROR
        )
      end
    end

    -- Remove the processed keys
    for _, k in ipairs(keys_to_remove) do
      self.pending_ui_updater[k] = nil
    end

    return nil
  end)
end

---@param state spinner.State
---@return integer|nil next_schedule_time Next schedule time, relative time
function M:step(state)
  local now_ms = utils.now_ms()
  local dirty, next_time = state:step(now_ms)

  if dirty then
    self:update_ui(state)
  end

  return next_time
end

---Starts a spinner with the given ID.
---@param id string
function M:start(id)
  local state = self.state_map[id]
  local dirty, next_time = state:start()
  if dirty then
    self:update_ui(state)
  end

  if next_time ~= nil then
    self.scheduler:schedule(function()
      return self:step(state)
    end, next_time)
  end
end

---Stops a spinner with the given ID.
---@param id string
---@param force? boolean
function M:stop(id, force)
  local state = self.state_map[id]
  local _, needs_ui_refresh = state:stop(force)

  if needs_ui_refresh then
    self:update_ui(state)
  end
end

---Pauses a spinner with the given ID.
---@param id string
function M:pause(id)
  local state = self.state_map[id]
  state:pause()
  self:update_ui(state)
end

---Configures options for a spinner with the given ID.
---@param id string Spinner ID to configure.
---@param opts spinner.Opts Options to configure.
function M:config(id, opts)
  local state = self.state_map[id]
  state:config(opts)
  self:update_ui(state)
end

---Renders the current frame of a spinner with the given ID.
---@param id string Spinner ID to render.
---@return string The rendered spinner frame.
function M:render(id)
  local state = self.state_map[id]
  return state:render()
end

---Reset spinner.
---@param id string
function M:reset(id)
  local state = self.state_map[id]
  state:reset()
  self:update_ui(state)
end

---Fail spinner.
---@param id string
function M:fail(id)
  local state = self.state_map[id]
  state:fail()
  self:update_ui(state)
end

-- Return the class itself, instantiation happens externally
return M
