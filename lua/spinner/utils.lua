local uv = vim.uv or vim.loop

---@param quotestr string
---@param P fun(value: boolean|string|integer|function|table|vim.lpeg.Pattern): vim.lpeg.Pattern
---@param C fun(patt: boolean|string|integer|function|table|vim.lpeg.Pattern): vim.lpeg.Pattern
---@return vim.lpeg.Pattern pattern
local function qtext(quotestr, P, C)
  local quote = P(quotestr)
  local escaped_quote = P("\\") * quote
  return quote * C(((1 - P(quote)) + escaped_quote) ^ 0) * quote
end

---@class spinner.utils
local M = {}

M.AUGROUP = vim.api.nvim_create_augroup("spinner", { clear = true })

---@return integer now
function M.now_ms()
  return math.floor(uv.hrtime() / 1e6)
end

---
--- Split an argument string on whitespace characters into a list,
--- except if the whitespace is contained within single or double quotes.
---
--- Leading and trailing whitespace is removed.
---
--- Examples:
---
--- ```lua
--- require("dap.utils").splitstr("hello world")
--- {"hello", "world"}
--- ```
---
--- ```lua
--- require("dap.utils").splitstr('a "quoted string" is preserved')
--- {"a", "quoted string", "is, "preserved"}
--- ```
---
--- Requires nvim 0.10+
---
--- @see nvim-dap https://github.com/mfussenegger/nvim-dap
--- @param str string
--- @return string[] splitted
function M.splitstr(str)
  str = str:match("^%s*(.*%S)")
  if not str or str == "" then
    return {}
  end

  local P, S, C = vim.lpeg.P, vim.lpeg.S, vim.lpeg.C
  local space = S(" \t\n\r") ^ 1
  local unquoted = C((1 - space) ^ 0)
  local element = qtext('"', P, C) + qtext("'", P, C) + unquoted
  local p = vim.lpeg.Ct(element * (space * element) ^ 0)
  return vim.lpeg.match(p, str)
end

---@alias spinner.VimCompFn fun(ArgLead: string, CmdLine: string, CursorPos: integer): comps: string[]|nil
---
---@class spinner.CompContext
---@field words string[]
---@field cur string
---@field prev string
---@field index number
---
---@alias spinner.CompFn fun(ctx: spinner.CompContext): items: string[]|nil

---Build vim complete function with a bash-like complete function {fn}, which
---accept a `spinner.CompContext` object as completion context.
---@param fn spinner.CompFn
---@return spinner.VimCompFn comp_fun
function M.create_comp(fn)
  return function(_, cmdline, cursorpos)
    local ctx = {}
    local before = cmdline:sub(1, cursorpos)

    local words = M.splitstr(before)
    ctx.words = words
    ctx.cur = ""
    ctx.prev = ""

    if before:match("%s$") then
      ctx.cur = ""
      ctx.prev = words[#words] or ""
    else
      ctx.cur = words[#words] or ""
      ctx.prev = words[#words - 1] or ""
    end

    local items = fn(ctx)

    if ctx.cur == "" or not items then
      return items
    end

    return vim
      .iter(items)
      :filter(function(v)
        return vim.startswith(v, ctx.cur)
      end)
      :totable()
  end
end

---Deduplicate a list while preserving order
---@generic T: Comparable
---@param list T[]
---@return T[] result
function M.deduplicate_list(list)
  local seen = {} ---@type table<string|integer, boolean>
  local result = {}
  for _, item in ipairs(list) do
    if not seen[item] then
      seen[item] = true
      table.insert(result, item)
    end
  end
  return result
end

---Create a scratch buffer
---@return integer
function M.create_scratch_buffer()
  local buf = vim.api.nvim_create_buf(false, true)

  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  vim.api.nvim_set_option_value("filetype", "spinner", { buf = buf })
  vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
  vim.api.nvim_set_option_value("undofile", false, { buf = buf })
  return buf
end

---Exec {cb} when window {win} close.
---@param win integer
---@param cb function
function M.on_win_closed(win, cb)
  local group = vim.api.nvim_create_augroup(
    ("spinner-winid-%d"):format(win),
    { clear = true }
  )

  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    callback = function(args)
      if tonumber(args.match) ~= win then
        return
      end

      cb(win)
      vim.api.nvim_del_augroup_by_id(group)
    end,
  })
end

return M
