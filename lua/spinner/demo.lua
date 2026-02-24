local api = vim.api

local pattern_map = require("spinner.pattern")
local utils = require("spinner.utils")

---@class spinner.demo
local M = {}

---padding str
---@param str string
---@param max integer
---@return string
local function pad(str, max)
  local l = #str
  if l >= max then
    return str
  end

  return string.rep(" ", max - l) .. str
end

---Open a window show all preset patterns.
function M.open()
  local bufnr = utils.create_scratch_buffer()

  local width = math.floor(vim.o.columns * 0.4)
  local height = math.floor(vim.o.lines * 0.6)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  local win = api.nvim_open_win(bufnr, true, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    style = "minimal",
    focusable = true,
    border = "rounded",
    noautocmd = false,
  })
  if win == 0 then
    vim.notify("[spinner.nvim] fail to open demo window", vim.log.levels.ERROR)
    return
  end

  local lines = {}
  local i = 0
  local patterns = {}
  for pattern in vim.spairs(pattern_map) do
    table.insert(lines, pad(pattern, 30))
    table.insert(patterns, pattern)

    require("spinner").config(pattern, {
      kind = "extmark",
      pattern = pattern,
      bufnr = bufnr,
      row = i,
      col = 30,
    })
    i = i + 1
  end

  api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  for pattern in vim.spairs(pattern_map) do
    require("spinner").start(pattern)
  end

  for _, key in ipairs({ "q", "<Esc>" }) do
    vim.keymap.set("n", key, function()
      if api.nvim_win_is_valid(win) then
        api.nvim_win_close(win, true)
      end
    end, {
      buffer = bufnr,
      nowait = true,
      silent = true,
    })
  end

  api.nvim_create_autocmd("BufWipeout", {
    buffer = bufnr,
    callback = function()
      for _, pattern in ipairs(patterns) do
        require("spinner").stop(pattern)
      end
    end,
  })
end

return M
