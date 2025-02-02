local api = vim.api
local ns = api.nvim_create_namespace('messageRedirection')

--- @param content [integer, string, integer][][]
--- @param title string?
--- @param history boolean
--- @return integer message ID
---@diagnostic disable-next-line: unused-local
local addChMessage = function (content, title, history)
  error('Not configured yet')
end

--- @param msgId integer
--- @param content [integer, string, integer][][]
--- @param title string?
--- @param history boolean
---@diagnostic disable-next-line: unused-local
local updateChMessage = function (msgId, content, title, history)
  error('Not configured yet')
end

---@diagnostic disable-next-line: unused-local
local debugMessage = function (content)
  error('Not configured yet')
end

local clearPromptMessage = function ()
  error('Not configured yet')
end

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
    addChMessage(content, kind, history)
    return
  end

  replaceableMsgIds[kind] = (replace and msgId)
    and updateChMessage(msgId, content, kind, history)
    or addChMessage(content, kind, history)
end

local function handleUiMessages(event, kind, content, replace, history)
  if showDebugMsgs then
    local dm = ('e: %s, f: %s, k: %s, r: %s, h: %s, c: %s'):format(
      event,
      vim.in_fast_event() and 1 or 0,
      vim.inspect(kind),
      replace,
      history,
      vim.inspect(content)
    )
    if dm ~= previous then
      debugMessage(dm)
      previous = dm
    end
  end

  if event == 'cmdline_hide' then
    clearPromptMessage()
    return
  end

  if event ~= 'msg_show' or kind == 'search_cmd' then
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
  vim.ui_attach(ns, {ext_messages = true, ext_cmdline = false}, handleUiMessages)
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

function M.init(addMsgCb, updateMsgCb, debugMsgCb, clearPromptMsgCb)
  if addChMessage then
    addChMessage = addMsgCb
  end
  if updateChMessage then
    updateChMessage = updateMsgCb
  end
  if debugMsgCb then
    debugMessage = debugMsgCb
  end
  if clearPromptMsgCb then
    clearPromptMessage = clearPromptMsgCb
  end

  api.nvim_create_autocmd('CmdlineEnter', {callback = detach})
  api.nvim_create_autocmd({'CmdlineLeave'}, {callback = attach})
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
