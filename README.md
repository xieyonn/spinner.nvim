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

1. Create a spinner object

```lua
local sp = require("spinner").new()
```

> you can treat `sp` as a read-only string that updates automatically.

2. Place `sp` to wherever you want.
   eg: statusline

```lua
-- use a global function here.
function sp_component()
  return tostring(sp)
end

vim.o.statusline = vim.o.statusline .. "%!v:lua.sp_component()"
```

3. In order to make the spinner actually animate, you need to provide an
   `on_change` callback (called when spinner move to next frame) so it can
   refresh the UI.

```lua
local sp = require("spinner").new({
    on_change = function()
        -- refresh statusline
        vim.cmd("redrawstatus")
    end
})

-- This is essentially just a function that has already been encapsulated as `statusline_spinner`.
local sp = require("spinner").statusline_spinner()

--- create a tabline_spinner, which call vim.cmd("redrawtabline") in on_change.
local sp = require("spinner").tabline_spinner()

--- create a cursor spinner, which create a floating window to display spinner.
local sp = require("spinner").cursor_spinner()
```

4. start/stop spinner according to your needs.

```lua
sp:start()
sp:stop()
```

A example of subscribe `LspProgress` event:

```lua
local lsp_work_by_client_id = {}
vim.api.nvim_create_autocmd("LspProgress", {
  callback = function(event)
    local kind = event.data.params.value.kind
    local client_id = event.data.client_id

    local work = lsp_work_by_client_id[client_id] or 0
    local work_change = kind == "begin" and 1 or (kind == "end" and -1 or 0)
    lsp_work_by_client_id[client_id] = math.max(work + work_change, 0)

    if work == 0 and work_change > 0 then
      sp:start()
    end
    if work == 1 and work_change < 0 then
      sp:stop()
    end
  end,
})
```

## Options

Default Options:

```lua
local default_opts = {
  texts = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },
  interval = 80, -- refresh millisecond.
  ttl = 0, -- the spinner will automatically stop after that {ttl} millisecond.
  initial_delay = 200, -- delay display spinner after {initial_delay} millisecond.
  on_change = nil, -- spinner will call {on_change} when spinner animate. use
  --                    this callback to update UI, eg: redrawstatus

  -- CursorSpinner Options
  hl_group = "Spinner", -- highlight group for spinner text, link to NormalFloat by default.
  winblend = 60, -- CursorSpinner window option.
  width = 3, -- CursorSpinner window option.
  zindex = 50, -- CursorSpinner window option.
  row = -1, -- CursorSpinner window position, relative to cursor.
  col = 1, -- CursorSpinner window position, relative to cursor.
}
```

`on_change` callback

```lua
---@class spinner.Event
---@field text string current spinner frame
---@field enabled boolean true -> start, false -> stop

---@field on_change? fun(event: spinner.Event)
```
