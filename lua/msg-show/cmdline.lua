local api = vim.api
local cmdbuf = api.nvim_create_buf(false, true)
local windows = require('msg-show.windows')
local cmdWinConfig = windows.settings.cmdline
local cmdwin
local promptlen = 0 -- like in Nvim #27855 - probably the only way to keep the value across events
local savedCmdHeight = 0

vim.treesitter.start(cmdbuf, 'vim')

--- @param pos? integer
--- @return integer
local function refresh(pos)
  cmdwin = windows.open(cmdbuf, cmdwin, cmdWinConfig, {cursorPos = promptlen + (pos or 0)})

  return cmdwin
end

--- @return integer
local function show(content, pos, firstc, prompt, indent, _level)
  local cmdText = content[1][2] -- todo
  local mergedPrompt = firstc .. prompt .. (' '):rep(indent or 0)
  api.nvim_buf_set_lines(cmdbuf, 0, -1, true, {mergedPrompt .. cmdText})
  promptlen = #mergedPrompt
  return refresh(pos)
end

local function hide(_abort)
  vim._with({noautocmd = true}, function ()
    vim.o.cmdheight = savedCmdHeight
  end)
  api.nvim_buf_set_lines(cmdbuf, 0, -1, true, {})
  windows.hide(cmdwin, true)
  return cmdwin
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
