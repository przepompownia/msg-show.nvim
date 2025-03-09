local api = vim.api
local ns = api.nvim_create_namespace('arctgx.msg-show')
local notifier = require('msg-show.notifier')
local cmdline = require('msg-show.cmdline')

local function detach()
  api.nvim__redraw({flush = true})
  vim.ui_detach(ns)
  vim.schedule(function ()
    api.nvim__redraw({flush = true})
  end)
end

local showDebugMsgs = false
local previous = ''

--- @type table<string, false|integer>
local replaceableMsgIds = {
  search_count = false,
  bufwrite = false,
  undo = false,
  completion = false,
}

local function displayMessage(kind, content, replace, history)
  local msgId = replaceableMsgIds[kind]
  if nil == msgId then
    notifier.addUiMessage(content, kind, history)
    return
  end

  replaceableMsgIds[kind] = (replace and msgId)
    and notifier.updateUiMessage(msgId, content, kind, history)
    or notifier.addUiMessage(content, kind, history)
end

local function jumpToCmdlinePos(pos, _level)
  if showDebugMsgs then
    notifier.debug(('Pos: %s'):format(pos))
  end

  cmdline.refresh(pos)
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

  cmdline.show(content, pos, firstc, prompt)
end

local function handleMessages(kind, content, replace, history)
  if showDebugMsgs then
    local dm = ('Msg: f: %s, k: %s, r: %s, h: %s, c: %s'):format(
      vim.in_fast_event() and 1 or 0,
      vim.inspect(kind),
      replace,
      history,
      vim.inspect(content)
    )
    if dm ~= previous then
      notifier.debug(dm)
      previous = dm
    end
  end

  if kind == 'confirm' then
    notifier.showDialogMessage(content)
    return
  end

  if kind == 'search_cmd' then
    return
  end

  if kind == '' and #content == 1 and content[1][2] == '\n' then
    return
  end

  if kind == 'return_prompt' then
    api.nvim_input('\r')
    return
  end

  displayMessage(kind, content, replace, history)
  vim.schedule(function ()
    api.nvim__redraw({flush = true})
  end)
end

local M = {}

local redirect = true

local function attach()
  if not redirect then
    return
  end
  api.nvim__redraw({flush = true})
  vim.ui_attach(ns, {ext_messages = true, ext_cmdline = true}, function (event, ...)
    if event == 'msg_show' then
      handleMessages(...)
    elseif event == 'cmdline_hide' then
      cmdline.hide()
      notifier.showDialogMessage()
    elseif event == 'cmdline_pos' then
      jumpToCmdlinePos(...)
    elseif event == 'cmdline_show' then
      showCmdline(...)
    end
  end)
  api.nvim__redraw({flush = true})
end

api.nvim_create_user_command('MsgRedirToggle', function ()
  redirect = not redirect
  if not redirect then
    detach()
  end
end, {nargs = 0})

api.nvim_create_user_command('MsgRedirToggleDebugUIEvents', function ()
  showDebugMsgs = not showDebugMsgs
end, {nargs = 0})

function M.init()
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

return M
