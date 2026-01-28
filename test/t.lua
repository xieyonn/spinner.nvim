local assert = require("luassert")

local M = {}

function M.eq(expected, actual, context)
  return assert.are.same(expected, actual, context)
end

function M.neq(expected, actual, context)
  return assert.are_not.same(expected, actual, context)
end

return M
