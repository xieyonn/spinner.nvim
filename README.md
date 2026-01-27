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
:= require("spinner").CursorSpinner:new({ ttl = 2000 }):start()
```

<img src="example/example.gif" alt="Preview Image" width="580">

## Options

Default:

```lua
local default_opts = {
  chars = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },
  speed = 80, -- refresh millisecond.
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

## Example

see
[example](https://github.com/xieyonn/spinner.nvim/blob/main/example/example.lua)
