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

local searchId = nil
local previous = ''

local function handleUiMessages(event, kind, content, replace)
  -- local dm = ('ev: %s, k: %s, r: %s, c: %s'):format(event, vim.inspect(kind), replace, vim.inspect(content))
  -- if dm ~= previous then
  --   debugMessage(dm)
  --   previous = dm
  -- end
  if event ~= 'msg_show' then
    return
  end

  if kind == 'return_prompt' then
    api.nvim_input('\r')
  elseif kind == 'search_count' then
    searchId = (replace and searchId) and updateChMessage(searchId, content, kind) or addChMessage(content, kind)
    -- elseif
    --   kind == 'emsg'
    --   or kind == 'echo'
    --   or kind == 'echoerr'
    --   or kind == 'echomsg'
    --   or kind == 'lua_error'
    --   or kind == 'lua_print'
    --   or kind == ''
    -- then
  else
    addChMessage(content, kind)
  end
end

local M = {}

local redirect = true

local function attach()
  if not redirect then
    return
  end
  vim.ui_attach(ns, {ext_messages = true, ext_cmdline = false}, handleUiMessages)
  -- vim.ui_attach(ns, {ext_messages = true, ext_cmdline = false}, vim.schedule_wrap(handleUiMessages))
  -- It causes waiting for <CR> input but debugging with osv works
end

local function detach()
  vim.ui_detach(ns)
  vim.schedule(function ()
    api.nvim__redraw({statusline = true})
  end)
end

api.nvim_create_user_command('MsgRedirToggle', function ()
  redirect = not redirect
  if not redirect then
    detach()
  end
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
