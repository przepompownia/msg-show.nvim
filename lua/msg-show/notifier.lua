local api = vim.api
local ns = api.nvim_create_namespace('arctgx.message')
local windows = require('msg-show.windows')
local defaultHl = windows.defaultHl

--- @alias arctgx.message {type: 'ui'|'notification', msg: table<integer, string, integer>[], priority: integer, created: integer, removed: boolean}

--- @type vim.api.keyset.set_extmark
local extmarkOpts = {
  end_row = 0,
  end_col = 0,
  hl_group = defaultHl,
  hl_eol = true,
  hl_mode = 'combine',
  invalidate = true,
  undo_restore = false,
}

--- @type arctgx.message?
local dialogMessage
local msgBuf
local dialogBuf
local debugBuf
local msgWin
local dialogWin
local historyWin
local historyBuf
local debugWin
local msgId = 0
local verbosity = vim.go.verbose

local msgWinConfig = windows.settings.notification
local dialogWinConfig = windows.settings.dialog
local historyWinConfig = windows.settings.history
local debugWinConfig = windows.settings.debug

local priorities = { 1, 2, 3, 4, 5,
  search_count = 6,
  progress = 7,
}

local uiKindHistoryInclude = {
  echo = true,
  list_cmd = true,
  verbose = true,
}

local nvimBuiltinProgressHandler = vim.lsp.handlers['$/progress']

local M = {}

--- @type arctgx.message[]
local msgHistory = {}

--- @type arctgx.message[]
local msgsToDisplay = {}

