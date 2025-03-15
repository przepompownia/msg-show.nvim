local api = vim.api
local cmdbuf = api.nvim_create_buf(false, true)
local windows = require('msg-show.windows')
local notifier = require('msg-show.notifier')
local cmdWinConfig = windows.settings.cmdline
local showDebugMsgs = false
local cmdwin
local promptlen = 0 -- like in Nvim #27855 - probably the only way to keep the value across events
local savedCmdHeight = nil

vim.treesitter.start(cmdbuf, 'vim')

local function saveCmdHeight()
  if nil == savedCmdHeight then
    savedCmdHeight = vim.o.cmdheight
  end
end

local function restoreCmdHeight()
  vim._with({noautocmd = true}, function ()
    vim.o.cmdheight = savedCmdHeight
    savedCmdHeight = nil
  end)
end

--- @param col? integer
--- @param hide? boolean
--- @return integer
local function refresh(row, col, hide)
  cmdwin = windows.open(cmdbuf, cmdwin, cmdWinConfig, {
    cursorRow = row,
    cursorCol = promptlen + (col or 0),
    savedCmdHeight = savedCmdHeight,
    hide = hide,
  })

  return cmdwin
end

local function updateCmdBuffer(linesData, prompt, startRow, endRow)
  local lines = {}
  local cmdText = ''
  for _, lineData in ipairs(linesData) do
    cmdText = ''
    for _, chunkText in ipairs(lineData) do
      cmdText = cmdText .. chunkText[2]
    end
    lines[#lines + 1] = prompt .. cmdText
  end
  api.nvim_buf_set_lines(cmdbuf, startRow, endRow, true, lines)

  local linenr = #api.nvim_buf_get_lines(cmdbuf, 0, -1, false)
  return linenr
end

--- @return integer
local function show(content, pos, firstc, prompt, indent, level)
  if showDebugMsgs then
    local fmt = 'pos: %s, ﬁ: %s, pr: %s, i: %s, l: %s, c: %s'
    notifier.debug((fmt):format(pos, firstc, vim.inspect(prompt), indent, level, vim.inspect(content)), 'CS')
  end
  saveCmdHeight()
  local mergedPrompt = firstc .. prompt .. (' '):rep(indent)
  promptlen = #mergedPrompt
  local linenr = updateCmdBuffer({content}, mergedPrompt, -2, -1)
  return refresh(linenr, pos)
end

local function hide(_abort)
  restoreCmdHeight()
  updateCmdBuffer({{{0, ''}}}, '', -2, -1)
  windows.hide(cmdwin, true)
  return cmdwin
end

local function blockShow(linesData)
  if showDebugMsgs then
    notifier.debug(linesData, 'BS')
  end
  saveCmdHeight()
  local linenr = updateCmdBuffer(linesData, ' ', -2, -2)
  refresh(linenr, 0)
end

local function blockAppend(lineData)
  if showDebugMsgs then
    notifier.debug(lineData, 'BA')
  end
  saveCmdHeight()
  local linenr = updateCmdBuffer({lineData}, ' ', -2, -2)
  refresh(linenr, 0)
end

local function blockHide()
  restoreCmdHeight()
  updateCmdBuffer({}, '', 0, -1)
  windows.hide(cmdwin, true)
  return cmdwin
end

local augroup = api.nvim_create_augroup('arctgx.cmdline', {clear = true})
api.nvim_create_autocmd({'VimResized'}, {group = augroup, callback = function ()
  saveCmdHeight()
  refresh(1, 0, true)
  restoreCmdHeight()
end})
api.nvim_create_autocmd({'TabLeave', 'TabClosed'}, {group = augroup, callback = function ()
  windows.close(cmdwin)
  cmdwin = nil
end})

local function toggleDebugEvents(enable)
  showDebugMsgs = enable
end

return {
  hide = hide,
  show = show,
  refresh = refresh,
  blockShow = blockShow,
  blockAppend = blockAppend,
  blockHide = blockHide,
  pos = function (pos)
    refresh(1, pos)
  end,
  toggleDebugEvents = toggleDebugEvents,
}
