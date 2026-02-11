local t = require("t")
local eq = t.eq
local state_module = require("spinner.state")
local stub = require("luassert.stub")
local new = state_module.new

local STATUS = require("spinner.status")

describe("state", function()
  local state
  local now

  before_each(function()
    now = 1000

    stub(vim.uv or vim.loop, "hrtime", function()
      return now * 1e6
    end)

    state = new("test", {
      kind = "statusline",
      pattern = "dots",
      ttl_ms = 0,
      initial_delay_ms = 0,
    })
  end)

  it("new() with default", function()
    local global = require("spinner.config").global

    state = new("test")
    eq("test", state.id)
    eq(1, state.index)
    eq(0, state.active)
    eq(STATUS.STOPPED, state.status)
    eq(0, state.start_time)
    eq(0, state.last_spin)
    eq(true, state.opts ~= nil)
    eq(true, state.ui_scope ~= nil)
    eq(true, state.ui_updater ~= nil)
    eq("custom", state.opts.kind)
    eq(require("spinner.pattern")[global.pattern], state.opts.pattern)
    eq(global.ttl_ms, state.opts.ttl_ms)
    eq(global.initial_delay_ms, state.opts.initial_delay_ms)
    if not global.placeholder then
      eq(nil, state.opts.placeholder)
    else
      eq(global.placeholder, state.opts.placeholder)
    end
  end)

  it("new() kind can be optional", function()
    state = new("test", {
      placeholder = "abc",
    })
    eq("custom", state.opts.kind)
  end)

  it("new() opts.pattern is a string", function()
    state = new("test", {
      kind = "statusline",
      pattern = "dots",
    })

    local pattern_map = require("spinner.pattern")
    eq("table", type(state.opts.pattern))
    eq(pattern_map["dots"], state.opts.pattern)
  end)

  it("new() opts.pattern is a table", function()
    local pattern = {
      frames = { "1", "2", "3" },
      interval = 1,
    }
    state = new("test", {
      kind = "statusline",
      pattern = pattern,
    })

    eq(pattern, state.opts.pattern)
  end)

  it("new()should error if opts.pattern is invalid", function()
    assert.has_error(function()
      new("test", {
        ---@diagnostic disable-next-line: assign-type-mismatch
        pattern = 1,
      })
    end)
  end)

  it("new() opts.placeholder is false", function()
    state = new("test", {
      kind = "statusline",
      placeholder = false,
    })
    eq(nil, state.opts.placeholder)
  end)

  it(
    "new opts.placeholder is true, placeholder a string with length equals to frame",
    function()
      state = new("test", {
        kind = "statusline",
        placeholder = true,
        pattern = {
          interval = 1,
          frames = { "123" },
        },
      })
      eq(3, #state.opts.placeholder)
    end
  )

  it("new() should error if placeholder is invalid", function()
    assert.has_error(function()
      new("test", {
        ---@diagnostic disable-next-line: assign-type-mismatch
        placeholder = {},
      })
    end)
  end)

  it("start() STOPPED -> RUNNING", function()
    local need_refresh_ui, next_schedule_time = state:start()
    eq(STATUS.RUNNING, state.status)
    eq(1, state.active)
    eq(true, state.started)
    eq(true, need_refresh_ui)
    eq(state.opts.pattern.interval, next_schedule_time)
    eq(0, state.last_spin)
    eq(now, state.start_time)
  end)

  it("start() STOPPED -> DELAYED", function()
    state = new("test", {
      kind = "statusline",
      ttl_ms = 0,
      initial_delay_ms = 500,
    })

    local need_refresh, next_time = state:start()

    eq(STATUS.DELAYED, state.status)
    eq(false, need_refresh)
    eq(500, next_time)
    eq(now, state.start_time)
  end)

  it("start() PAUSED -> RUNNING should spin", function()
    state:start()
    eq(1, state.active)

    state:pause()
    local old = state:render()
    now = now + 100
    local need_refresh_ui, next_schedule_time = state:start()

    eq(1, state.active)
    eq(true, need_refresh_ui)
    eq(now, state.start_time)
    eq(now, state.last_spin)
    eq(STATUS.RUNNING, state.status)
    eq(state.opts.pattern.interval, next_schedule_time)
    eq(true, old ~= state:render())
  end)

  it("start() prevents duplicate start", function()
    local need_refresh_ui1, next_schedule_time1 = state:start()
    eq(true, state.started)
    eq(1, state.active)
    eq(true, need_refresh_ui1)
    eq(80, next_schedule_time1)

    -- Second start should NOT reschedule (duplicate protection)
    local need_refresh_ui2, next_schedule_time2 = state:start()
    eq(true, state.started)
    eq(2, state.active)
    eq(false, need_refresh_ui2)
    eq(nil, next_schedule_time2)

    -- Third start should also NOT reschedule
    local need_refresh_ui3, next_schedule_time3 = state:start()
    eq(true, state.started)
    eq(3, state.active)
    eq(false, need_refresh_ui3)
    eq(nil, next_schedule_time3)
  end)

  it(
    "start() a initial_delay spinner in PAUSE status, should NOT schedule when delay has not arrived",
    function()
      state = new("test", {
        kind = "statusline",
        initial_delay_ms = 100,
      })
      now = 0
      state:start()
      state:pause()

      now = 50
      local update_ui, next_time = state:start()
      eq(false, update_ui)
      eq(nil, next_time)
      eq(STATUS.RUNNING, state.status)
      eq(0, state.last_spin)
      eq(100, state.opts.initial_delay_ms)
    end
  )

  it("requires start/stop pairing via active", function()
    state:start()
    state:start()

    eq(2, state.active)
    eq(STATUS.RUNNING, state.status)

    state:stop()
    eq(1, state.active)
    eq(STATUS.RUNNING, state.status)

    state:stop()
    eq(0, state.active)
    eq(STATUS.STOPPED, state.status)
  end)

  it("step() when PAUSED", function()
    state:start()
    state:pause()

    local dirty, next_time = state:step(now)

    eq(false, dirty)
    eq(nil, next_time)
  end)

  it("spin() advances frame and returns relative delay", function()
    state:start()

    local current = state:render()
    local dirty, next_time = state:spin(now)

    eq(true, dirty)
    eq(true, next_time > 0)
    eq(true, current ~= state:render())
  end)

  it("spin() record last_spin", function()
    state:start()
    eq(0, state.last_spin)

    state:spin(now)
    eq(now, state.last_spin)
    now = now + 100
    state:spin(now)
    eq(now, state.last_spin)
  end)

  it("spin() next_time < interval if last spin elaspse delayed", function()
    state.opts.pattern.interval = 100
    state:start()

    now = 100
    state:spin(now)
    now = now + 120
    local _, next_time = state:spin(now)
    eq(true, next_time < 100)
  end)

  it("spin() drift correction is non-negative", function()
    state:start()

    local intervals = { 50, 100, 150, 200 }
    for _, drift in ipairs(intervals) do
      state.last_spin = now - drift
      local dirty, next_time = state:spin(now)

      eq(true, dirty)
      eq(true, next_time > 0)
    end
  end)

  it("step() check ttl expiration then stops spinner", function()
    state.opts.ttl_ms = 100
    state:start()

    now = state.start_time + 200
    local dirty, next_time = state:step(now)

    eq(true, dirty)
    eq(nil, next_time)
    eq(STATUS.STOPPED, state.status)
  end)

  it("render() returns placeholder with placeholder = true", function()
    state = new("test", {
      kind = "statusline",
      placeholder = true,
    })

    local text = state:render()

    eq(true, text ~= "")
    eq(vim.fn.strdisplaywidth(state.opts.pattern.frames[1]), #text)
  end)

  it("render() returns placeholder with placeholder value", function()
    state = new("test", {
      kind = "statusline",
      placeholder = "abc",
    })

    eq("abc", state:render())
  end)

  it("render() returns empty if placeholder = nil", function()
    state = new("test", {
      kind = "statusline",
      placeholder = nil,
    })

    eq("", state:render())
  end)

  it("render() returns empty if kind is cmdline", function()
    state = new("test", {
      kind = "cmdline",
      placeholder = "abc",
    })

    eq("", state:render())
  end)

  it("render() cmdline with highlighting", function()
    state = new("test", {
      kind = "cmdline",
      pattern = {
        frames = { "abc" },
        interval = 10,
      },
    })
    state:start()

    eq("{{SPINNER_HIGHLIGHT}}abc{{END_HIGHLIGHT}}", state:render())
  end)

  it("render() PAUSE returns same string", function()
    state:start()
    state:pause()
    eq(STATUS.PAUSED, state.status)
    local text = state:render()
    eq(text, state:render())
    eq(text, state:render())
    eq(text, state:render())
  end)

  it("fsm invariants hold under arbitrary sequence", function()
    local ops = { "start", "pause", "stop" }

    for _ = 1, 100 do
      local op = ops[math.random(1, #ops)]
      state[op](state)

      -- active >= 0
      eq(true, state.active >= 0)

      eq(
        true,
        state.status == STATUS.STOPPED
          or state.status == STATUS.RUNNING
          or state.status == STATUS.PAUSED
          or state.status == STATUS.DELAYED
      )
    end
  end)

  it("fuzz start/pause/stop sequence", function()
    local ops = { "start", "pause", "stop" }

    local seq = {}
    for i = 1, 50 do
      seq[i] = ops[math.random(1, #ops)]
    end

    for _, op in ipairs(seq) do
      state[op](state)
    end

    if state.status == STATUS.STOPPED then
      eq(0, state.active)
    else
      eq(true, state.active >= 0)
    end
  end)

  it("handles multiple stop calls gracefully", function()
    state:start()
    state:stop()

    eq(false, state.started) -- Should not be scheduled after stop

    -- Second stop call should be no-op
    local initial_active = state.active
    local initial_status = state.status
    local initial_started = state.started

    state:stop()

    eq(initial_active, state.active)
    eq(initial_status, state.status)
    eq(initial_started, state.started)
  end)

  it("handles resume from long pause with proper timing", function()
    state:start()

    state:spin(now)

    state:pause()
    eq(STATUS.PAUSED, state.status)

    state.last_spin = now - 10000
    local need_refresh, next_schedule = state:start()

    eq(STATUS.RUNNING, state.status)
    eq(now, state.last_spin)
    eq(true, need_refresh)
    eq(state.opts.pattern.interval, next_schedule)
  end)

  it("can pause delayed spinner", function()
    state = new("delayed_test", {
      kind = "statusline",
      pattern = "dots",
      ttl_ms = 1000,
      initial_delay_ms = 500,
    })

    state:start()
    eq(STATUS.DELAYED, state.status)
    eq(true, state.started)

    state:pause()
    eq(STATUS.PAUSED, state.status)
    eq(true, state.started)
  end)

  it("can NOT pause a STOPPED spinner", function()
    state:pause()
    eq(true, STATUS.PAUSED ~= state.status)
  end)

  it("ttl expiration respects reference counting", function()
    state = new("ttl_test", {
      kind = "statusline",
      pattern = "dots",
      ttl_ms = 100,
      initial_delay_ms = 0,
    })

    state:start()
    state:start()

    eq(2, state.active)
    eq(STATUS.RUNNING, state.status)

    now = state.start_time + 200

    -- TTL expires, but since active > 1, it should decrement active and continue
    local dirty, next_time = state:step(now)

    eq(1, state.active)
    eq(STATUS.RUNNING, state.status)
    eq(true, dirty)
    eq(true, next_time > 0)
  end)

  it("ttl expiration fully stops spinner when active reaches 0", function()
    state = new("ttl_test", {
      kind = "statusline",
      pattern = "dots",
      ttl_ms = 100,
      initial_delay_ms = 0,
    })

    state:start()

    eq(1, state.active)
    eq(STATUS.RUNNING, state.status)

    now = state.start_time + 200

    -- TTL expires, and since active = 1, it should decrement to 0 and fully stop
    local dirty, next_time = state:step(now)

    eq(0, state.active)
    eq(STATUS.STOPPED, state.status)
    eq(true, dirty)
    eq(nil, next_time)
  end)

  it("properly clears scheduled flag in stop method", function()
    state:start()
    eq(true, state.started)
    eq(1, state.active)

    -- Stop should not clear scheduled flag if there are still active references
    state:start()
    local fully_stopped1, needs_refresh1 = state:stop()
    eq(false, fully_stopped1)
    eq(false, needs_refresh1)
    eq(true, state.started)
    eq(1, state.active)

    -- Final stop should clear scheduled flag when fully stopped
    local fully_stopped2, needs_refresh2 = state:stop()
    eq(true, fully_stopped2)
    eq(true, needs_refresh2)
    eq(false, state.started)
    eq(0, state.active)
    eq(STATUS.STOPPED, state.status)
  end)

  it(
    "scheduled flag behavior with delayed state and duplicate starts",
    function()
      state = new("delayed_test", {
        kind = "statusline",
        pattern = "dots",
        ttl_ms = 1000,
        initial_delay_ms = 500,
      })

      -- First start should schedule with delay
      local need_refresh1, next_time1 = state:start()
      eq(true, state.started)
      eq(STATUS.DELAYED, state.status)
      eq(1, state.active)
      eq(false, need_refresh1)
      eq(500, next_time1)

      -- Second start should NOT reschedule (duplicate protection)
      local need_refresh2, next_time2 = state:start()
      eq(true, state.started)
      eq(STATUS.DELAYED, state.status)
      eq(2, state.active)
      eq(false, need_refresh2)
      eq(nil, next_time2)

      -- Stop once - should still be scheduled
      local fully_stopped1, needs_refresh1 = state:stop()
      eq(false, fully_stopped1)
      eq(false, needs_refresh1) -- active > 0, so no refresh needed
      eq(true, state.started)
      eq(STATUS.DELAYED, state.status)
      eq(1, state.active)

      -- Final stop - should clear scheduled flag
      local fully_stopped2, needs_refresh2 = state:stop()
      eq(true, fully_stopped2)
      eq(true, needs_refresh2)
      eq(false, state.started)
    end
  )

  it("stop() force stop", function()
    state = new("delayed_test", {
      kind = "statusline",
      pattern = "dots",
      ttl_ms = 1000,
      initial_delay_ms = 500,
    })

    state:start()
    state:start()
    state:start()

    eq(3, state.active)
    eq(true, state.started)
    eq(STATUS.DELAYED, state.status)

    local fully_stopped, update_ui = state:stop(true)
    eq(true, fully_stopped)
    eq(0, state.active)
    eq(false, state.started)
    eq(STATUS.STOPPED, state.status)
    eq(true, update_ui)
  end)

  it(
    "repeated calls to stop without force do not trigger UI refresh after spinner is stopped",
    function()
      state:start()

      -- First stop call should return true (needs UI refresh) if it fully stops
      local fully_stopped1, update_ui = state:stop()
      eq(true, fully_stopped1)
      eq(true, update_ui)
      eq(0, state.active)
      eq(STATUS.STOPPED, state.status)

      -- Subsequent stop calls should return false (no UI refresh needed)
      local fully_stopped2, refresh_needed2 = state:stop()
      eq(true, fully_stopped2) -- still fully stopped
      eq(false, refresh_needed2) -- no refresh needed since already stopped
      eq(0, state.active)
      eq(STATUS.STOPPED, state.status)

      local fully_stopped3, refresh_needed3 = state:stop()
      eq(true, fully_stopped3) -- still fully stopped
      eq(false, refresh_needed3) -- no refresh needed since already stopped
      eq(0, state.active)
      eq(STATUS.STOPPED, state.status)
    end
  )

  it(
    "repeated calls to stop with force do not trigger UI refresh after spinner is already stopped",
    function()
      state:start()
      state:start()
      eq(2, state.active)
      eq(STATUS.RUNNING, state.status)

      -- First force stop should return true (needs UI refresh) if it fully stops
      local fully_stopped1, refresh_needed = state:stop(true)
      eq(true, fully_stopped1)
      eq(true, refresh_needed)
      eq(0, state.active)
      eq(STATUS.STOPPED, state.status)

      -- Subsequent force stop calls should return false (no UI refresh needed) since already stopped
      local fully_stopped2, refresh_needed2 = state:stop(true)
      eq(true, fully_stopped2)
      eq(false, refresh_needed2)
      eq(0, state.active)
      eq(STATUS.STOPPED, state.status)

      local fully_stopped3, refresh_needed3 = state:stop(true)
      eq(true, fully_stopped3)
      eq(false, refresh_needed3)
      eq(0, state.active)
      eq(STATUS.STOPPED, state.status)
    end
  )

  it(
    "stop with force does not trigger UI refresh if already stopped",
    function()
      eq(0, state.active)
      eq(STATUS.STOPPED, state.status)

      -- Force stop on already stopped spinner should return false (no UI refresh needed)
      local fully_stopped, refresh_needed = state:stop(true)
      eq(true, fully_stopped)
      eq(false, refresh_needed)
      eq(0, state.active)
      eq(STATUS.STOPPED, state.status)
    end
  )

  it(
    "should use on_update_ui callback when provided and update when config changes",
    function()
      local update_ui1 = spy.new(function() end)
      local update_ui2 = spy.new(function() end)

      -- Test initialization with on_update_ui
      state = new("test_callback", {
        kind = "statusline",
        pattern = "dots",
        ttl_ms = 0,
        initial_delay_ms = 0,
        ---@diagnostic disable-next-line: assign-type-mismatch
        on_update_ui = update_ui1,
      })

      state.ui_updater()

      assert.spy(update_ui1).was.called(1)
      local args = update_ui1.calls[1].vals[1]
      eq("string", type(args.text)) -- Should contain rendered text
      eq(STATUS.STOPPED, args and args.status or nil) -- Initial state is STOPPED

      -- Test updating on_update_ui via config
      state:config({
        on_update_ui = update_ui2,
      })

      -- Call the updated ui_updater
      state.ui_updater()
      assert.spy(update_ui2).was.called(1)
    end
  )

  it(
    "render() should use fmt function to format spinner text when provided",
    function()
      local fmt_func = function(event)
        return "[" .. event.text .. "]"
      end

      state = new("test_fmt", {
        kind = "statusline",
        pattern = {
          frames = { "a", "b" },
          interval = 100,
        },
        fmt = fmt_func,
      })

      -- Test when spinner is stopped
      eq("[]", state:render())

      -- Start the spinner and test formatting
      state:start()
      eq("[a]", state:render())
    end
  )

  it(
    "should preserve existing options when calling config multiple times",
    function()
      state = new("test_merge", {
        kind = "statusline",
        placeholder = "OLD",
        pattern = {
          frames = { "x", "y" },
          interval = 200,
        },
      })

      eq("OLD", state.opts.placeholder)
      eq(200, state.opts.pattern.interval)

      -- Update only the placeholder, other options should be preserved
      state:config({
        placeholder = "NEW",
      })

      eq("NEW", state.opts.placeholder)
      eq(200, state.opts.pattern.interval)
      eq("statusline", state.opts.kind)

      -- Update only the pattern, other options should be preserved
      state:config({
        pattern = {
          frames = { "p", "q", "r" },
          interval = 300,
        },
      })

      eq("NEW", state.opts.placeholder)
      eq(300, state.opts.pattern.interval)
      eq(3, #state.opts.pattern.frames)
      eq("statusline", state.opts.kind)
    end
  )

  it(
    "render() should use fmt function to format spinner text when kind is cmdline",
    function()
      local fmt_func = function(event)
        return "[" .. event.text .. "]"
      end

      state = new("test_cmdline_fmt", {
        kind = "cmdline",
        pattern = {
          frames = { "a", "b" },
          interval = 100,
        },
        fmt = fmt_func,
      })

      eq("", state:render())
      state:start()
      eq("[{{SPINNER_HIGHLIGHT}}a{{END_HIGHLIGHT}}]", state:render())
    end
  )

  it("config() fmt should be a function or callback", function()
    assert.has_error(function()
      state = new("test", {
        ---@diagnostic disable-next-line: assign-type-mismatch
        fmt = "a",
      })
    end)
  end)

  it("should validate cursor options", function()
    state = new("test_cursor", {
      kind = "cursor",
      hl_group = "TestHighlight",
      winblend = 50,
      zindex = 10,
      row = 1,
      col = 2,
    })

    eq(50, state.opts.winblend)
    eq(10, state.opts.zindex)
    eq(1, state.opts.row)
    eq(2, state.opts.col)
    eq("TestHighlight", state.opts.hl_group)
  end)

  it("should cursor spinner use global default", function()
    -- use global default
    state = new("test_cursor", {
      kind = "cursor",
    })

    local global = require("spinner.config").global
    eq(global.cursor_spinner.winblend, state.opts.winblend)
    eq(global.cursor_spinner.hl_group, state.opts.hl_group)
    eq(global.cursor_spinner.zindex, state.opts.zindex)
    eq(global.cursor_spinner.row, state.opts.row)
    eq(global.cursor_spinner.col, state.opts.col)
  end)

  it("should validate extmark  options", function()
    state = new("test_extmark", {
      kind = "extmark",
      bufnr = 1,
      row = 10,
      col = 20,
      ns = 100,
      hl_group = "TestHighlight",
      virt_text_pos = "abc",
      virt_text_win_col = 1,
    })

    eq(1, state.opts.bufnr)
    eq(10, state.opts.row)
    eq(20, state.opts.col)
    eq(100, state.opts.ns)
    eq("TestHighlight", state.opts.hl_group)
    eq("abc", state.opts.virt_text_pos)
    eq(1, state.opts.virt_text_win_col)
  end)

  it("should extmark spinner use global default", function()
    state = new("test", {
      kind = "extmark",
      bufnr = 1,
      row = 10,
      col = 20,
      hl_group = nil,
    })
    eq(
      require("spinner.config").global.extmark_spinner.hl_group,
      state.opts.hl_group
    )
  end)

  it("should error if extmark lack options", function()
    local opts = {
      kind = "extmark",
      bufnr = 1,
      row = 1,
      col = 1,
    }
    opts.bufnr = nil
    assert.has_error(function()
      new("test", opts)
    end)
    opts.row = nil
    assert.has_error(function()
      new("test", opts)
    end)
    opts.col = nil
    assert.has_error(function()
      new("test", opts)
    end)
  end)

  it("should validate cmdline specific options", function()
    state = new("test_cmdline", {
      kind = "cmdline",
      hl_group = "TestHighlight",
    })
    eq("TestHighlight", state.opts.hl_group)
  end)

  it("should cmdline use global default", function()
    local global = require("spinner.config").global
    state = new("test_cmdline", {
      kind = "cmdline",
      hl_group = nil,
    })
    eq(global.cmdline_spinner.hl_group, state.opts.hl_group)
  end)

  it("should handle stop with active <= 0", function()
    state = new("test_stop", {
      kind = "statusline",
      pattern = {
        frames = { "a", "b" },
        interval = 100,
      },
    })

    -- Start the spinner to change status from STOPPED to RUNNING
    state:start()
    state.status = require("spinner.status").RUNNING -- Explicitly set to RUNNING

    -- Manually set active to 0 to trigger the condition
    state.active = 0
    local was_fully_stopped, needs_ui_refresh = state:stop()

    eq(false, was_fully_stopped)
    eq(false, needs_ui_refresh)
  end)

  it("should handle config with event attachment", function()
    -- Mock the event.attach function
    local original_attach = require("spinner.event").attach
    local attach_called = false
    local attach_params = {}

    require("spinner.event").attach = function(id, event)
      attach_called = true
      attach_params = { id = id, event = event }
    end

    local lsp_event = {
      lsp = {
        progress = true,
        client_names = { "test-client" },
      },
    }

    state = new("test_config_event", {
      kind = "statusline",
      pattern = {
        frames = { "a", "b" },
        interval = 100,
      },
      attach = lsp_event,
    })

    -- Config with attach option
    state:config({ attach = lsp_event })

    eq(true, attach_called)
    eq("test_config_event", attach_params.id)
    eq(lsp_event, attach_params.event)

    -- Restore original function
    require("spinner.event").attach = original_attach
  end)

  it("custom spinner should have on_update_ui option", function()
    assert.has_error(function()
      state = new("custom", {
        kind = "custom",
        on_update_ui = nil,
      })
    end)
  end)

  it("custom spinner shoud use id as ui_scope by default", function()
    state = new("custom-id", {
      kind = "custom",
      on_update_ui = function() end,
    })
    eq("custom-id", state.ui_scope)
  end)

  it("custom spinner use ui_scope from opts", function()
    state = new("custom", {
      kind = "custom",
      ui_scope = "abc",
      on_update_ui = function() end,
    })

    eq("abc", state.ui_scope)
  end)

  it("should validate cursor-specific options completely", function()
    state = new("test_cursor_complete", {
      kind = "cursor",
      hl_group = "TestHighlight",
      winblend = 50,
      zindex = 10,
      row = 1,
      col = 2,
    })

    eq("TestHighlight", state.opts.hl_group)
    eq(50, state.opts.winblend)
    eq(10, state.opts.zindex)
    eq(1, state.opts.row)
    eq(2, state.opts.col)
  end)

  it("can set window-title spinner opts", function()
    state = new("window-title", {
      kind = "window-title",
      win = 10,
      pos = "left",
      hl_group = "abc",
    })
    eq(10, state.opts.win)
    eq("left", state.opts.pos)
    eq("abc", state.opts.hl_group)
  end)

  it("can set window-footer spinner opts", function()
    state = new("window-footer", {
      kind = "window-footer",
      win = 10,
      pos = "left",
      hl_group = "abc",
    })
    eq(10, state.opts.win)
    eq("left", state.opts.pos)
    eq("abc", state.opts.hl_group)
  end)

  it("window-title spinner can have pos optional", function()
    state = new("window-title", {
      kind = "window-title",
      win = 10,
      pos = nil,
    })
    eq(10, state.opts.win)
    eq("center", state.opts.pos)
  end)

  it("window-footer spinner can have pos optional", function()
    state = new("window-footer", {
      kind = "window-footer",
      win = 10,
      pos = nil,
    })
    eq(10, state.opts.win)
    eq("center", state.opts.pos)
  end)

  it(
    "should error if win = nil for spinner window-title or window-footer",
    function()
      assert.has_error(function()
        new("window-title", {
          kind = "window-title",
          pos = "any",
          ---@diagnostic disable-next-line: assign-type-mismatch
          win = nil,
        })
      end)

      assert.has_error(function()
        new("window-footer", {
          kind = "window-footer",
          pos = "any",
          ---@diagnostic disable-next-line: assign-type-mismatch
          win = nil,
        })
      end)
    end
  )
end)
