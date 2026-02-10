local t = require("t")
local eq = t.eq
local spy = require("luassert.spy")

local scheduler = require("spinner.scheduler")

describe("scheduler", function()
  local s
  local now = 1000
  local fake_timer
  local cbs = {}
  local tick = function()
    local cb = table.remove(cbs, 1)
    if cb then
      cb()
    end
  end

  local uv = vim.uv or vim.loop
  before_each(function()
    s = scheduler.new()
    cbs = {}

    fake_timer = {
      start = spy.new(function(_, _, _, cb)
        table.insert(cbs, cb)
      end),
      stop = spy.new(function() end),
      close = spy.new(function() end),
    }

    stub(uv, "new_timer", function()
      return fake_timer
    end)
    stub(vim, "schedule_wrap", function(fn)
      return fn
    end)
    stub(uv, "hrtime", function()
      return now * 1e6
    end)
  end)

  after_each(function()
    if fake_timer then
      fake_timer.start:clear()
      fake_timer.stop:clear()
      fake_timer.close:clear()
    end
  end)

  it("should create a new scheduler", function()
    eq(true, s ~= nil)
    eq(true, type(s.tasks) == "table")
    eq(true, s.timer == nil)
  end)

  it("should execute a scheduled job once", function()
    local f = spy.new()

    s:schedule(function()
      f()
    end)

    tick()
    assert.spy(f).called(1)
  end)

  it("should reschedule a periodic job if it returns interval", function()
    local count = 0
    local interval = 10

    local f = spy.new(function()
      count = count + 1
      if count < 3 then
        return interval
      end
    end)

    s:schedule(function()
      return f()
    end)

    tick()
    tick()
    tick()

    assert.spy(f).called(3)

    tick()
    assert.spy(f).called(3)
  end)

  it("should handle periodic job that stops returning interval", function()
    local count = 0

    local f = spy.new(function()
      count = count + 1
      if count == 1 then
        return 10
      end
    end)

    s:schedule(function()
      return f()
    end)

    tick()
    tick()

    assert.spy(f).called(2)

    tick()
    assert.spy(f).called(2)
  end)

  it("should handle multiple concurrent jobs", function()
    local f1 = spy.new()
    local f2 = spy.new()

    s:schedule(function()
      f1()
    end)

    s:schedule(function()
      f2()
    end)

    tick()
    assert.spy(f1).called(1)
    assert.spy(f2).called(1)
  end)

  it("should handle errors in scheduled jobs gracefully", function()
    local f = spy.new()

    s:schedule(function()
      error("Test error in scheduled job")
    end)

    s:schedule(function()
      f()
    end)

    -- Even if one job errors, other jobs should continue to work
    tick()
    assert.spy(f).called(1)
  end)

  it("should handle zero interval correctly", function()
    local f = spy.new()

    s:schedule(function()
      f()
      return 0
    end)

    tick()
    assert.spy(f).called(1)

    tick()
    assert.spy(f).called(1)
  end)

  it("should handle negative interval correctly", function()
    local f = spy.new()

    s:schedule(function()
      f()
      return -5
    end)

    tick()
    assert.spy(f).called(1)

    tick()
    assert.spy(f).called(1)
  end)

  it("should handle tasks scheduled in the past", function()
    local f = spy.new()

    now = 5000
    s:schedule(function()
      f()
    end, now - 1000)

    tick()
    assert.spy(f).called(1)
  end)

  it("should handle rapid successive scheduling", function()
    local f = spy.new()

    for _ = 1, 5 do
      s:schedule(function()
        f()
      end)
    end

    tick()
    assert.spy(f).called(5)
  end)

  it("should notify error if fail to create timer #id", function()
    stub(uv, "new_timer", nil)
    stub(vim, "notify")

    s = scheduler.new()
    s:schedule(function() end)
    ---@diagnostic disable-next-line
    assert.stub(vim.notify).called(1)
    ---@diagnostic disable-next-line
    vim.notify:revert()
  end)
end)
