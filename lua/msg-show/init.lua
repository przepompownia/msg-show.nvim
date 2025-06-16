local api = vim.api
local ns = api.nvim_create_namespace('arctgx.msg-show')
local notifier = require('msg-show.notifier')
local cmdline = require('msg-show.cmdline')
local showDebugMsgs = false
local enable = true

local M = {}

local function attachCb(event, ...)
  if event == 'msg_show' then
    notifier.msgShow(...)
  elseif event == 'cmdline_hide' then
    cmdline.hide()
    notifier.showDialogMessage()
  elseif event == 'cmdline_pos' then
    cmdline.pos(...)
  elseif event == 'cmdline_show' then
    cmdline.show(...)
  elseif event == 'cmdline_block_show' then
    cmdline.blockShow(...)
  elseif event == 'cmdline_block_append' then
    cmdline.blockAppend(...)
  elseif event == 'cmdline_block_hide' then
    cmdline.blockHide()
  end
end

local function reportError(err)
  notifier.debug(debug.traceback(err), 'AT')
end

local function attach()
  vim.ui_attach(ns, {
    ext_messages = true,
    ext_cmdline = true,
    set_cmdheight = vim.fn.has('nvim-0.12') == 1 or nil,
  }, function (event, ...)
    if showDebugMsgs then
      xpcall(attachCb, reportError, event, ...)
      return
    end
    attachCb(event, ...)
  end)
end

api.nvim_create_user_command('MsgShowToggle', function ()
  enable = not enable
  if not enable then
    vim.ui_detach(ns)
    return
  end
  attach()
end, {nargs = 0})

api.nvim_create_user_command('MsgShowToggleDebugEvents', function ()
  showDebugMsgs = not showDebugMsgs
  notifier.toggleDebugEvents(showDebugMsgs)
  cmdline.toggleDebugEvents(showDebugMsgs)
end, {nargs = 0})

--- @alias arctgx.msg-show.opts {notifier: arctgx.msg-show.notifier.opts}

---@param opts? arctgx.msg-show.opts
function M.setup(opts)
  notifier.setup(opts and opts.notifier)
  notifier.displayInitMessages()
  attach()
end

function M.history()
  return notifier.showHistory()
end

function M.delayRemoval()
  return notifier.delayRemoval()
end

return M
