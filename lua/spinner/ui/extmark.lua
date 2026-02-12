local STATUS = require("spinner.status")

local spinner_ns = vim.api.nvim_create_namespace("spinner.nvim")

---@param state spinner.State
---@return function
return function(state)
  local extmark_id = nil ---@type integer|nil

  local stop = function()
    require("spinner").stop(state.id, true)
  end

  return function()
    local opts = state.opts
    local ns = opts.ns or spinner_ns

    if not opts.bufnr or not opts.row or not opts.col then
      stop()
      return
    end

    if not vim.api.nvim_buf_is_valid(opts.bufnr) then
      stop()
      return
    end

    local text = state:render()

    -- only delete extmark if text is empty, eg: we have a non-empty placeholder
    if (STATUS.STOPPED == state.status) and "" == text then
      if extmark_id then
        pcall(vim.api.nvim_buf_del_extmark, opts.bufnr, ns, extmark_id)
        extmark_id = nil
      end
      return
    end

    ---@type vim.api.keyset.set_extmark
    local extmark_opts = {
      virt_text = { { text, state:get_hl_group() } },
      virt_text_pos = opts.virt_text_pos or "eol",
    }
    if opts.virt_text_win_col then
      extmark_opts.virt_text_win_col = opts.virt_text_win_col
    end

    -- Try to update existing extmark
    if extmark_id then
      extmark_opts.id = extmark_id

      local success = pcall(
        vim.api.nvim_buf_set_extmark,
        opts.bufnr,
        ns,
        opts.row,
        opts.col,
        extmark_opts
      )

      if success then
        return
      end

      extmark_id = nil
    end

    -- Create a new extmark
    local ok, id = pcall(
      vim.api.nvim_buf_set_extmark,
      opts.bufnr,
      ns,
      opts.row,
      opts.col,
      extmark_opts
    )

    if not ok then
      stop()
      return
    end

    extmark_id = id
  end
end
