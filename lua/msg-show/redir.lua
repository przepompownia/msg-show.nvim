local api = vim.api
local ns = api.nvim_create_namespace('messageRedirection')

--- @param content [integer, string, integer][][]
--- @param title string?
--- @return integer message ID
local addChMessage = function (content, title)
  error('Not configured yet')
end

--- @param content [integer, string, integer][][]
--- @param title string?
local updateChMessage = function (msgId, content, title)
  error('Not configured yet')
end

local debugMessage = function (content)
  error('Not configured yet')
end

local function detach()
  api.nvim__redraw({flush = true})
  vim.ui_detach(ns)
  api.nvim__redraw({flush = true})
end

local showDebugMsgs = false
local searchId = nil
local writeId = nil
local previous = ''

local qMsgs = {}

local function displayMessage(kind, content, replace)
  if kind == 'search_count' then
    searchId = (replace and searchId) and updateChMessage(searchId, content, kind) or addChMessage(content, kind)
  elseif kind == 'bufwrite' then
    writeId = (replace and writeId) and updateChMessage(writeId, content, kind) or addChMessage(content, kind)
  else
    addChMessage(content, kind)
  end
end

local function consumeMsgs()
  for _, qmsg in ipairs(qMsgs) do
    displayMessage(qmsg[1], qmsg[2], qmsg[3])
  end
  qMsgs = {}
end

local function handleUiMessages(event, kind, content, replace)
  if showDebugMsgs then
    local dm = ('e: %s, f: %s, k: %s, r: %s, c: %s'):format(
      event,
      vim.in_fast_event() and 1 or 0,
      vim.inspect(kind),
      replace,
      vim.inspect(content)
    )
    if dm ~= previous then
      debugMessage(dm)
      previous = dm
    end
  end

  if event ~= 'msg_show' or kind == 'search_cmd' then
    return
  end

  if kind == 'return_prompt' then
    api.nvim_input('\r')
    return
  end

  if not vim.in_fast_event() then
    consumeMsgs()
    displayMessage(kind, content, replace)
    return
  end

  qMsgs[#qMsgs + 1] = {kind, content, replace}

  vim.schedule(function ()
    consumeMsgs()
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

function M.init(addMsgCb, updateMsgCb, debugMsgCb)
  if addChMessage then
    addChMessage = addMsgCb
  end
  if updateChMessage then
    updateChMessage = updateMsgCb
  end
  if debugMsgCb then
    debugMessage = debugMsgCb
  end

  api.nvim_create_autocmd('CmdlineEnter', {callback = detach})
  api.nvim_create_autocmd({'UIEnter', 'CmdlineLeave'}, {callback = attach})
end

return M
