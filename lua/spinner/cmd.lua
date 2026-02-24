local api = vim.api

---@class spinner.cmd
local M = {}
local utils = require("spinner.utils")

local subcmds = { "start", "stop", "pause", "reset", "fail" }

-- Completion function for Spinner command
---@param engine spinner.Engine
---@return spinner.VimCompFn comp_fun
local function spinner_completion(engine)
  return utils.create_comp(function(ctx)
    if ctx.prev == "Spinner" then
      return subcmds
    end

    local ids = {} ---@type string[]
    for id, _ in pairs(engine.state_map) do
      if rawget(engine.state_map, id) then
        table.insert(ids, id)
      end
    end

    local entered_ids = {} ---@type table<string, boolean>
    for i = 3, #ctx.words do
      entered_ids[ctx.words[i]] = true
    end

    local available_ids = {} ---@type string[]
    for _, id in ipairs(ids) do
      if not entered_ids[id] then
        table.insert(available_ids, id)
      end
    end

    return available_ids
  end)
end

---@param engine spinner.Engine
local function spinner_cmd(engine)
  api.nvim_create_user_command("Spinner", function(opts)
    if vim.tbl_isempty(opts.fargs) then
      vim.notify(
        "[spinner.nvim]: Missing subcommand. Use one of: "
          .. table.concat(subcmds, ", "),
        vim.log.levels.WARN
      )
      return
    end

    local subcmd = opts.fargs[1]
    local spinner_ids = { unpack(opts.fargs, 2) } -- All remaining arguments are spinner IDs

    -- Deduplicate spinner IDs while preserving order
    local unique_spinner_ids = utils.deduplicate_list(spinner_ids)

    for _, id in ipairs(unique_spinner_ids) do
      if not rawget(engine.state_map, id) then
        vim.notify(
          ("[spinner.nvim]: spinner %s not setup yet"):format(id),
          vim.log.levels.WARN
        )
        -- Continue to next spinner instead of returning
      elseif not vim.list_contains(subcmds, subcmd) then
        vim.notify(
          "[spinner.nvim]: Unknown subcommand '"
            .. subcmd
            .. "'. Use one of: "
            .. table.concat(subcmds, ", "),
          vim.log.levels.WARN
        )
        return
      end

      if subcmd == "start" then
        engine:start(id)
      elseif subcmd == "stop" then
        engine:stop(id, true)
      elseif subcmd == "pause" then
        engine:pause(id)
      elseif subcmd == "reset" then
        engine:reset(id)
      elseif subcmd == "fail" then
        engine:fail(id)
      end
    end
  end, {
    nargs = "+",
    desc = ("Control spinners (%s)"):format(table.concat(subcmds, ", ")),
    complete = spinner_completion(engine),
    force = true,
  })
end

---@param engine spinner.Engine
function M.setup(engine)
  spinner_cmd(engine)
end

return M
