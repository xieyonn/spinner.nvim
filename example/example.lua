--- show spinner in statusline/tabline
_G.sp = require("spinner").StatuslineSpinner:new()
vim.o.statusline = vim.o.statusline .. "%{v:lua.tostring(sp)}"
vim.o.tabline = vim.o.tabline .. "%{v:lua.tostring(sp)}"

sp:start()
sp:stop()

-- show spinner next to cursor
local sp = require("spinner").CursorSpinner:new()
sp:start()
sp:stop()
