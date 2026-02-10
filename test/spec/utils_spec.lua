local t = require("t")
local utils = require("spinner.utils")
local eq = t.eq

describe("utils", function()
  describe("splitstr", function()
    it("splits simple strings", function()
      eq({ "hello", "world" }, utils.splitstr("hello world"))
    end)

    it("handles quoted strings", function()
      eq(
        { "a", "quoted string", "is", "preserved" },
        utils.splitstr('a "quoted string" is preserved')
      )
    end)

    it("handles empty input", function()
      eq({}, utils.splitstr(""))
      eq({}, utils.splitstr("   "))
    end)
  end)

  describe("deduplicate_list", function()
    it("removes duplicates while preserving order", function()
      eq(
        { "a", "b", "c", "d" },
        utils.deduplicate_list({ "a", "b", "a", "c", "b", "d" })
      )
    end)

    it("handles no duplicates", function()
      eq({ "a", "b", "c" }, utils.deduplicate_list({ "a", "b", "c" }))
    end)

    it("handles empty list", function()
      eq({}, utils.deduplicate_list({}))
    end)
  end)

  describe("now_ms", function()
    it("returns a positive timestamp", function()
      local time1 = utils.now_ms()
      eq("number", type(time1))
      eq(true, time1 > 0)
    end)
  end)

  describe("create_comp", function()
    it("handles basic functionality and filtering", function()
      -- Test basic functionality with filtering
      local mock_fn = function()
        return { "apple", "application", "banana" }
      end
      local comp_fn = utils.create_comp(mock_fn)

      -- Test filtering when current input is "app"
      eq({ "apple", "application" }, comp_fn("", "test app", 8))

      -- Test when current input is empty (after space)
      eq({ "apple", "application", "banana" }, comp_fn("", "test ", 5))

      -- Test when no matches found
      eq({}, comp_fn("", "cmd xyz", 7))

      -- Test when completion function returns nil
      local nil_fn = utils.create_comp(function()
        return nil
      end)
      eq(nil, nil_fn("", "test ", 5))
    end)

    it("builds context correctly", function()
      local captured_ctx = nil
      local mock_fn = function(ctx)
        captured_ctx = ctx
        return { "option1" }
      end
      local comp_fn = utils.create_comp(mock_fn)

      -- Single word
      comp_fn("", "test", 4)
      assert(captured_ctx)
      eq({ "test" }, captured_ctx.words)
      eq("test", captured_ctx.cur)
      eq("", captured_ctx.prev)

      -- Multiple words
      comp_fn("", "first second", 12)
      eq({ "first", "second" }, captured_ctx.words)
      eq("second", captured_ctx.cur)
      eq("first", captured_ctx.prev)

      -- After space (empty current word)
      comp_fn("", "first ", 6)
      eq({ "first" }, captured_ctx.words)
      eq("", captured_ctx.cur)
      eq("first", captured_ctx.prev)
    end)
  end)

  it("on_win_closed shoud call once then clear", function()
    local win = 10
    local group = 1
    local autocmd_cb
    local delete = spy.new(function() end)

    stub(vim.api, "nvim_create_augroup").invokes(function(_, opts)
      eq({ clear = true }, opts)
      return group
    end)
    stub(vim.api, "nvim_create_autocmd").invokes(function(_, opts)
      autocmd_cb = opts.callback
    end)
    stub(vim.api, "nvim_del_augroup_by_id").invokes(function(...)
      delete(...)
    end)

    utils.on_win_closed(win, function() end)

    -- not target window
    autocmd_cb({ match = tostring(win + 1) })
    assert.spy(delete).was.called(0)

    -- target window
    autocmd_cb({ match = tostring(win) })
    assert.spy(delete).was.called(1)
    assert.spy(delete).was.called_with(group)
  end)

  it("should create_scratch_buffer() set correct field", function()
    local buf = utils.create_scratch_buffer()
    local getopt = function(key)
      return vim.api.nvim_get_option_value(key, { buf = buf })
    end
    eq(true, buf > 0)
    eq("nofile", getopt("buftype"))
    eq("wipe", getopt("bufhidden"))
    eq("spinner", getopt("filetype"))
    eq(false, getopt("swapfile"))
    eq(false, getopt("undofile"))
  end)
end)
