local api = vim.api
local ns = api.nvim_create_namespace('arctgx.msg-show')
local notifier = require('msg-show.notifier')
local cmdline = require('msg-show.cmdline')

local function detach()
  vim.ui_detach(ns)
end

local showDebugMsgs = false
local function jumpToCmdlinePos(pos, _level)
  if showDebugMsgs then
    notifier.debug(('Pos: %s'):format(pos))
  end

  return cmdline.refresh(pos)
end

local function showCmdline(content, pos, firstc, prompt, indent, level, hlId)
  if showDebugMsgs then
    local dm = ('Cmd: f: %s, pos: %s, ﬁ: %s, pr: %s, i: %s, l: %s, hl: %s, c: %s'):format(
      vim.in_fast_event() and 1 or 0,
      pos,
      firstc,
      vim.inspect(prompt),
      indent,
      level,
      hlId,
      vim.inspect(content)
    )
    notifier.debug(dm)
  end

  return cmdline.show(content, pos, firstc, prompt, indent, level)
end

local M = {}

local enable = true

local function attach()
  vim.ui_attach(ns, {ext_messages = true, ext_cmdline = true}, function (event, ...)
    if event == 'msg_show' then
      notifier.msgShow(...)
    elseif event == 'cmdline_hide' then
      cmdline.hide()
      notifier.showDialogMessage()
    elseif event == 'cmdline_pos' then
      jumpToCmdlinePos(...)
    elseif event == 'cmdline_show' then
      showCmdline(...)
    end
  end)
end

api.nvim_create_user_command('MsgShowToggle', function ()
  enable = not enable
  if not enable then
    detach()
    return
  end
  attach()
end, {nargs = 0})

api.nvim_create_user_command('MsgShowToggleDebugEvents', function ()
  showDebugMsgs = not showDebugMsgs
  notifier.toggleDebugEvents(showDebugMsgs)
end, {nargs = 0})

--- @alias arctgx.msg-show.opts {notifier: arctgx.msg-show.notifier.opts}

---@param opts? arctgx.msg-show.opts
function M.setup(opts)
  notifier.setup(opts and opts.notifier)
  api.nvim_create_autocmd({'UIEnter'}, {
    callback = function ()
      local startMessages = vim.trim(api.nvim_exec2('messages', {output = true}).output)
      if #startMessages > 0 then
        displayMessage('echo', {{0, startMessages, 0}})
      end
      attach()
    end
  })
end

function M.history()
  return notifier.showHistory()
end

function M.delayRemoval()
  return notifier.delayRemoval()
end

return M
