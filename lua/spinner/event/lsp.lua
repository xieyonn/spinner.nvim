local set = require("spinner.set")
local utils = require("spinner.utils")

---@class spinner.event.LSP
local M = {}

---Check client_id is what we want
---@param client_name_set spinner.Set
---@param client_id integer client id
---@return boolean wants
local function want_client(client_name_set, client_id)
  local client = vim.lsp.get_client_by_id(client_id)
  local client_name = client and client.name or nil

  if client_name and client_name_set:has(client_name) then
    return true
  end

  return false
end

---Listen to LspProgress
---@param id string
---@param client_names? string[]
function M.progress(id, client_names)
  local client_name_set = set.new(client_names)

  vim.api.nvim_create_autocmd("LspProgress", {
    group = utils.AUGROUP,
    callback = function(event)
      local client_id = event.data.client_id
      if client_names and not want_client(client_name_set, client_id) then
        return
      end

      local kind = event.data.params.value.kind --[[@as string]]

      if kind == "begin" then
        require("spinner").start(id)
      end

      if kind == "end" then
        require("spinner").stop(id)
      end
    end,
  })
end

---Listen to LspRequest
---@param id string
---@param methods spinner.LspRequest[]
---@param client_names? string[]
function M.request(id, methods, client_names)
  local client_name_set = set.new(client_names)
  local methods_set = set.new(methods)

  vim.api.nvim_create_autocmd("LspRequest", {
    group = utils.AUGROUP,
    callback = function(event)
      local client_id = event.data.client_id
      if client_names and not want_client(client_name_set, client_id) then
        return
      end

      local request = event.data.request
      local method = request.method
      if method and methods and not methods_set:has(method) then
        return
      end

      if request.type == "pending" then
        require("spinner").start(id)
        return
      end
      if vim.list_contains({ "cancel", "complete" }, request.type) then
        require("spinner").stop(id)
      end
    end,
  })
end

return M
