# spinner.nvim

Lightweight spinner component for Neovim.

## Quick Start

Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
return {
  {
    "xieyonn/spinner.nvim",
    config = function()
      require("spinner").setup({
        -- options here
      })
    end,
  },
}
```

Display the spinner next to the cursor:

```lua
:= require("spinner").cursor_spinner({ ttl = 2000 }):start()
```

<img src="example/example.gif" alt="Preview Image" width="580">

## Usage

Use `require("spinner").new()` to create a spinner object, which you can
treat as a read-only string (`tostring(sp)`) that updates automatically.

You can place it wherever you want to display the spinner.

To make the spinner actually animate, you need to provide an `on_change()` callback
(called when spinner move to next frame) so it can refresh the UI.

for example, create a spinner in statusline.

```lua
local sp = require("spinner").new({
    on_change = function()
        -- refresh statusline so the spinner animate.
        vim.cmd("redrawstatus")
    end
})
```

This is essentially just a function that has already been encapsulated as
`require("spinner").statusline_spinner()`

### statusline/tabline spinner

```lua
--- 1. create a spinner
local sp = require("spinner").statusline_spinner()
-- local sp = require("spinner").tabline_spinner()

--- 2. define a global function
function sp_component()
  return tostring(sp)
  -- you can add extra text here
  -- return tostring(sp) .. "something"
end

--- 3. set statusline/tabline
vim.o.statusline = vim.o.statusline .. "%!v:lua.sp_component()"
-- vim.o.tabline = vim.o.tabline .. "%!v:lua.sp_component()"

--- 4. start/stop spinner according to your needs.
sp:start()
sp:stop()
```

### cursor spinner

```lua
local sp = require("spinner").cursor_spinner()
--- start spinner
sp:start()
--- stop spinner
sp:stop()
```

### subscribe events

LspProgress:

```lua
local sp = require("spinner").cursor_spinner()
vim.api.nvim_create_autocmd("LspProgress", {
  callback = function(event)
    local kind = event.data.params.value.kind
    if kind == "begin" then
      sp:start()
    end
    if kind == "end" then
      sp:stop()
    end
  end,
})
```

## Options

Default:

```lua
local default_opts = {
  texts = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },
  interval = 80, -- refresh millisecond.
  ttl = 0, -- the spinner will automatically stop after that {ttl} millisecond.

  -- CursorSpinner Options
  hl_group = "Spinner", -- link to `NormalFloat` by default.
  winblend = 60, -- CursorSpinner window option.
  width = 3, -- CursorSpinner window option.
  zindex = 50, -- CursorSpinner window option.
  row = -1, -- CursorSpinner window position, relative to cursor.
  col = 1, -- CursorSpinner window position, relative to cursor.
}
```
