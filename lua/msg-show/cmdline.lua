local api = vim.api
local cmdbuf = api.nvim_create_buf(false, true)
local windows = require('msg-show.windows')
local cmdWinConfig = windows.settings.cmdline
local cmdwin
local promptlen = 0 -- like in Nvim #27855 - probably the only way to keep the value across events

local function refresh(pos)
  cmdwin = windows.open(cmdbuf, cmdwin, cmdWinConfig, {cursorPos = promptlen + pos, buf = cmdbuf})
end

local function show(content, pos, firstc, prompt)
  local cmdText = content[1][2] -- todo
  api.nvim_buf_set_lines(cmdbuf, 0, -1, true, {firstc .. prompt .. cmdText})
  promptlen = #prompt
  refresh(firstc:len() + pos)
end

local function hide(_abort)
  vim.schedule(function ()
    windows.hide(cmdwin, true)
  end)
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
}
