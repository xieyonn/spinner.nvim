local pretty = require("pl.pretty")
local term = require("term")
local isatty = io.type(io.stdout) == "file" and term.isatty(io.stdout)

local colors = require("term.colors")

local old_print = print
local buffer = {}
local out = function(...)
  local args = vim.F.pack_len(...)
  table.insert(buffer, table.concat(args, " ", 1, args.n))
end

if not os.getenv("GITHUB_ACTIONS") and not isatty then
  colors = setmetatable({}, {
    __index = function()
      return function(s)
        return s
      end
    end,
  })
end

local testid = (function()
  local id = 0
  return function()
    id = id + 1
    return id
  end
end)()

local M = {}

function M.time(ms)
  local units = { "ms", "s", "m", "h" }
  local divs = { 1000, 60, 60 }
  local i = 1

  while divs[i] and ms >= divs[i] do
    ms = ms / divs[i]
    i = i + 1
  end

  return string.format("%.2f %s", ms, units[i])
end

--- @param name? 'cirrus'|'github'
--- @return boolean
function M.is_ci(name)
  local any = (name == nil)
  assert(any or name == "github" or name == "cirrus")
  local gh = ((any or name == "github") and nil ~= os.getenv("GITHUB_ACTIONS"))
  local cirrus = ((any or name == "cirrus") and nil ~= os.getenv("CIRRUS_CI"))
  return gh or cirrus
end

