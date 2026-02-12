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
    setup_check({ placeholder = {} })
    setup_check({ placeholder = function() end })
    setup_check({ hl_group = 0 })
    setup_check({ cursor_spinner = { winblend = "abc" } })
    setup_check({ cursor_spinner = { zindex = "abc" } })
    setup_check({ cursor_spinner = { row = "abc" } })
    setup_check({ cursor_spinner = { col = "abc" } })
  end)
end)
