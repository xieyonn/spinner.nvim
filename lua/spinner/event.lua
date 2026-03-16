local lsp = require("spinner.event.lsp")

---@class spinner.Event
---@field lsp? spinner.Event.Lsp
---
---@class spinner.Event.Lsp
---@field client_names? string[]
---@field progress? boolean
---@field request? spinner.LspRequest[]

---@alias spinner.LspRequest vim.lsp.protocol.Method.ClientToServer

---@class spinner.event
local M = {}

---Attach spinner to event.
---@param id string
---@param event spinner.Event
function M.attach(id, event)
  if event.lsp then
    if event.lsp.progress == true then
      lsp.progress(id, event.lsp.client_names)
    end

    if event.lsp.request then
      lsp.request(id, event.lsp.request, event.lsp.client_names)
    end
  end
end

return M
