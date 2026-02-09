---@alias Comparable string|number|boolean|table|function|userdata

---@class spinner.Set
---@field set table<Comparable, boolean>
---@field n integer
local M = {}

M.set = {}
M.n = 0
M.__index = M

---New Set.
---
---@param items Comparable[]|nil
---@return spinner.Set set
function M.new(items)
  if not items then
    return setmetatable({ set = {}, n = 0 }, M)
  end

  local set, n = {}, 0 ---@type table<Comparable, boolean>, integer

  for _, item in ipairs(items) do
    if not set[item] then
      set[item] = true
      n = n + 1
    end
  end

  return setmetatable({ set = set, n = n }, M)
end

---Return boolean value whether an element exist.
---
---@param item Comparable|nil
---@return boolean has
---@nodiscard
function M:has(item)
  if item == nil then
    return false
  end

  return self.set[item] == true
end

---Inserts a new element.
---
---@param item Comparable
function M:add(item)
  if item == nil then
    return
  end

  if self.set[item] then
    return
  end

  self.set[item] = true
  self.n = self.n + 1
end

---Delete an element
---
---@param item Comparable
function M:delete(item)
  if item == nil or not self.set[item] then
    return
  end

  self.set[item] = nil
  self.n = self.n - 1
end

---Clear set.
---
function M:clear()
  self.set = {}
  self.n = 0
end

---Call `f` once for each value present in the Set.
---
---@param f fun(item: Comparable)
function M:for_each(f)
  for item, _ in pairs(self.set) do
    f(item)
  end
end

---Check empty
---@return boolean empty
---@nodiscard
function M:is_empty()
  return self.n == 0
end

return M