--- @param item arctgx.message
--- @param lines string[]
--- @param highlights table
--- @return integer, integer
local function composeSingleItem(item, lines, highlights, startLine)
  local line, col, newCol, msg, hlId, maxwidth = startLine, 0, 0, nil, nil, 0

  for _, chunk in ipairs(item.msg) do
    hlId = chunk[3]
    msg = vim.split(chunk[2], '\n')
    for index, msgpart in ipairs(msg) do
      if index > 1 then
        line, col = line + 1, 0
      end
      newCol = col + #msgpart
      lines[line + 1] = (lines[line + 1] or '') .. msgpart
      if #lines[line + 1] > maxwidth then
        maxwidth = #lines[line + 1]
      end
      highlights[#highlights + 1] = {line, col, newCol, hlId}
      col = newCol
    end
  end

  return line + 1, maxwidth
end

--- @param items arctgx.message[]
local function composeLines(items)
  local line, lines, highlights, maxwidth, width = 0, {}, {}, 0, 0

  for _, item in pairs(items) do
    line, width = composeSingleItem(item, lines, highlights, line)
    if width > maxwidth then
      maxwidth = width
    end
  end

  return lines, highlights, maxwidth
end

--- @type uv.uv_timer_t[]
local removalTimers = {}

local function destroyRemovalTimer(id)
  local timer = removalTimers[id]
  if not timer then
    return
  end

  timer:stop()
  timer:close()
  removalTimers[id] = nil
end

local function deferRemoval(duration, id)
  local timer = assert(vim.uv.new_timer())
  timer:start(duration, duration, function ()
    M.remove(id)
  end)
  removalTimers[id] = timer
end

local function deferRemovalAgain(id)
  local timer = removalTimers[id]
  if not timer then
    return
  end
  timer:again()
end

local function deferAllTimers()
  for _, timer in pairs(removalTimers) do
    timer:again()
  end
end

--- @class notifier.opts
local defaultOpts = {
  notify = true,
  debug = true,
  lspProgress = true,
  duration = 5000,
  msgWin = {
    maxWidth = 130,
  },
}
--- @class notifier.opts?
local realOpts

local function loadItemsToBuf(items, buf)
  local lines, highlights, maxwidth = composeLines(items)

  api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  api.nvim_buf_set_lines(buf, 0, -1, true, lines)
  for _, highlight in ipairs(highlights) do
    extmarkOpts.end_row, extmarkOpts.end_col, extmarkOpts.hl_group = highlight[1], highlight[3], highlight[4]
    api.nvim_buf_set_extmark(buf, ns, highlight[1], highlight[2], extmarkOpts)
  end

  return #lines, maxwidth
end

--- @param items arctgx.message[]
--- @param buf integer
local function displayNotifications(items, buf, win, winConfig)
  local lineNr, maxwidth = loadItemsToBuf(items, buf)
  local height = (lineNr < vim.o.lines - 3) and lineNr or vim.o.lines - 3

  if height == 0 or maxwidth == 0 then
    windows.close(win)
    return
  end

  return windows.open(buf, win, winConfig, {maxLinesWidth = maxwidth})
end

local function inFastEventWrapper(cb)
  if vim.in_fast_event() then
    vim.schedule(cb)
    return
  end
  cb()
end

local function refresh()
  local msglist = vim.tbl_values(msgsToDisplay)
  table.sort(msglist, function (a, b)
    if a.priority ~= b.priority then
      return a.priority < b.priority
    end
    return a.created < b.created
  end)
  inFastEventWrapper(function ()
    msgWin = displayNotifications(msglist, msgBuf, msgWin, msgWinConfig)
  end)
end

local function newId()
  msgId = msgId + 1
  return msgId
end

local logLEvels = vim.log.levels
local notifyLevelHl = {
  [logLEvels.DEBUG] = defaultHl,
  [logLEvels.INFO] = defaultHl,
  [logLEvels.WARN] = 'WarningMsg',
  [logLEvels.ERROR] = 'ErrorMsg',
}

local function toChunk(msg, level)
  return {{0, msg, notifyLevelHl[level] or defaultHl}}
end

local previous, previousId, previousDuplicated = nil, nil, 1

function M.addUiMessage(chunkSequence, kind, history)
  if previous == vim.json.encode(chunkSequence) then
    previousDuplicated = previousDuplicated + 1
    chunkSequence[#chunkSequence + 1] = {0, (' (x%d)'):format(previousDuplicated), defaultHl}
    return M.updateUiMessage(previousId, chunkSequence, kind)
  end
  --- @type arctgx.message
  local newItem = {type = 'ui', msg = chunkSequence, removed = false, priority = priorities[kind] or 0, created = vim.uv.hrtime()}

  local id = newId()

  if uiKindHistoryInclude[kind] or history then
    msgHistory[id] = newItem
  end

  if verbosity > 7 and kind == 'verbose' then
    return id
  end

  msgsToDisplay[id] = newItem
  refresh()

  deferRemoval(realOpts.duration, id)

  previous, previousId, previousDuplicated = vim.json.encode(chunkSequence), id, 1

  return id
end

function M.showDialogMessage(chunkSequence)
  if nil == dialogMessage and nil == chunkSequence then
    return
  end
  dialogMessage = chunkSequence and {msg = chunkSequence} or nil
  inFastEventWrapper(function ()
    dialogWin = displayNotifications({dialogMessage}, dialogBuf, dialogWin, dialogWinConfig)
  end)
end

function M.updateUiMessage(id, chunkSequence, kind, history)
  if msgHistory[id] then
    msgHistory[id].msg = chunkSequence
  end
  if not msgsToDisplay[id] then
    return M.addUiMessage(chunkSequence, kind, history)
  end

  msgsToDisplay[id].msg = chunkSequence
  deferRemovalAgain(id)
  refresh()

  return id
end

function M.showHistory()
  inFastEventWrapper(function ()
    loadItemsToBuf(msgHistory, historyBuf)
    historyWin = windows.open(historyBuf, historyWin, historyWinConfig)
  end)
end

function M.remove(id)
  if msgHistory[id] then msgHistory[id].removed = true end
  msgsToDisplay[id] = nil
  destroyRemovalTimer(id)
  refresh()
end

local function displayDebugMessages(msg)
  api.nvim_buf_set_lines(debugBuf, -1, -1, true, vim.split(vim.inspect(msg), '\n'))
  debugWin = windows.open(debugBuf, debugWin, debugWinConfig)
end

M.delayRemoval = deferAllTimers

local prog = {}

local function displayProgMsg(clientId, progId, report)
  local client = assert(vim.lsp.get_clients({id = clientId})[1])

  local progData = prog[progId] or {}
  local isEnd = report.kind == 'end'

  local percentage = report.percentage and (' [%s%%]'):format(report.percentage) or ''
  local msg = ('%s: %s%s'):format(client.name or clientId, report.message or (isEnd and 'finished' or '-'), percentage)
  local chunks = toChunk(msg, vim.log.levels.INFO)
  if nil == progData.notificationId then
    progData.notificationId = M.addUiMessage(chunks, 'progress')
  else
    progData.notificationId = M.updateUiMessage(progData.notificationId, chunks, 'progress')
  end

  return not isEnd and progData or nil
end

local function lspProgressHandler(err, result, ctx, config)
  nvimBuiltinProgressHandler(err, result, ctx, config)

  if nil ~= err then
    return M.notify(vim.inspect(err), vim.log.levels.ERROR)
  end

  local progId = ('%s-%s'):format(ctx.client_id, result.token)

  prog[progId] = displayProgMsg(ctx.client_id, progId, result.value)
end

function M.debug(msg)
  inFastEventWrapper(function ()
    displayDebugMessages(msg)
  end)
end

---@param opts notifier.opts?
function M.setup(opts)
  --- @type notifier.opts
  realOpts = vim.tbl_extend('keep', opts or {}, defaultOpts)

  if realOpts.debug then
    debugBuf = api.nvim_create_buf(false, true)
  end

  if realOpts.notify then
    msgBuf = api.nvim_create_buf(false, true)
  end

  dialogBuf = api.nvim_create_buf(false, true)

  if realOpts.lspProgress then
    vim.lsp.handlers['$/progress'] = lspProgressHandler
  end

  historyBuf = api.nvim_create_buf(false, true)
  -- vim.bo[historyBuf].modifiable = false

  local augroup = api.nvim_create_augroup('arctgx.msg', {clear = true})
  api.nvim_create_autocmd({'TabEnter', 'VimResized'}, {group = augroup, callback = refresh})
  api.nvim_create_autocmd({'TabLeave', 'TabClosed'}, {group = augroup, callback = function ()
    windows.close(msgWin)
    msgWin = nil
  end})
  api.nvim_create_autocmd({'OptionSet'}, {
    group = augroup,
    pattern = 'verbose',
    callback = function () verbosity = vim.v.option_new end,
  })
end

return M
