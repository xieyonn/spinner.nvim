local lsp = require("spinner.event.lsp")

---@class spinner.Event
---@field lsp? spinner.Event.Lsp
---
---@class spinner.Event.Lsp
---@field client_names? string[]
---@field progress? boolean
---@field request? spinner.LspRequest[]
---
---@alias spinner.LspRequest
---| 'callHierarchy/incomingCalls',
---| 'callHierarchy/outgoingCalls',
---| 'codeAction/resolve',
---| 'codeLens/resolve',
---| 'completionItem/resolve',
---| 'documentLink/resolve',
---| 'initialize',
---| 'inlayHint/resolve',
---| 'shutdown',
---| 'textDocument/codeAction',
---| 'textDocument/codeLens',
---| 'textDocument/colorPresentation',
---| 'textDocument/completion',
---| 'textDocument/declaration',
---| 'textDocument/definition',
---| 'textDocument/diagnostic',
---| 'textDocument/documentColor',
---| 'textDocument/documentHighlight',
---| 'textDocument/documentLink',
---| 'textDocument/documentSymbol',
---| 'textDocument/foldingRange',
---| 'textDocument/formatting',
---| 'textDocument/hover',
---| 'textDocument/implementation',
---| 'textDocument/inlayHint',
---| 'textDocument/inlineCompletion',
---| 'textDocument/inlineValue',
---| 'textDocument/linkedEditingRange',
---| 'textDocument/moniker',
---| 'textDocument/onTypeFormatting',
---| 'textDocument/prepareCallHierarchy',
---| 'textDocument/prepareRename',
---| 'textDocument/prepareTypeHierarchy',
---| 'textDocument/rangeFormatting',
---| 'textDocument/rangesFormatting',
---| 'textDocument/references',
---| 'textDocument/rename',
---| 'textDocument/selectionRange',
---| 'textDocument/semanticTokens/full',
---| 'textDocument/semanticTokens/full/delta',
---| 'textDocument/semanticTokens/range',
---| 'textDocument/signatureHelp',
---| 'textDocument/typeDefinition',
---| 'textDocument/willSaveWaitUntil',
---| 'typeHierarchy/subtypes',
---| 'typeHierarchy/supertypes',
---| 'workspaceSymbol/resolve',
---| 'workspace/diagnostic',
---| 'workspace/executeCommand',
---| 'workspace/symbol',
---| 'workspace/textDocumentContent',
---| 'workspace/willCreateFiles',
---| 'workspace/willDeleteFiles',
---| 'workspace/willRenameFiles',

---@class spinner.event
local M = {}

---Attach spinner to event.
---@param id string
---@param event spinner.Event
function M.attach(id, event)
  if event.lsp then
    if event.lsp.progress == true then
      lsp.progress(id, event.lsp.client_names)
    end

    if event.lsp.request then
      lsp.request(id, event.lsp.request, event.lsp.client_names)
    end
  end
end

return M
