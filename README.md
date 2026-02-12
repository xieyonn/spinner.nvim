# spinner.nvim

Extensible spinner framework for Neovim plugins and UI.

[![coverage](https://img.shields.io/codecov/c/github/xieyonn/spinner.nvim?branch=main&logo=codecov)](https://codecov.io/gh/xieyonn/spinner.nvim)
[![release](https://img.shields.io/github/v/release/xieyonn/spinner.nvim)](https://github.com/xieyonn/spinner.nvim/releases/latest)
[![Requires Neovim 0.11+](https://img.shields.io/badge/requires-nvim%200.11%2B-9cf?logo=neovim)](https://neovim.io/)
[![license](https://img.shields.io/github/license/xieyonn/spinner.nvim)](https://github.com/xieyonn/spinner.nvim/blob/main/LICENSE)

<img src="https://github.com/user-attachments/assets/d8caeedd-017f-419b-a394-f3ce6dc25e3e" width="560" />

# Features

- **Multiple UI locations**:
    - Pre-defined `statusline`, `tabline`, `winbar`, `cursor`, `extmark`, `cmdline`, `window-title` and `window-footer`.
    - Any place you can render a text. see [Extend](#extend)
- **LSP integration**: show spinners for `LspProgress` and `LspRequest`.
- **Extensible API**: start / stop / pause a spinner in your plugins and configurations.
- **Configurable spinner patterns**: Built-in presets with 70+ [patterns](https://github.com/xieyonn/spinner.nvim/blob/main/lua/spinner/pattern.lua)

<div>
<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [Getting Started](#getting-started)
    - [Installation](#installation)
    - [Preview](#preview)
    - [Setup](#setup)
- [Example](#example)
- [Usage](#usage)
    - [Statusline](#statusline)
    - [Tabline](#tabline)
    - [Winbar](#winbar)
    - [Cursor](#cursor)
    - [Extmark](#extmark)
    - [Cmdline](#cmdline)
    - [Window Title](#window-title)
    - [Window Footer](#window-footer)
- [Extend](#extend)
- [Options](#options)
    - [Lsp Integration](#lsp-integration)
    - [Pattern](#pattern)
    - [TTL](#ttl)
    - [Initial Delay](#initial-delay)
    - [Placeholder](#placeholder)
    - [Formatting](#formatting)
    - [Highlight](#highlight)
- [Commands](#commands)
- [API Reference](#api-reference)
- [Contributing](#contributing)
- [Thanks](#thanks)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->
</div>

# Getting Started

Neovim's UI components do **NOT** refresh automatically.

So there are 2 ways to make the spinner animate:

- Insert a function into the UI component. It renders the spinner text on UI
  refresh, then refreshes this UI component at regular intervals. eg:
  statusline/tabline/winbar spinner.
- Periodically call the API to set the text content of the UI component. eg:
  cursor/extmark spinner.

`spinner.nvim` manages the internal state of the spinner and determines when to
refresh the UI. Each spinner is identified by a unique `id`, with option `kind`
to indicate how `spinner.nvim` refresh the UI.

| kind          | refresh method                                                         |
| ------------- | ---------------------------------------------------------------------- |
| statusline    | vim.cmd("redrawstatus) or vim.api.nvim\_\_redraw({ statusline = true}) |
| tabline       | vim.cmd("redrawtabline) or vim.api.nvim\_\_redraw({ tabline = true})   |
| winbar        | vim.cmd("redrawstatus) or vim.api.nvim\_\_redraw({ winbar = true})     |
| extmark       | vim.api.nvim_buf_set_extmarks()                                        |
| cursor        | vim.api.nvim_win_open() + vim.api.nvim_buf_set_lines()                 |
| cmdline       | vim.cmd("echo 'text'")                                                 |
| window-title  | vim.api.nvim_win_set_config()                                          |
| window-footer | vim.api.nvim_win_set_config()                                          |
| custom        | you tell how, see [Extend](#extend)                                    |

Control spinners via lua api:

```lua
local spinner = require("spinner")

-- 1. Setup a spinner with a unique id.
spinner.config("id", opts)

-- 2. Set up spinner content in the desired location with `render()`.
local text = spinner.render("id")

-- 3. Control spinner as need.
spinner.start("id") -- Start a spinner
spinner.stop("id") -- Stop a spinner
spinner.pause("id") -- Pause a spinner
```

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "xieyonn/spinner.nvim",
  config = function()
    ---@type spinner
    local sp = require("spinner")

    -- NO need to call setup() if you are fine with defaults.
    sp.setup()
  end
}
```

## Preview

Type in command line:

```vim
= require("spinner.demo").open()
```

Will open a window displaying all built-in spinners.

<img src="https://github.com/user-attachments/assets/36000baf-54ab-4e93-b04a-be9d364223dc" width="800" />

## Setup

Setup defaults for spinners.

```lua
require("spinner").setup({
  -- Pre-defined pattern key name in
  -- https://github.com/xieyonn/spinner.nvim/blob/main/lua/spinner/pattern.lua
  pattern = "dots",

  -- Time-to-live in milliseconds since the most recent start, after which the
  -- spinner stops, preventing it from running indefinitely.
  ttl_ms = 0,

  -- Milliseconds to wait after startup before showing the spinner.
  -- This helps prevent the spinner from briefly flashing for short-lived tasks.
  initial_delay_ms = 0,

  -- Text displayed when the spinner is inactive.
  -- **Not** Used in cmdline
  --
  -- true: show an empty string, with length equal to spinner frames.
  -- false: equals to "".
  -- or string values
  --
  -- eg: show ✔ when lsp progress finished.
  placeholder = false,

  -- Highlight group for text, `Spinner` use fg of `Comment` by default.
  hl_group = "Spinner",

  cursor_spinner = {
    -- CursorSpinner window option.
    winblend = 60,

    -- CursorSpinner window option.
    zindex = 50,

    -- CursorSpinner window position, relative to cursor.
    -- row = -1 col = 1 means Above-Right.
    row = -1,
    col = 1,
  }
})
```

# Example

<img src="https://github.com/user-attachments/assets/19fe17a9-5359-478e-8b6f-a0b8a2319229" width="700" />

- Display lsp client name (lua_ls) and lsp progress in `statusline`.
- Display spinner right above cursor when press `K` (lsp_hover)

1. setup a `statusline` spinner with id `lsp_progress` and attach to `LspProgress`

```lua
require("spinner").config("lsp_progress", {
  kind = "statusline", -- spinner kind.
  placeholder = "✔", -- a nice symbol to indicate lsp is ready.
  attach = {
    lsp = {
      progress = true, -- attach to LspProgress event.
    },
  },
})
```

2. create a global function to concat lsp client names and render spinner text.

> if you setup statusline by `vim.o.statusline`, you need a global function.
> or if you use a statusline plugin, you can set this function local.

```lua
function lsp_progress()
  local client_names = {}
  local seen = {}

  -- need to remove duplicate because somehow a buffer may attached to multiple
  -- clients with same name.
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
    local name = client and client.name or ""
    if name ~= "" and not seen[name] then
      table.insert(client_names, name)
      seen[name] = true
    end
  end
  -- if no active lsp clients, leave it empty
  if #client_names == 0 then
    return ""
  end

  local spinner = require("spinner").render("lsp_progress")

  return table.concat(client_names, " ") .. " " .. spinner
end
```

3. setup statusline

```lua
vim.o.statusline = vim.o.statusline .. "%!v:lua.lsp_progress()"
```

4. setup a `cursor` spinner with id `cursor` and attach to `LspRequest`

```lua
require("spinner").config("cursor", {
  kind = "cursor", -- kind cursor
  attach = {
    lsp = {
      request = {
        -- select the methods you're interested in. For a complete list: `:h lsp-method`
        -- "textDocument/definition", -- for GoToDefinition (shortcut `C-]`)
        "textDocument/hover", -- for hover (shortcut `K`)
      },
    },
  },
})
```

# Usage

## Statusline

1. Configure a `statusline` spinner with id `my_spinner`.

```lua
require("spinner").config("my_spinner", {
  kind = "statusline",
})
```

2. Set `vim.o.statusline`.

```lua
-- Need a global function here.
function my_spinner()
  return require("spinner").render("my_spinner")
end

vim.o.statusline = vim.o.statusline .. "%!v:lua.my_spinner()"
```

3. Start/stop/pause the spinner where needed.

```lua
-- start spinner
require("spinner").start("my_spinner")

-- stop spinner
require("spinner").stop("my_spinner")

-- spinner.nvim internally tracks the number of start/stop calls for the same
-- spinner. It only stops spinning when the number of stop calls >= start calls.
-- use a second param `true` to force stop a spinner.
require("spinner").stop("my_spinner", true)

-- pause a spinner
require("spinner").pause("my_spinner")
```

By default, `spinner.nvim` refreshes the statusline using `vim.cmd("redrawstatus")`.
If you use a statusline plugin, it may take over the refresh mechanism, causing
the spinner to behave incorrectly due to refresh/frame-rate issues.

You can use the `on_update_ui` option to let your statusline plugin handle updates properly.

eg: if you use [lualine.nvim](https://github.com/nvim-lualine/lualine.nvim)

```lua
require("spinner").config("my_spinner", {
  kind = "statusline",
  on_update_ui = function()
    require("lualine").refresh() -- use lualine's refresh method
  end,
})
```

> lualine.nvim is auto-detect and support by default.

## Tabline

1. Configure a `tabline` spinner with id `my_spinner`.

```lua
require("spinner").config("my_spinner", {
  kind = "tabline",
})
```

2. Set `vim.o.tabline`.

```lua
-- this function need to be a global function
function my_spinner()
  return require("spinner").render("my_spinner")
end

vim.o.tabline = vim.o.tabline .. "%!v:lua.my_spinner()"
```

> spinner.nvim use `vim.cmd("redrawtabline")` to refresh tabline.
> if you use a plugin to setup tabline, you may need to provide a `on_update_ui`
> option to refresh tabline. See [Statusline](#statusline).

## Winbar

1. Configure a `winbar` spinner with id `my_spinner`.

```lua
require("spinner").config("my_spinner", {
  kind = "winbar",
})
```

2. Set `vim.o.winbar`.

```lua
-- this function need to be a global function
function my_spinner()
  return require("spinner").render("my_spinner")
end

vim.o.winbar = vim.o.winbar .. "%!v:lua.my_spinner()"
```

> spinner.nvim use `vim.cmd("redrawstatus")` to refresh winbar.
> if you use a plugin to setup winbar, you may need to provide a `on_update_ui`
> option to refresh tabline. See [Statusline](#statusline).

## Cursor

`spinner.nvim` use a float window relative to cursor to displaying spinner.
create the float window when spinner start/pause, close the float window when stop.

> If you want to show multiple `cursor` spinners, be careful with id.

Configure a `cursor` spinner with id.

```lua
local row, col
require("spinner").config("cursor", {
  kind = "cursor",

  -- highlight group for text, use fg of `Comment` by default.
  hl_group = "Spinner", -- optional

  -- CursorSpinner window option.
  winblend = 60, -- optional

  -- CursorSpinner window option.
  zindex = 50, --optional

  -- CursorSpinner window position, relative to cursor.
  row = -1, --optional

  -- CursorSpinner window position, relative to cursor.
  col = 1, --optional
})
```

`row` and `col` means the position relative to cursor.

- `{ row = -1, col = 1 }` Above-Right
- `{ row = -1, col = -1 }` Above-Left
- `{ row = 1, col = 1 }` Below-Right
- `{ row = 1, col = -1 }` Below-Left

## Extmark

`spinner.nvim` uses Neovim `extmarks` (see `h: extmark`) to attach spinners to buffer
positions.

Extmarks automatically track positions as the text changes, ensuring the spinner
stays correctly aligned even when you edit the buffer, like diagnostic messages.

> If you want to show multiple spinners at the same time, be careful with the
> spinner id.

Configure an `extmark` spinner with id.

```lua
local bufnr, row, col
local id = string.format("extmark-spinner-%d-%d-%d", bufnr, row, col)
require("spinner").config(id, {
  kind = "extmark",
  bufnr = bufnr, -- must be provided
  row = row, -- must be provided, which line, 0-based
  col = col, -- must be provided, which col, 0-based

  ns = 0, -- namespace, optional
  hl_group = "Spinner" -- hl_group for text, optional
  virt_text_pos = "eol" -- options for `vim.api.nvim_buf_set_extmark`, optional
  virt_text_win_col = nil -- options for `vim.api.nvim_buf_set_extmarks`, optional
})
```

`virt_text_pos` and `virt_text_win_col` determine spinner position.

| virt_text_pos | virt_text_win_col | Description                                          |
| ------------- | ----------------- | ---------------------------------------------------- |
| overlay       | nil               | Draws at the `col` anchor                            |
| overlay       | integer           | Draws at the specified window column, ignoring `col` |
| eol           | nil               | Draws at the end of the line                         |
| eol           | integer           | `virt_text_win_col` is ignored                       |
| right_align   | nil               | Aligns text to the right of the window               |
| right_align   | integer           | `virt_text_win_col` is ignored                       |
| inline        | nil               | Inserts at the specified `col`                       |
| inline        | integer           | `virt_text_win_col` is ignored                       |

> See `h: nvim_buf_set_extmarks()`.

## Cmdline

Configure a `cmdline` spinner with id `my_spinner`.

```lua
require("spinner").config("my_spinner", {
  kind = "cmdline"
  hl_group = "Spinner" -- hl_group for text, optional
})
```

## Window Title

Configure a `window-title` spinner:

```lua
local win = nil -- target win
local id = string.format("window-title:%d", win)
require("spinner").config(id, {
  kind = "window-title",
  win = win, -- target win, must provided

  pos = "center", -- optional, can be "left", "center", "right", default is "center"
  hl_group = "", -- optional, set hl_group for text

  -- optional, use fmt function to add extra text.
  fmt = function(event)
    local text = event.text
    return text .. " This is a title"
  end,
})
```

Spinner will stop when window close.

A preview:

<img src="https://github.com/user-attachments/assets/004f8907-d2ef-41b3-ade2-20d7335da24f" width="700" />

## Window Footer

Configure a `window-footer` spinner:

```lua
local win = nil -- target win
local id = string.format("window-footer:%d", win)
require("spinner").config(id, {
  kind = "window-footer",
  win = win, -- target win, must provided

  pos = "center", -- optional, can be "left", "center", "right", default is "center"
  hl_group = "", -- optional, set hl_group for text

  -- optional, use fmt function to add extra text.
  fmt = function(event)
    local text = event.text
    return text .. " This is a footer"
  end,
})
```

Spinner will stop when window close.

A preview:

<img src="https://github.com/user-attachments/assets/daf3b537-4998-4016-8aac-d622e9b58f35" width="700" />

# Extend

`spinner.nvim` decides when to refresh the UI, you decide where and how.

Use option `on_update_ui` to implement a `custom` spinner.

```lua
local id = "my_spinner"
require("spinner").config(id, {
  kind = "custom",

  -- must provide, called when refresh UI.
  on_update_ui = function(event)
    local status = event.status -- spinner status
    local text = event.text -- spinner text

    -- do what you want
  end,

  -- optional, used to improve performance, take spinner id by default
  ui_scope = id,
})
```

Option `ui_scope` defines the scope for batching UI updates.

Spinners with the same `ui_scope` will have their UI updates combined within a
short period of time to improve performance.

- All `statusline` spinners share the `statusline` scope and update together.
- All `tabline` spinners share the `tabline` scope and update together.
- Custom spinners with the same `ui_scope` will update together.

Here is a example shows how to display spinner in a window title. (only float
window can set title)

```lua
local bufnr = vim.api.nvim_create_buf(false, true)
local win = vim.api.nvim_open_win(bufnr, true, {})
local spinner_id = string.format("win-%d", win)
require("spinner").config(spinner_id, {
  kind = "custom",
  ui_scope = spinner_id, -- Tell spinner.nvim not to merge refreshes with other spinners.
  on_update_ui = function(event)
    if not (win and vim.api.nvim_win_is_valid(win)) then
      return
    end

    vim.api.nvim_win_set_config(win, {
      title = event.text,
      title_pos = "center",
    })
  end,
})

-- start spinner
require("spinner").start(spinner_id)
```

This is how the built-in `window-title` spinner is implemented.

# Options

## Lsp Integration

Configure spinner with `attach` option to make it listen to `LspProgress` or `LspRequest`.

```lua
require("spinner").config("cursor", {
  kind = "cursor",
  attach = {
    lsp = {
      progress = true, -- listen to LspProgress

      request = {
        -- Select the methods you're interested in. For a complete list: `:h lsp-method`
        -- "textDocument/definition", -- for GoToDefinition (shortcut `C-]`)
        "textDocument/hover", -- for hover (shortcut `K`)
      },

      -- Optional, select lsp names you're interested in.
      client_names = {
        "lua_ls",
      }
    },
  },
})
```

## Pattern

`spinner.nvim` provides a large number of built-in patterns. See [patterns](https://github.com/xieyonn/spinner.nvim/blob/main/lua/spinner/pattern.lua)

Or you can set up a custom pattern:

```lua
require("spinner").config("my_spinner", {
  kind = "statusline",
  pattern = {
    interval = 80, -- in milliseconds
    frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },
  },
})
```

## TTL

Tasks may fail or abort unexpectedly, causing the stop signal to never be received.
You can set a `ttl_ms` to prevent the spinner from spinning indefinitely.

```lua
require("spinner").config("my_spinner", {
  kind = "statusline",
  ttl_ms = 10000, -- 10 seconds
})
```

## Initial Delay

Some asynchronous tasks are too short: the spinner stops shortly after starting,
causing flickering. Use `initial_delay_ms` to delay the spinner startup and avoid
flickering.

```lua
require("spinner").config("my_spinner", {
  kind = "statusline",
  initial_delay_ms = 200, -- in milliseconds
})
```

## Placeholder

Set a default string to display when the spinner is idle.

`spinner.nvim` render spinner as an empty string with length == `len(frame)`,
you can set `placeholder = false` to disable this features. (will show a zero
length empty string when spinner is idle)

```lua
require("spinner").config("my_spinner", {
  kind = "statusline",

  -- eg: show ✔ when lsp progress finished.
  placeholder = "✔",
})
```

> cmdline spinner do not support (and needed) placeholder

## Formatting

You can customize the spinner text format using the `fmt` option. This function
receives the current text and status and returns the formatted string:

```lua
require("spinner").config("my_spinner", {
  kind = "statusline",
  fmt = function(event)
    local text = event.text
    local status = event.status
    return "[" .. text .. "]"
  end
})
```

## Highlight

You can customize the spinner text color by using the `hl_group` option.

```lua
require("spinner").config("my_spinner", {
  kind = "statusline",
  hl_group = "Spinner"
})
```

Or set a global default value in `setup()`

```lua
require("spinner").setup({
  hl_group = "Spinner",
})
```

> statusline / tabline / winbar will wrap text in format `%#HL_GROUP#...%*`

# Commands

`spinner.nvim` provides a command `Spinner`:

```vim
:Spinner start my_spinner    " Start a spinner
:Spinner stop my_spinner     " Stop a spinner
:Spinner pause my_spinner    " Pause a spinner
```

With tab completion for spinner IDs.

> Use it to test your configuration.

# API Reference

<details>
<summary>Click to expand</summary>

```lua
---@class spinner
---@field start fun(id: string) -- Start spinner.
---@field stop fun(id: string, force?: boolean) -- Stop spinner.
---@field pause fun(id: string) -- Pause spinner.
---@field config fun(id: string, opts?: spinner.Opts) -- Setup spinner.
---@field render fun(id: string): string -- Render spinner.
---@field setup fun(opts?: spinner.Config) -- Setup global configuration.

---@alias spinner.UIScope -- Used to combine UI updates.
---| "statusline"
---| "tabline"
---| "cursor"
---| string

---@alias spinner.Kind
---| "custom" -- Custom UI kind
---| "statusline" -- Statusline spinner
---| "tabline" -- Tabline spinner
---| "winbar" -- Winbar spinner
---| "cursor" -- Cursor spinner
---| "extmark" -- Extmark spinner
---| "cmdline" -- CommandLine spinner
---| "window-title" -- WindowTitle spinner
---| "window-footer" -- WindowFooter spinner

---@alias spinner.Opts
---| spinner.CoreOpts -- Core options
---| spinner.CustomOpts -- Custom options
---| spinner.StatuslineOpts -- Statusline options
---| spinner.TablineOpts -- Tabline options
---| spinner.WinbarOpts -- Winbar options
---| spinner.CursorOpts -- Cursor options
---| spinner.ExtmarkOpts -- Extmark options
---| spinner.CmdlineOpts -- CommandLine options
---| spinner.WindowTitleOpts -- WindowTitle options
---| spinner.WindowFooterOpts -- WindowFooter options
---
---@class spinner.CoreOpts
---@field kind? spinner.Kind -- Spinner kind
---@field pattern? string|spinner.Pattern -- Animation pattern
---@field ttl_ms? integer -- Time to live in ms
---@field initial_delay_ms? integer -- Initial delay in ms
---@field placeholder? string|boolean -- Placeholder text
---@field attach? spinner.Event -- Event attachment
---@field on_update_ui? fun(event: spinner.OnChangeEvent) -- UI update callback
---@field ui_scope? string custom ui_scope, used to improve UI refresh performance
---@field fmt? fun(event: spinner.OnChangeEvent): string -- Format function
---
---@class spinner.StatuslineOpts: spinner.CoreOpts
---@field kind "statusline" -- Statusline kind
---
---@class spinner.TablineOpts: spinner.CoreOpts
---@field kind "tabline" -- Tabline kind
---
---@class spinner.WinbarOpts: spinner.CoreOpts
---@field kind "winbar" -- Winbar kind
---
---@class spinner.CursorOpts: spinner.CoreOpts
---@field kind "cursor" -- Cursor kind
---@field hl_group? string -- Highlight group
---@field row? integer -- Position relative to cursor
---@field col? integer -- Position relative to cursor
---@field zindex? integer -- Z-index
---@field winblend? integer -- Window blend
---
---@class spinner.ExtmarkOpts: spinner.CoreOpts
---@field kind "extmark" -- Extmark kind
---@field bufnr integer -- Buffer number
---@field row integer -- Line position 0-based
---@field col integer -- Column position 0-based
---@field ns? integer -- Namespace
---@field hl_group? string -- Highlight group
---@field virt_text_pos? string -- options for vim.api.nvim_buf_set_extmark
---@field virt_text_win_col? integer -- options for `vim.api.nvim_buf_set_extmarks`
---
---@class spinner.WindowTitleOpts: spinner.CoreOpts
---@field kind "window-title"
---@field win integer -- target win id
---@field pos? string -- position, can be on of "left", "center" or "right"
---@field hl_group? string -- hl_group for text
---
---@class spinner.WindowFooterOpts: spinner.CoreOpts
---@field kind "window-footer"
---@field win integer -- target win id
---@field pos? string -- position, can be on of "left", "center" or "right"
---@field hl_group? string -- hl_group for text
---
---@class spinner.CmdlineOpts: spinner.CoreOpts
---@field kind "cmdline" -- CommandLine kind
---
---@class spinner.CustomOpts: spinner.CoreOpts
---@field kind "custom"
---@field on_update_ui fun(event: spinner.OnChangeEvent) -- UI update callback
---@field ui_scope? string custom ui_scope, use spinner id by default
---
---@class spinner.OnChangeEvent
---@field status spinner.Status -- Current status
---@field text string -- Current text

---@enum spinner.Status
local STATUS = {
  DELAYED = "delayed", -- Delayed status
  RUNNING = "running", -- Running status
  PAUSED = "paused", -- Paused status
  STOPPED = "stopped", -- Stopped status
}

---@class spinner.Pattern
---@field interval integer -- Animation interval
---@field frames string[] -- Animation frames

---@class spinner.Event
---@field lsp? spinner.Event.Lsp -- LSP event attachment
---
---@class spinner.Event.Lsp
---@field client_names? string[] -- Client names filter
---@field progress? boolean -- Progress event
---@field request? spinner.LspRequest[] -- Request events
---
---@alias spinner.LspRequest
---| 'callHierarchy/incomingCalls'
---| 'callHierarchy/outgoingCalls'
---| 'codeAction/resolve'
---| 'codeLens/resolve'
---| 'completionItem/resolve'
---| 'documentLink/resolve'
---| 'initialize'
---| 'inlayHint/resolve'
---| 'shutdown'
---| 'textDocument/codeAction'
---| 'textDocument/codeLens'
---| 'textDocument/colorPresentation'
---| 'textDocument/completion'
---| 'textDocument/declaration'
---| 'textDocument/definition'
---| 'textDocument/diagnostic'
---| 'textDocument/documentColor'
---| 'textDocument/documentHighlight'
---| 'textDocument/documentLink'
---| 'textDocument/documentSymbol'
---| 'textDocument/foldingRange'
---| 'textDocument/formatting'
---| 'textDocument/hover'
---| 'textDocument/implementation'
---| 'textDocument/inlayHint'
---| 'textDocument/inlineCompletion'
---| 'textDocument/inlineValue'
---| 'textDocument/linkedEditingRange'
---| 'textDocument/moniker'
---| 'textDocument/onTypeFormatting'
---| 'textDocument/prepareCallHierarchy'
---| 'textDocument/prepareRename'
---| 'textDocument/prepareTypeHierarchy'
---| 'textDocument/rangeFormatting'
---| 'textDocument/rangesFormatting'
---| 'textDocument/references'
---| 'textDocument/rename'
---| 'textDocument/selectionRange'
---| 'textDocument/semanticTokens/full'
---| 'textDocument/semanticTokens/full/delta'
---| 'textDocument/semanticTokens/range'
---| 'textDocument/signatureHelp'
---| 'textDocument/typeDefinition'
---| 'textDocument/willSaveWaitUntil'
---| 'typeHierarchy/subtypes'
---| 'typeHierarchy/supertypes'
---| 'workspaceSymbol/resolve'
---| 'workspace/diagnostic'
---| 'workspace/executeCommand'
---| 'workspace/symbol'
---| 'workspace/textDocumentContent'
---| 'workspace/willCreateFiles'
---| 'workspace/willDeleteFiles'
---| 'workspace/willRenameFiles'

---@class spinner.Config
---@field pattern? string|spinner.Pattern -- Default pattern
---@field ttl_ms? integer -- Default TTL
---@field initial_delay_ms? integer -- Default delay
---@field placeholder? string|boolean -- Default placeholder
---@field hl_group? string
---@field cursor_spinner? spinner.CursorSpinnerConfig -- Default cursor config
---
---@class spinner.CursorSpinnerConfig
---@field hl_group? string -- Default highlight group
---@field winblend? integer -- Default window blend
---@field zindex? integer -- Default z-index
---@field row? integer -- Default row offset 0-based
---@field col? integer -- Default column offset 0-based
```

</details>

# Contributing

Please see [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines on how to contribute to this project.

# Thanks

- [cli-spinners](https://github.com/sindresorhus/cli-spinners) Adopted a lot of spinner patterns from there.
- [panvimdoc](https://github.com/kdheepak/panvimdoc) Use this plugin to generate vim docs.
- [nvim-dap](https://github.com/mfussenegger/nvim-dap) Borrow `splitstr` function used in cmdline command completion.
