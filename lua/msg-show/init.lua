local api = vim.api
local ns = api.nvim_create_namespace('arctgx.msg-show')
local notifier = require('msg-show.notifier')
local cmdline = require('msg-show.cmdline')

local function detach()
  vim.ui_detach(ns)
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
end

local M = {}

local enable = true

local function attach()
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
    elseif event == 'cmdline_block_show' then
      cmdline.blockShow(...)
    elseif event == 'cmdline_block_append' then
      cmdline.blockAppend(...)
    elseif event == 'cmdline_block_hide' then
      cmdline.blockHide()
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

api.nvim_create_user_command('MsgShowToggleDebugUIEvents', function ()
  showDebugMsgs = not showDebugMsgs
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
