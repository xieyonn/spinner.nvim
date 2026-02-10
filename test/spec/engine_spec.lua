local t = require("t")
local eq = t.eq
local engine_module = require("spinner.engine")
local spy = require("luassert.spy")

describe("engine", function()
  local engine
  local state_mock

  before_each(function()
    state_mock = {
      start = spy.new(function()
        return true, nil
      end),
      stop = spy.new(function()
        return false
      end),
      pause = spy.new(function() end),
      render = spy.new(function()
        return "mock_render"
      end),
      step = spy.new(function()
        return true, nil
      end),
      opts = { kind = "statusline" },
      ui_scope = "statusline",
      ui_updater = function()
        return function() end
      end,
    }

    local dummy_scheduler = { schedule = function() end }
    engine = engine_module.new(dummy_scheduler)

    -- Directly assign the mock state to bypass the state factory
    engine.state_map["test_id"] = state_mock
  end)

  it("should start spinner and trigger UI update when needed", function()
    spy.on(engine, "update_ui")

    engine:start("test_id")

    assert.spy(state_mock.start).was.called(1)
    assert.spy(engine.update_ui).was.called(1)
  end)

  it("should stop spinner conditionally triggering UI update", function()
    local state_with_update = {
      stop = function()
        return true, true -- fully_stopped, needs_ui_refresh
      end,
      opts = { kind = "statusline" },
      ui_scope = "statusline",
      ui_updater = function()
        return function() end
      end,
    }
    spy.on(engine, "update_ui")
    engine.state_map["test_id"] = state_with_update

    engine:stop("test_id")
    assert.spy(engine.update_ui).was.called(1)

    -- Reset spy and test state that returns false for UI refresh
    engine.update_ui:clear()
    local state_without_update = {
      stop = function()
        return true, false -- fully_stopped, no_ui_refresh
      end,
      opts = { kind = "statusline" },
      ui_scope = "statusline",
      ui_updater = function()
        return function() end
      end,
    }
    engine.state_map["test_id"] = state_without_update

    engine:stop("test_id")
    assert.spy(engine.update_ui).was.called(0)
  end)

  it("should pause spinner", function()
    engine:pause("test_id")

    assert.spy(state_mock.pause).was.called(1)
  end)

  it("should render spinner correctly", function()
    local result = engine:render("test_id")

    assert.spy(state_mock.render).was.called(1)
    eq("mock_render", result)
  end)

  it("should step spinner and conditionally trigger UI update", function()
    local state_with_dirty = {
      step = spy.new(function()
        return true, 100
      end),
      opts = { kind = "statusline" },
      ui_scope = "statusline",
      ui_updater = function()
        return function() end
      end,
    }
    spy.on(engine, "update_ui")

    engine:step(state_with_dirty)
    assert.spy(engine.update_ui).was.called(1)
    assert.spy(state_with_dirty.step).was.called(1)

    -- Reset spy and test state that returns dirty=false
    engine.update_ui:clear()
    local state_without_dirty = {
      step = spy.new(function()
        return false, 100
      end),
      opts = { kind = "statusline" },
      ui_scope = "statusline",
      ui_updater = function()
        return function() end
      end,
    }

    engine:step(state_without_dirty)
    assert.spy(engine.update_ui).was.called(0)
    assert.spy(state_without_dirty.step).was.called(1)
  end)

  it("should batch UI updates for same scope", function()
    local state1 = {
      step = function()
        return true, nil
      end,
      opts = { kind = "statusline" },
      ui_scope = "same_scope", -- Same scope for both states
      ui_updater = function()
        return function() end
      end,
    }
    local state2 = {
      step = function()
        return true, nil
      end,
      opts = { kind = "statusline" },
      ui_scope = "same_scope", -- Same scope for both states
      ui_updater = function()
        return function() end
      end,
    }

    engine:update_ui(state1)
    engine:update_ui(state2)

    -- Check that there's only one pending updater for the same scope
    local count = 0
    for _ in pairs(engine.pending_ui_updater) do
      count = count + 1
    end
    eq(1, count)
  end)

  it("should handle UI updates for different scopes separately", function()
    local state1 = {
      step = function()
        return true, nil
      end,
      opts = { kind = "statusline" },
      ui_scope = "statusline", -- Different scopes for each state
      ui_updater = function()
        return function() end
      end,
    }
    local state2 = {
      step = function()
        return true, nil
      end,
      opts = { kind = "tabline" },
      ui_scope = "tabline", -- Different scopes for each state
      ui_updater = function()
        return function() end
      end,
    }

    engine:update_ui(state1)
    engine:update_ui(state2)

    -- Check that there are two pending updaters for different scopes
    local count = 0
    for _ in pairs(engine.pending_ui_updater) do
      count = count + 1
    end
    eq(2, count)
  end)

  it(
    "should prevent duplicate scheduling when start is called multiple times",
    function()
      local schedule_spy = spy.new(function() end)
      local dummy_scheduler = { schedule = schedule_spy }
      engine = engine_module.new(dummy_scheduler)

      spy.on(engine, "update_ui")

      -- Create a state that returns nil for next_time on subsequent calls
      local call_count = 0
      local state_with_duplicate_protection = {
        start = function()
          call_count = call_count + 1
          if call_count == 1 then
            return true, nil -- First call: needs UI update, no additional schedule
          else
            return false, nil -- Subsequent calls: no UI update, no additional schedule
          end
        end,
        opts = { kind = "statusline" },
        ui_scope = "statusline",
        ui_updater = function()
          return function() end
        end,
      }
      engine.state_map["test_id"] = state_with_duplicate_protection

      -- Call start multiple times
      engine:start("test_id") -- Should update UI and schedule once
      engine:start("test_id") -- Should not update UI or schedule again (duplicate protection)
      engine:start("test_id") -- Should not update UI or schedule again (duplicate protection)

      -- Should only have scheduled once despite multiple start calls
      assert.spy(schedule_spy).was.called(1)
      -- Should only have updated UI once (when dirty was true)
      ---@diagnostic disable-next-line: param-type-mismatch
      assert.spy(engine.update_ui).was.called(1)
    end
  )

  it(
    "should not schedule multiple UI updates for same scope in quick succession",
    function()
      spy.on(engine.scheduler, "schedule")

      local state = {
        opts = { kind = "statusline" },
        ui_scope = "statusline",
        ui_updater = function()
          return function() end
        end,
      }

      -- Call update_ui multiple times quickly (simulating fast spinner)
      engine:update_ui(state)
      engine:update_ui(state)
      engine:update_ui(state)
      engine:update_ui(state)

      -- Should only schedule once since all updates are for the same scope
      assert.spy(engine.scheduler.schedule).was.called(1)
    end
  )

  it("should handle UI update errors gracefully", function()
    -- Mock vim.notify to capture notifications
    local original_notify = vim.notify
    local notify_called = false
    local notify_msg = nil

    ---@diagnostic disable-next-line :duplicate-set-field
    vim.notify = function(msg, _)
      notify_called = true
      notify_msg = msg
    end

    -- Create a real scheduler and state
    local scheduler = require("spinner.scheduler").new()
    engine = require("spinner.engine").new(scheduler)

    -- Create a state with an updater that throws an error
    local error_state = require("spinner.state").new("error_test", {
      kind = "statusline", -- Need to specify kind
      pattern = {
        frames = { "a", "b" },
        interval = 100,
      },
    })

    error_state.ui_updater = function()
      error("Test error in UI updater")
    end
    error_state.ui_scope = "error_scope"

    -- Trigger UI update which should catch the error
    engine:update_ui(error_state)

    -- Process the scheduler immediately to trigger the error handling
    -- Since we're using a real scheduler, we need to wait for it to process
    vim.wait(100) -- Wait 100ms for scheduler to process

    -- Check that notification was sent (the error should have been caught)
    eq(true, notify_called)
    assert.truthy(notify_msg and string.find(notify_msg, "fail to refresh ui"))

    -- Restore original notify
    vim.notify = original_notify
  end)

  it("should schedule step when start returns a next_time", function()
    -- Create a real scheduler and state
    local scheduler = require("spinner.scheduler").new()
    local engine = require("spinner.engine").new(scheduler)

    local state_with_next_time =
      require("spinner.state").new("next_time_test", {
        kind = "statusline", -- Need to specify kind
        pattern = {
          frames = { "a", "b" },
          interval = 100,
        },
        initial_delay_ms = 10, -- Small delay to trigger next_time scheduling
      })

    state_with_next_time.ui_updater = function() end
    state_with_next_time.ui_scope = "statusline"

    -- Add the state to the engine's state map
    engine.state_map["next_time_test"] = state_with_next_time

    -- Spy on the step method to check if it's called
    local step_spy = spy.on(engine, "step")

    -- Start the spinner - this should schedule a step
    engine:start("next_time_test")

    -- Wait for scheduler to process
    vim.wait(100)

    ---@diagnostic disable-next-line :param-type-mismatch
    assert.spy(engine.step).was.called_at_least(1)

    -- Clean up spy
    step_spy:revert()
  end)

  it("should config spinner options", function()
    local config_called = false
    local config_opts = nil

    local state_for_config = {
      config = function(_, opts)
        config_called = true
        config_opts = opts
      end,
      opts = { kind = "statusline" },
      ui_scope = "statusline",
      ui_updater = function() end,
    }
    engine.state_map["config_test"] = state_for_config

    local test_opts = { pattern = "dots", ttl_ms = 5000 }

    -- Config the spinner with new options
    engine:config("config_test", test_opts)

    eq(true, config_called)
    eq(test_opts, config_opts)
  end)

  it("should auto create spinner state", function()
    local state = engine.state_map.spinner_id
    eq(true, state ~= nil)
    eq(state, engine.state_map.spinner_id)
  end)
end)
