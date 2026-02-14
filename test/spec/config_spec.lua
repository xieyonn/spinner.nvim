local t = require("t")
local eq = t.eq

describe("config", function()
  before_each(function()
    package.loaded["spinner.config"] = nil
  end)
  after_each(function()
    package.loaded["spinner.config"] = nil
  end)

  it("setup() with nil", function()
    local global = require("spinner.config").global
    require("spinner.config").setup()

    package.loaded["spinner.config"] = nil
    eq(global, require("spinner.config").global)
  end)

  it("setup() shoud change global defaults", function()
    ---@type spinner.Config
    local opts = {
      pattern = "dots2",
      ttl_ms = 10,
      initial_delay_ms = 10,
      placeholder = true,
      hl_group = "Abc",
      cursor_spinner = {
        winblend = 100,
        zindex = 100,
        row = 100,
        col = 100,
      },
    }

    local config = require("spinner.config")
    config.setup(opts)

    eq(opts, config.global)
  end)

  it("setup() shoud error if param invalid", function()
    local setup_check = function(opts)
      assert.has_error(function()
        require("spinner.config").setup(opts)
      end)
    end

    setup_check({ pattern = "abc" })
    setup_check({ pattern = 1 })
    setup_check({ pattern = { interval = -1, frames = {} } })
    setup_check({ pattern = { interval = 10, frames = nil } })
    setup_check({ pattern = { interval = 10, frames = "abc" } })
    setup_check({ ttl_ms = -1 })
    setup_check({ initial_delay_ms = -1 })
    setup_check({ placeholder = 1 })
    setup_check({ placeholder = function() end })
    setup_check({ placeholder = { init = 1 } })
    setup_check({ placeholder = { stopped = 1 } })
    setup_check({ placeholder = { failed = 1 } })
    setup_check({ hl_group = 0 })
    setup_check({ hl_group = { init = 1 } })
    setup_check({ hl_group = { paused = 1 } })
    setup_check({ hl_group = { running = 1 } })
    setup_check({ hl_group = { stopped = 1 } })
    setup_check({ hl_group = { failed = 1 } })
    setup_check({ cursor_spinner = { winblend = "abc" } })
    setup_check({ cursor_spinner = { zindex = "abc" } })
    setup_check({ cursor_spinner = { row = "abc" } })
    setup_check({ cursor_spinner = { col = "abc" } })
  end)

  it("setup() can set placeholder with string", function()
    local config = require("spinner.config")
    local opts = {
      placeholder = "abc",
    }
    config.setup(opts)

    eq(opts.placeholder, config.global.placeholder)
  end)

  it("setup() can set hl_group with table", function()
    local config = require("spinner.config")
    local opts = {
      hl_group = {
        init = "init",
        paused = "paused",
        running = "running",
        stopped = "stopped",
        failed = "failed",
      },
    }
    config.setup(opts)

    eq(opts.hl_group, config.global.hl_group)
  end)

  it("setup() can set placeholder with table", function()
    local config = require("spinner.config")
    local opts = {
      placeholder = {
        init = "init",
        stopped = "stopped",
        failed = "failed",
      },
    }
    config.setup(opts)

    eq(opts.placeholder, config.global.placeholder)
  end)
end)
