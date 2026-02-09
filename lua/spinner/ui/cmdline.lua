local STATUS = require("spinner.status")

---@param state spinner.State
return function(state)
  return function()
    if state.status == STATUS.STOPPED or state.status == STATUS.PAUSED then
      vim.cmd.echo("''")
      return
    end

    local spinner_text = state:render()

    -- Find and extract content between highlight markers
    local start_pos, end_pos = spinner_text:find("{{SPINNER_HIGHLIGHT}}")
    local end_start, end_pos2 = spinner_text:find("{{END_HIGHLIGHT}}")

    if not (start_pos and end_pos and end_start and end_pos2) then
      -- No highlight markers found, display the whole text
      vim.cmd.echo(("'%s'"):format(spinner_text:gsub("'", "''")))
      return
    end

    -- Extract the text between the markers (this is what should be highlighted)
    local before_highlight = spinner_text:sub(1, start_pos - 1)
    local highlighted_text = spinner_text:sub(end_pos + 1, end_start - 1)
    local after_highlight = spinner_text:sub(end_pos2 + 1)

    -- Display the parts with appropriate highlighting
    vim.cmd.echo(("'%s'"):format(before_highlight:gsub("'", "''")))
    vim.cmd.echohl("Spinner")
    vim.cmd.echon(("'%s'"):format(highlighted_text:gsub("'", "''")))
    vim.cmd.echohl("None")
    vim.cmd.echon(("'%s'"):format(after_highlight:gsub("'", "''")))
  end
end
