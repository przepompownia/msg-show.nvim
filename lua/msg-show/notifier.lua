local api = vim.api
local ns = api.nvim_create_namespace('arctgx.message')

local extmarkOpts = {end_row = 0, end_col = 0, hl_group = 'Normal', hl_eol = true, hl_mode = 'combine'}

local msgBuf
local debugBuf
local msgWin
local historyWin
local historyBuf
local debugWin
local msgId = 0

local priorities = { 1, 2, 3, 4, 5,
  search_count = 6,
}

local uiKindHistoryExclude = {
  search_count = true,
}

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

local function openMsgWin(maxwidth)
  if msgWin and api.nvim_win_is_valid(msgWin) then
    api.nvim_win_set_config(msgWin, {width = maxwidth})
    return
  end

  msgWin = api.nvim_open_win(msgBuf, false, {
    relative = 'editor',
    row = vim.go.lines - 2,
    col = vim.o.columns,
    width = maxwidth,
    height = 10,
    anchor = 'SE',
    style = 'minimal',
    focusable = false,
    zindex = 999,
  })
  vim.wo[msgWin].winblend = 25
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
  vim.wo[historyWin].winblend = 25
end

local function closeWin(winId)
  if not winId then
    return
  end

  if api.nvim_win_is_valid(winId) then
    api.nvim_win_close(winId, true)
  end

  msgWin = nil
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
local defaultOpts = {notify = true, debug = true, duration = 5000}
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

  if height == 0 then
    closeWin(msgWin)
    msgWin = nil
    return
  end

  openMsgWin(maxwidth)
  api.nvim_win_set_config(msgWin, {
    height = (height == 0) and 1 or height
  })
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
  [logLEvels.DEBUG] = 'DebugMsg',
  [logLEvels.INFO] = 'InfoMsg',
  [logLEvels.WARN] = 'WarningMsg',
  [logLEvels.ERROR] = 'ErrorMsg',
}

function M.notify(msg, level)
  local chunkSequence = {{0, msg, notifyLevelHl[level] or 'Normal'}}
  M.addUiMessage(chunkSequence, level)
end

local previous, previousId, previousDuplicated = nil, nil, 0

function M.addUiMessage(chunkSequence, kind)
  if previous == vim.json.encode(chunkSequence) then
    previousDuplicated = previousDuplicated + 1
    chunkSequence[#chunkSequence + 1] = {0, (' (x%d)'):format(previousDuplicated), 'Normal'}
    M.updateUiMessage(previousId, chunkSequence, kind)
    return
  end
  --- @type arctgx.message
  local newItem = {type = 'ui', msg = chunkSequence, removed = false, priority = priorities[kind] or 0, created = vim.uv.hrtime()}

  local id = newId()

  if not uiKindHistoryExclude[kind] then
    msgHistory[id] = newItem
  end
  msgsToDisplay[id] = newItem
  refresh()
  deferRemoval(realOpts.duration, id)

  previous, previousId, previousDuplicated = vim.json.encode(chunkSequence), id, 0

  return id
end

function M.updateUiMessage(id, chunkSequence, kind)
  if msgHistory[id] then
    msgHistory[id].msg = chunkSequence
  end
  if msgsToDisplay[id] then
    msgsToDisplay[id].msg = chunkSequence
  else
    id = M.addUiMessage(chunkSequence, kind)
  end
  refresh()
  deferRemovalAgain(id)

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
  if previousId == id then
    previous, previousId, previousDuplicated = nil, nil, 0
  end
  destroyRemovalTimer(id)
  refresh()
end

local function displayDebugMessages(msg)
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
  api.nvim_buf_set_lines(debugBuf, -1, -1, true, vim.split(msg, '\n'))
end

function M.debug(msg)
  inFastEventWrapper(function ()
    displayDebugMessages(msg)
  end)
end

---@param opts notifier.opts
function M.setup(opts)
  --- @type notifier.opts
  realOpts = vim.tbl_extend('keep', opts or {}, defaultOpts)

  if realOpts.debug then
    debugBuf = api.nvim_create_buf(false, true)
  end

  if realOpts.notify then
    msgBuf = api.nvim_create_buf(false, true)
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
end

return M
