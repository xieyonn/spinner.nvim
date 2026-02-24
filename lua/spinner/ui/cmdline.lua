local api = vim.api

---@param state spinner.State
---@return function
return function(state)
  return function()
    local text = state:render()
    local hl = state:get_hl_group()

    if not hl then
      api.nvim_echo({ { text } }, false, {})
      return
    end

    -- Find and extract content between highlight markers
    local start_pos, end_pos = text:find("{{SPINNER_HIGHLIGHT}}")
    local end_start, end_pos2 = text:find("{{END_HIGHLIGHT}}")

    if not (start_pos and end_pos and end_start and end_pos2) then
      -- No highlight markers found, display the whole text
      api.nvim_echo({ { text } }, false, {})
      return
    end

    -- Extract the text between the markers (this is what should be highlighted)
    local before_highlight = text:sub(1, start_pos - 1)
    local highlighted_text = text:sub(end_pos + 1, end_start - 1)
    local after_highlight = text:sub(end_pos2 + 1)

    api.nvim_echo(
      { { before_highlight }, { highlighted_text, hl }, { after_highlight } },
      false,
      {}
    )
  end
end
