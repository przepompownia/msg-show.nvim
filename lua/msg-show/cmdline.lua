local api = vim.api
local cmdbuf = api.nvim_create_buf(false, true)
local windows = require('msg-show.windows')
local cmdWinConfig = windows.settings.cmdline
local cmdwin
local promptlen = 0 -- like in Nvim #27855 - probably the only way to keep the value across events
local savedCmdHeight = 0

vim.treesitter.start(cmdbuf, 'vim')

--- @param col? integer
--- @return integer
local function refresh(row, col)
  cmdwin = windows.open(cmdbuf, cmdwin, cmdWinConfig, {cursorRow = row, cursorCol = promptlen + (col or 0)})

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

  return #lines
end

--- @return integer
local function show(content, pos, firstc, prompt, indent, _level)
  local mergedPrompt = firstc .. prompt .. (' '):rep(indent)
  promptlen = #mergedPrompt
  local linenr = updateCmdBuffer({content}, mergedPrompt, -2, -1)
  return refresh(linenr, pos)
end

local function hide(_abort)
  vim._with({noautocmd = true}, function ()
    vim.o.cmdheight = savedCmdHeight
  end)
  api.nvim_buf_set_lines(cmdbuf, 0, -1, true, {})
  windows.hide(cmdwin, true)
  return cmdwin
end

local function blockShow(linesData)
  local linenr = updateCmdBuffer(linesData, '>', -2, -2)
  refresh(linenr)
end

local function blockAppend(lineData)
  local linenr = updateCmdBuffer({lineData}, '>', -2, -1)
  refresh(linenr)
end

local function blockHide()
  hide()
end

local augroup = api.nvim_create_augroup('arctgx.cmdline', {clear = true})
api.nvim_create_autocmd({'VimResized'}, {group = augroup, callback = function ()
  refresh()
end})
api.nvim_create_autocmd({'TabLeave', 'TabClosed'}, {group = augroup, callback = function ()
  windows.close(cmdwin)
  cmdwin = nil
end})

return {
  hide = hide,
  show = show,
  refresh = refresh,
  blockShow = blockShow,
  blockAppend = blockAppend,
  blockHide = blockHide,
}
