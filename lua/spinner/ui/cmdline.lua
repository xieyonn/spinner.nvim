local STATUS = require("spinner.status")

return function(state)
  return function()
    if state.status == STATUS.STOPPED or state.status == STATUS.PAUSED then
      vim.cmd("echo ''")
      return
    end

    local spinner_text = state:render()

    -- Find and extract content between highlight markers
    local start_pos, end_pos = string.find(spinner_text, "{{SPINNER_HIGHLIGHT}}")
    local end_start, end_pos2 = string.find(spinner_text, "{{END_HIGHLIGHT}}")

    if start_pos and end_pos and end_start and end_pos2 then
      -- Extract the text between the markers (this is what should be highlighted)
      local before_highlight = string.sub(spinner_text, 1, start_pos - 1)
      local highlighted_text = string.sub(spinner_text, end_pos + 1, end_start - 1)
      local after_highlight = string.sub(spinner_text, end_pos2 + 1)

      -- Display the parts with appropriate highlighting
      vim.cmd("echo '" .. before_highlight:gsub("'", "''") .. "'")
      vim.cmd("echohl Spinner")
      vim.cmd("echon '" .. highlighted_text:gsub("'", "''") .. "'")
      vim.cmd("echohl None")
      vim.cmd("echon '" .. after_highlight:gsub("'", "''") .. "'")
    else
      -- No highlight markers found, display the whole text
      vim.cmd("echo '" .. spinner_text:gsub("'", "''") .. "'")
    end
  end
end
