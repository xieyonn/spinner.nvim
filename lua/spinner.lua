local scheduler = require("spinner.scheduler").new()

local engine = require("spinner.engine").new(scheduler)

require("spinner.cmd").setup(engine)
require("spinner.config").setup()

---@class spinner
local M = {}

---Setup config.
---@param opts? spinner.Config
function M.setup(opts)
  require("spinner.config").setup(opts)
end

---Start spinner.
---@param id string spinner id.
function M.start(id)
  engine:start(id)
end

---Stop spinner.
---@param id string spinner id.
---@param force? boolean
function M.stop(id, force)
  engine:stop(id, force)
end

---Pause spinner.
---@param id string spinner id.
function M.pause(id)
  engine:pause(id)
end

---Setup spinner.
---@param id string spinner id.
---@param opts spinner.Opts
function M.config(id, opts)
  engine:config(id, opts)
end

---Render spinner.
---@param id string spinner id.
---@return string
function M.render(id)
  return engine:render(id)
end

return M
