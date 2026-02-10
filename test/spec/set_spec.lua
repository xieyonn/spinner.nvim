local set = require("spinner.set")
local t = require("t")
local eq = t.eq

describe("set", function()
  it("creates empty set", function()
    local s = set.new()
    eq(0, s.n)
    eq(true, s:is_empty())
  end)

  it("creates set with items", function()
    local s = set.new({ "a", "b", "c" })
    eq(3, s.n)
    eq(true, s:has("a"))
    eq(true, s:has("b"))
    eq(true, s:has("c"))
  end)

  it("handles duplicates", function()
    local s = set.new({ "a", "a", "b" })
    eq(2, s.n)
  end)

  it("adds and removes items", function()
    local s = set.new()
    s:add("x")
    eq(1, s.n)
    eq(true, s:has("x"))

    s:add("x") -- duplicate
    eq(1, s.n) -- count unchanged

    s:delete("x")
    eq(0, s.n)
    eq(false, s:has("x"))
  end)

  it("clears set", function()
    local s = set.new({ "a", "b" })
    s:clear()
    eq(0, s.n)
    eq(true, s:is_empty())
  end)

  it("iterates over items", function()
    local s = set.new({ "a", "b", "c" })
    local count = 0
    s:for_each(function(_)
      count = count + 1
    end)
    eq(3, count)
  end)

  it("handles nil correctly", function()
    local s = set.new()
    ---@diagnostic disable-next-line :param-type-mismatch
    eq(false, s:has(nil))
    ---@diagnostic disable-next-line :param-type-mismatch
    s:add(nil)
    eq(0, s.n) -- nil not added

    ---@diagnostic disable-next-line: param-type-mismatch
    s:delete(nil)
  end)

  it("delete a non-exist item correctly", function()
    local s = set.new()
    s:add(1)
    eq(true, s:has(1))

    s:delete(2)
    eq(true, s:has(1))
  end)
end)
