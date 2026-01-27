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

## APIS

```lua
local spinner = require(spinner)

-- create a spinner
local sp = spinner.new()
-- statusline spinner
sp = spinner.statusline_spinner()
--- tabline spinner
sp = spinner.tabline_spinner()
--- cursor spinner
sp = spinner.cursor_spinner()


--- start spinner
sp:start()
--- sopt spinner
sp:stop()
```

see more example: [example](https://github.com/xieyonn/spinner.nvim/blob/main/example/example.lua)

## Options

Default:

```lua
local default_opts = {
  texts = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },
  interval = 80, -- refresh millisecond.
  ttl = 0, -- the spinner will automatically stop after that {ttl} millisecond.

  -- CursorSpinner
  hl_group = "Spinner", -- link to `NormalFloat` by default.
  winblend = 60, -- CursorSpinner window option.
  width = 3, -- CursorSpinner window option.
  zindex = 50, -- CursorSpinner window option.
  row = -1, -- CursorSpinner window position, relative to cursor.
  col = 1, -- CursorSpinner window position, relative to cursor.
}
```
