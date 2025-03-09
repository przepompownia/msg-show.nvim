local api = vim.api
local cmdbuf = api.nvim_create_buf(false, true)
local windows = require('msg-show.windows')
local cmdWinConfig = windows.settings.cmdline
local cmdwin

local function refresh(pos)
  cmdwin = windows.open(cmdbuf, cmdwin, cmdWinConfig, {cursorPos = pos})
end

local function show(content, pos, firstc)
  local cmdText = content[1][2] -- todo
  api.nvim_buf_set_lines(cmdbuf, 0, -1, true, {firstc .. cmdText})
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