-- Gets the (tail) contents of `logfile`.
-- Also moves the file to "${NVIM_LOG_FILE}.displayed" on CI environments.
function M.read_nvim_log(logfile, ci_rename)
  logfile = logfile or os.getenv("NVIM_LOG_FILE") or ".nvimlog"
  local is_ci = M.is_ci()
  local keep = is_ci and 100 or 10
  local lines = M.read_file_list(logfile, -keep) or {}
  local log = (
    ("-"):rep(78)
    .. "\n"
    .. string.format("$NVIM_LOG_FILE: %s\n", logfile)
    .. (#lines > 0 and "(last " .. tostring(keep) .. " lines)\n" or "(empty)\n")
  )
  for _, line in ipairs(lines) do
    log = log .. line .. "\n"
  end
  log = log .. ("-"):rep(78) .. "\n"
  if is_ci and ci_rename then
    os.rename(logfile, logfile .. ".displayed")
  end
  return log
end

--- Reads text lines from `filename` into a table.
--- @param filename string path to file
--- @param start? integer start line (1-indexed), negative means "lines before end" (tail)
--- @return string[]?
function M.read_file_list(filename, start)
  local lnum = (start ~= nil and type(start) == "number") and start or 1
  local tail = (lnum < 0)
  local maxlines = tail and math.abs(lnum) or nil
  local file = io.open(filename, "r")
  if not file then
    return nil
  end

  -- There is no need to read more than the last 2MB of the log file, so seek
  -- to that.
  local file_size = file:seek("end")
  local offset = file_size - 2000000
  if offset < 0 then
    offset = 0
  end
  file:seek("set", offset)

  local lines = {}
  local i = 1
  local line = file:read("*l")
  while line ~= nil do
    if i >= start then
      table.insert(lines, line)
      if #lines > maxlines then
        table.remove(lines, 1)
      end
    end
    i = i + 1
    line = file:read("*l")
  end
  file:close()
  return lines
end

return function(options)
  local busted = require("busted")
  local handler = require("busted.outputHandlers.base")()

  local c = {
    succ = function(s)
      return colors.bright(colors.green(s))
    end,
    skip = function(s)
      return colors.bright(colors.yellow(s))
    end,
    fail = function(s)
      return colors.bright(colors.magenta(s))
    end,
    errr = function(s)
      return colors.bright(colors.red(s))
    end,
    id = function(s)
      return colors.bright(colors.cyan(s))
    end,
    test = tostring,
    file = colors.blue,
    time = colors.dim,
    note = colors.yellow,
    sect = function(s)
      return colors.green(colors.dim(s))
    end,
    nmbr = colors.bright,
  }

  local repeatSuiteString = "\nRepeating all tests (run %d of %d) . . .\n\n"
  local randomizeString =
    c.note("Note: Randomizing test order with a seed of %d.\n")
  local globalSetup = c.sect("--------") .. " Global test environment setup.\n"
  local fileStartString = c.sect("--------")
    .. " Running tests from "
    .. c.file("%s")
    .. "\n"
  local runString = c.sect("RUN     ") .. " " .. c.test("%s") .. ": "
  local successString = c.succ("OK") .. "\n"
  local skippedString = c.skip("SKIP") .. "\n"
  local failureString = c.fail("FAIL") .. "\n"
  local errorString = c.errr("ERR") .. "\n"
  local fileEndString = c.sect("--------")
    .. " "
    .. c.nmbr("%d")
    .. " %s from "
    .. c.file("%s")
    .. " "
    .. c.time("(%s total)")
    .. "\n\n"
  local globalTeardown = c.sect("--------")
    .. " Global test environment teardown.\n"
  local suiteEndString = c.sect("========")
    .. " "
    .. c.nmbr("%d")
    .. " %s from "
    .. c.nmbr("%d")
    .. " test %s ran. "
    .. c.time("(%s total)")
    .. "\n"
  local successStatus = c.succ("PASSED  ") .. " " .. c.nmbr("%d") .. " %s.\n"

  local summaryStrings = {
    skipped = {
      header = c.skip("SKIPPED ")
        .. " "
        .. c.nmbr("%d")
        .. " %s, listed below:\n",
      test = c.skip("SKIPPED ") .. " %s\n",
      footer = " " .. c.nmbr("%d") .. " SKIPPED %s\n",
    },

    failure = {
      header = c.fail("FAILED  ")
        .. " "
        .. c.nmbr("%d")
        .. " %s, listed below:\n",
      test = c.fail("FAILED  ") .. " %s\n",
      footer = " " .. c.nmbr("%d") .. " FAILED %s\n",
    },

    error = {
      header = c.errr("ERROR   ")
        .. " "
        .. c.nmbr("%d")
        .. " %s, listed below:\n",
      test = c.errr("ERROR   ") .. " %s\n",
      footer = " " .. c.nmbr("%d") .. " %s\n",
    },
  }

  local fileCount = 0
  local fileTestCount = 0
  local testCount = 0
  local successCount = 0
  local skippedCount = 0
  local failureCount = 0
  local errorCount = 0

  local pendingDescription = function(pending)
    local string = ""

    if type(pending.message) == "string" then
      string = string .. pending.message .. "\n"
    elseif pending.message ~= nil then
      string = string .. pretty.write(pending.message) .. "\n"
    end

    return string
  end

  local failureDescription = function(failure)
    local string = failure.randomseed
        and ("Random seed: " .. failure.randomseed .. "\n")
      or ""
    if type(failure.message) == "string" then
      string = string .. failure.message
    elseif failure.message == nil then
      string = string .. "Nil error"
    else
      string = string .. pretty.write(failure.message)
    end

    string = string .. "\n"

    if options.verbose and failure.trace and failure.trace.traceback then
      string = string .. failure.trace.traceback .. "\n"
    end

    return string
  end

  local getFileLine = function(element)
    local fileline = ""
    if element.trace or element.trace.short_src then
      fileline = colors.cyan(element.trace.short_src)
        .. " @ "
        .. colors.cyan(element.trace.currentline)
        .. ": "
    end
    return fileline
  end

  local getTestList = function(status, count, list, getDescription)
    local string = ""
    local header = summaryStrings[status].header
    if count > 0 and header then
      local tests = (count == 1 and "test" or "tests")
      local errors = (count == 1 and "error" or "errors")
      string = header:format(count, status == "error" and errors or tests)

      local testString = summaryStrings[status].test
      if testString then
        for _, t in ipairs(list) do
          local fullname = getFileLine(t.element) .. colors.bright(t.name)
          string = string .. testString:format(fullname)
          string = string .. getDescription(t)
        end
      end
    end
    return string
  end

  local getSummary = function(status, count)
    local string = ""
    local footer = summaryStrings[status].footer
    if count > 0 and footer then
      local tests = (count == 1 and "TEST" or "TESTS")
      local errors = (count == 1 and "ERROR" or "ERRORS")
      string = footer:format(count, status == "error" and errors or tests)
    end
    return string
  end

  local getSummaryString = function()
    local tests = (successCount == 1 and "test" or "tests")
    local string = successStatus:format(successCount, tests)

    string = string
      .. getTestList(
        "skipped",
        skippedCount,
        handler.pendings,
        pendingDescription
      )
    string = string
      .. getTestList(
        "failure",
        failureCount,
        handler.failures,
        failureDescription
      )
    string = string
      .. getTestList("error", errorCount, handler.errors, failureDescription)

    string = string
      .. ((skippedCount + failureCount + errorCount) > 0 and "\n" or "")
    string = string .. getSummary("skipped", skippedCount)
    string = string .. getSummary("failure", failureCount)
    string = string .. getSummary("error", errorCount)

    return string
  end

  handler.suiteReset = function()
    fileCount = 0
    fileTestCount = 0
    testCount = 0
    successCount = 0
    skippedCount = 0
    failureCount = 0
    errorCount = 0

    return nil, true
  end

  handler.suiteStart = function(_suite, count, total, randomseed)
    if total > 1 then
      io.write(repeatSuiteString:format(count, total))
    end
    if randomseed then
      io.write(randomizeString:format(randomseed))
    end
    io.write(globalSetup)
    io.flush()

    return nil, true
  end

  local function getElapsedTime(tbl)
    if tbl.duration then
      return M.time(tbl.duration * 1000)
    end
    return "nan"
  end

  handler.suiteEnd = function(suite, _count, _total)
    local elapsedTime = getElapsedTime(suite)
    local tests = (testCount == 1 and "test" or "tests")
    local files = (fileCount == 1 and "file" or "files")
    io.write(globalTeardown)
    io.write(
      suiteEndString:format(testCount, tests, fileCount, files, elapsedTime)
    )
    io.write(getSummaryString())
    -- if failureCount > 0 or errorCount > 0 then
    --   io.write(M.read_nvim_log(nil, true))
    -- end
    io.flush()

    return nil, true
  end

  handler.fileStart = function(file)
    fileTestCount = 0
    io.write(fileStartString:format(vim.fs.normalize(file.name)))
    io.flush()
    return nil, true
  end

  handler.fileEnd = function(file)
    local elapsedTime = getElapsedTime(file)
    local tests = (fileTestCount == 1 and "test" or "tests")
    fileCount = fileCount + 1
    io.write(
      fileEndString:format(
        fileTestCount,
        tests,
        vim.fs.normalize(file.name),
        elapsedTime
      )
    )
    io.flush()
    return nil, true
  end

  handler.testStart = function(element, _parent)
    buffer = {}
    _G.print = out

    local desc = ("%s %s"):format(
      c.id("T" .. testid()),
      handler.getFullName(element)
    )
    io.write(runString:format(desc))
    io.flush()

    return nil, true
  end

  local function write_status(element, str)
    io.write(c.time(getElapsedTime(element)) .. " " .. str)
  end

  handler.testEnd = function(element, _parent, status, _debug)
    _G.print = old_print
    local str

    fileTestCount = fileTestCount + 1
    testCount = testCount + 1
    if status == "success" then
      successCount = successCount + 1
      str = successString
    elseif status == "pending" then
      skippedCount = skippedCount + 1
      str = skippedString
    elseif status == "failure" then
      failureCount = failureCount + 1
      str = failureString
        .. failureDescription(handler.failures[#handler.failures])
    elseif status == "error" then
      errorCount = errorCount + 1
      str = errorString .. failureDescription(handler.errors[#handler.errors])
    else
      str = "unexpected test status! (" .. status .. ")"
    end
    write_status(element, str)

    if #buffer > 0 then
      for _, line in ipairs(buffer) do
        io.write(line .. "\n")
      end
    end

    io.flush()

    return nil, true
  end

  handler.error = function(element, _parent, _message, _debug)
    if element.descriptor ~= "it" then
      write_status(element, failureDescription(handler.errors[#handler.errors]))
      io.flush()
      errorCount = errorCount + 1
    end

    return nil, true
  end

  busted.subscribe({ "suite", "reset" }, handler.suiteReset)
  busted.subscribe({ "suite", "start" }, handler.suiteStart)
  busted.subscribe({ "suite", "end" }, handler.suiteEnd)
  busted.subscribe({ "file", "start" }, handler.fileStart)
  busted.subscribe({ "file", "end" }, handler.fileEnd)
  busted.subscribe(
    { "test", "start" },
    handler.testStart,
    { predicate = handler.cancelOnPending }
  )
  busted.subscribe(
    { "test", "end" },
    handler.testEnd,
    { predicate = handler.cancelOnPending }
  )
  busted.subscribe({ "failure" }, handler.error)
  busted.subscribe({ "error" }, handler.error)

  return handler
end
