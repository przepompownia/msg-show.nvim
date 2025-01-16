local api = vim.api
local ns = api.nvim_create_namespace('arctgx.message')
local defaultHl = 'Comment'

local extmarkOpts = {end_row = 0, end_col = 0, hl_group = defaultHl, hl_eol = true, hl_mode = 'combine'}

local msgBuf
local debugBuf
local msgWin
local msgWinOpts = {
  maxWidth = 130,
}
local historyWin
local historyBuf
local debugWin
local msgId = 0
local verbosity = vim.go.verbose

local priorities = { 1, 2, 3, 4, 5,
  search_count = 6,
  progress = 7,
}

local uiKindHistoryInclude = {
  echo = true,
  list_cmd = true,
  verbose = true,
}

local msgWinHlMap = {
  Normal = defaultHl,
  Search = defaultHl,
}

local msgWinHl = vim.iter(msgWinHlMap):map(function (k, v) return ('%s:%s'):format(k, v) end):join(',')

local nvimBuiltinProgressHandler = vim.lsp.handlers['$/progress']

local M = {}

--- @alias arctgx.message {type: 'ui'|'notification', msg: table<integer, string, integer>[], priority: integer, created: integer, removed: boolean}

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

local function jumpToLastLine(win)
  vim._with({win = win}, function ()
    vim.cmd.normal({args = {'G'}, mods = {silent = true}})
  end)
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

local function computeWinHeight(win)
  local maxHeight = vim.go.lines - 2 -- todo: respect tabpage and stl (non)existence
  local height = api.nvim_win_text_height(win, {}).all

  return (height > maxHeight) and maxHeight or height
end

local function openMsgWin(maxLinesWidth)
  local savedEventIgnore = vim.go.eventignore
  vim.go.eventignore = 'all'
  local width = maxLinesWidth
  if width > msgWinOpts.maxWidth then
    width = msgWinOpts.maxWidth
  end
  if not msgWin or not api.nvim_win_is_valid(msgWin) then
    msgWin = api.nvim_open_win(msgBuf, false, {
      relative = 'editor',
      row = vim.go.lines - 1,
      col = vim.o.columns,
      width = width,
      height = 1,
      anchor = 'SE',
      style = 'minimal',
      focusable = false,
      zindex = 999,
      noautocmd = true,
    })
    vim.wo[msgWin].winblend = 25
    vim.wo[msgWin].winhl = msgWinHl
    vim.wo[msgWin].wrap = true
  end

  api.nvim_win_set_config(msgWin, {
    width = width,
  })
  api.nvim_win_set_config(msgWin, {
    height = computeWinHeight(msgWin),
  })
  vim.go.eventignore = savedEventIgnore
end

local function openHistoryWin()
  if historyWin and api.nvim_win_is_valid(historyWin) then
    return
  end

  historyWin = vim.api.nvim_open_win(historyBuf, true, {
    relative = 'editor',
    width = vim.go.columns,
    height = math.floor(math.min(20, vim.go.lines / 2)),
    anchor = 'SE',
    row = vim.go.lines - 1,
    col = 0,
    border = 'single',
    style = 'minimal',
    title = 'Messages',
    title_pos = 'center',
    zindex = 998,
  })
  vim.wo[historyWin].winblend = 5
  jumpToLastLine(historyWin)
end

local function closeWin(winId)
  if not winId then
    return
  end

  if api.nvim_win_is_valid(winId) then
    local savedEventIgnore = vim.go.eventignore
    vim.go.eventignore = 'all'
    api.nvim_win_close(winId, true)
    vim.go.eventignore = savedEventIgnore
  end
end

--- @type uv.uv_timer_t[]
local removal_timers = {}

local function destroyRemovalTimer(id)
  local timer = removal_timers[id]
  if not timer then
    return
  end

  timer:stop()
  timer:close()
  removal_timers[id] = nil
end

local function deferRemoval(duration, id)
  local timer = assert(vim.uv.new_timer())
  timer:start(duration, duration, function ()
    M.remove(id)
  end)
  removal_timers[id] = timer
end

local function deferRemovalAgain(id)
  local timer = removal_timers[id]
  if not timer then
    return
  end
  timer:again()
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
local function displayNotifications(items)
  local buf = msgBuf
  local lineNr, maxwidth = loadItemsToBuf(items, buf)
  local height = (lineNr < vim.o.lines - 3) and lineNr or vim.o.lines - 3

  if height == 0 or maxwidth == 0 then
    closeWin(msgWin)
    msgWin = nil
    return
  end

  local savedEventIgnore = vim.go.eventignore
  vim.go.eventignore = 'all'
  openMsgWin(maxwidth)
  vim.go.eventignore = savedEventIgnore
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
    displayNotifications(msglist)
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
    openHistoryWin()
  end)
end

function M.remove(id)
  if msgHistory[id] then msgHistory[id].removed = true end
  msgsToDisplay[id] = nil
  destroyRemovalTimer(id)
  refresh()
end

local function displayDebugMessages(msg)
  local savedEventIgnore = vim.go.eventignore
  vim.go.eventignore = 'all'
  if not debugWin or not api.nvim_win_is_valid(debugWin) then
    debugWin = api.nvim_open_win(debugBuf, false, {
      relative = 'editor',
      row = 0,
      col = vim.o.columns,
      width = 120,
      height = 14,
      anchor = 'NE',
      border = 'rounded',
      title_pos = 'center',
      title = ' unhandled messages ',
      hide = true,
      style = 'minimal',
    })
    vim.wo[debugWin].winblend = 25
    vim.wo[debugWin].number = true
  end
  api.nvim_win_set_config(debugWin, {hide = false})
  api.nvim_buf_set_lines(debugBuf, -1, -1, true, vim.split(vim.inspect(msg), '\n'))
  jumpToLastLine(debugWin)
  vim.go.eventignore = savedEventIgnore
end

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

  if realOpts.lspProgress then
    vim.lsp.handlers['$/progress'] = lspProgressHandler
  end

  historyBuf = api.nvim_create_buf(false, true)
  -- vim.bo[historyBuf].modifiable = false

  local augroup = api.nvim_create_augroup('arctgx.msg', {clear = true})
  api.nvim_create_autocmd({'TabEnter', 'VimResized'}, {
    group = augroup,
    callback = refresh,
  })
  api.nvim_create_autocmd({'TabLeave', 'TabClosed'}, {
    group = augroup,
    callback = function ()
      closeWin(msgWin)
      msgWin = nil
    end,
  })
  api.nvim_create_autocmd({'OptionSet'}, {
    group = augroup,
    pattern = 'verbose',
    callback = function (ev)
      verbosity = vim.v.option_new
    end,
  })
end

return M
