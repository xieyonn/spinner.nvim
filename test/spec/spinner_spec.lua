local stub = require("luassert.stub")
local t = require("t")
local eq = t.eq

describe("spinner", function()
  before_each(function()
    stub(vim.uv, "new_timer").returns({
      start = function(_, _, _, callback)
        callback()
      end,
      stop = function(_) end,
      close = function(_) end,
    })
    stub(vim, "schedule_wrap").invokes(function(fn)
      return fn
    end)
    stub(vim, "defer_fn").invokes(function(fn)
      fn()
    end)
    local now = 0
    stub(vim.uv, "now").invokes(function()
      now = now + 1
      return now
    end)
  end)

  it("empty default", function()
    local sp = require("spinner").new()
    eq(false, sp.enabled)
    eq("", tostring(sp))
  end)

  it("start spinner", function()
    local sp = require("spinner").new()
    stub(vim.uv, "new_timer").returns({
      start = function(_, _, _, callback)
        callback()
        eq(true, sp.enabled)
        eq(1, sp.idx)
        eq(sp.opts.texts[1], tostring(sp))

        callback()
        eq(true, sp.enabled)
        eq(2, sp.idx)
        eq(sp.opts.texts[2], tostring(sp))
      end,
      stop = function(_) end,
      close = function(_) end,
    })
    sp:start()
  end)

  it("stop spinner after ttl ", function()
    local sp = require("spinner").new({
      ttl = 3,
    })
    stub(vim.uv, "new_timer").returns({
      start = function(_, _, _, callback)
        callback()
        eq(true, sp.enabled)
        eq(1, sp.idx)
        eq(sp.opts.texts[1], tostring(sp))

        callback()
        eq(true, sp.enabled)
        eq(2, sp.idx)
        eq(sp.opts.texts[2], tostring(sp))

        callback()
      end,
      stop = function(_) end,
      close = function(_) end,
    })

    sp:start()
    eq(false, sp.enabled)
    eq("", tostring(sp))
    eq(0, sp.idx)
  end)

  it("remain start if call times start() > stop()", function()
    local sp = require("spinner").new()

    sp:start()
    eq(true, sp.enabled)
    sp:start()
    eq(true, sp.enabled)

    sp:stop()
    -- remain enable
    eq(true, sp.enabled)
    sp:stop()
    eq(false, sp.enabled)

    -- remian stop
    sp:stop()
    eq(false, sp.enabled)
  end)
end)
