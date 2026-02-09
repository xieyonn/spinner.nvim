local STATUS = require("spinner.status")

local spinner_ns = vim.api.nvim_create_namespace("spinner.nvim")

---@param state spinner.State
---@return function
return function(state)
  local extmark_id = nil ---@type integer|nil

  return function()
    local opts = state.opts
    local ns = opts.ns or spinner_ns

    if not opts.bufnr or not opts.row or not opts.col then
      return
    end

    if not vim.api.nvim_buf_is_valid(opts.bufnr) then
      return
    end

    if STATUS.STOPPED == state.status then
      if extmark_id then
        pcall(vim.api.nvim_buf_del_extmark, opts.bufnr, ns, extmark_id)
        extmark_id = nil
      end
      return
    end

    local text = state:render()

    -- Try to update existing extmark
    if extmark_id then
      local success = pcall(
        vim.api.nvim_buf_set_extmark,
        opts.bufnr,
        ns,
        opts.row,
        opts.col,
        {
          id = extmark_id,
          virt_text = { { text, opts.hl_group or "Spinner" } },
          virt_text_pos = "eol",
        }
      )

      -- If update succeeds, nothing more to do
      if success then
        return
      end
      -- If update fails, clear the ID so we create a new extmark
      extmark_id = nil
    end

    -- Create a new extmark
    local ok, id =
      pcall(vim.api.nvim_buf_set_extmark, opts.bufnr, ns, opts.row, opts.col, {
        virt_text = { { text, opts.hl_group or "Spinner" } },
        virt_text_pos = "eol",
      })

    if not ok then
      return
    end

    extmark_id = id
  end
end
