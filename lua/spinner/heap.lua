---@generic T
---@class spinner.Heap<T>
---@field private size integer
---@field private data T[]
---@field private less fun(a: T, b: T): boolean
local M = {}
M.__index = M

---Create a smallest heap.
---@generic T
---@param less fun(a: T, b: T): boolean
---@return spinner.Heap<T> new_heap
function M.new(less)
  return setmetatable({
    size = 0,
    data = {},
    less = less,
  }, M)
end

---@param i integer
---@return integer parent
local function parent(i)
  return math.floor(i / 2)
end

---@param i integer
---@return integer left_child
local function left_child(i)
  return i * 2
end

---@param i integer
---@param j integer
function M:_swap(i, j)
  self.data[i], self.data[j] = self.data[j], self.data[i]
end

---@param i integer
function M:_sift_up(i)
  while i > 1 do
    local p = parent(i)
    if not self.less(self.data[i], self.data[p]) then
      break
    end
    self:_swap(i, p)
    i = p
  end
end

---@param i integer
function M:_sift_down(i)
  while true do
    local l = left_child(i)
    if l > self.size then
      break
    end

    local smallest = l
    local r = l + 1
    if r <= self.size and self.less(self.data[r], self.data[l]) then
      smallest = r
    end

    if not self.less(self.data[smallest], self.data[i]) then
      break
    end

    self:_swap(i, smallest)
    i = smallest
  end
end

---Push to heap.
---@generic T
---@param value T
function M:push(value)
  self.size = self.size + 1
  self.data[self.size] = value
  self:_sift_up(self.size)
end

---Get root value.
---@generic T
---@return nil|T
function M:peek()
  if self:is_empty() then
    return
  end
  return self.data[1]
end

---Get and remove root value
---@generic T
---@return nil|T
function M:pop()
  if self:is_empty() then
    return
  end

  local root = self.data[1]
  local last = self.data[self.size]

  self.data[self.size] = nil
  self.size = self.size - 1

  if self.size > 0 then
    self.data[1] = last
    self:_sift_down(1)
  end

  return root
end

---Is heap empty
---@return boolean empty
function M:is_empty()
  return self.size == 0
end

---Clear heap
function M:clear()
  self.size = 0
  self.data = {}
end

return M
