local api = vim.api

--- @alias window {config: vim.api.keyset.win_config, options: vim.wo?, after: fun(winId: integer, opts: table?)?}

local function computeWinHeight(win)
  local stlSpace = (vim.o.laststatus > 0) and 1 or 0 -- for ls=1 and single window it can take unnecessary line
  local tabSpace = (vim.o.showtabline == 2 or (vim.o.showtabline == 1 and #vim.api.nvim_list_tabpages() > 1)) and 1 or 0
  local maxHeight = vim.go.lines - stlSpace - tabSpace
  local height = api.nvim_win_text_height(win, {}).all

  return (height > maxHeight) and maxHeight or height
end

local msgWinOpts = {
  maxWidth = 130,
}

local function jumpToLastLine(win)
  vim._with({win = win}, function ()
    vim.cmd.normal({args = {'G'}, mods = {silent = true}})
  end)
end

local function hide(winId, value)
  if not winId or false == api.nvim_win_is_valid(winId) then
    return
  end
  api.nvim_win_set_config(winId, {hide = value})
end

--- @type table<string, window>
local settings = {
  notification = {
    config = {
      relative = 'editor',
      row = vim.go.lines - 1,
      col = vim.o.columns,
      width = 1,
      height = 1,
      anchor = 'SE',
      style = 'minimal',
      focusable = false,
      zindex = 998,
      noautocmd = true,
      border = 'none',
    },
    --- @diagnostic disable-next-line: missing-fields
    options = {
      winblend = 25,
      wrap = true,
      eventignorewin = 'all',
    },
    after = function (winId, opts)
      local width = opts.maxLinesWidth
      if width and width > msgWinOpts.maxWidth then
        width = msgWinOpts.maxWidth
      end
      api.nvim_win_set_config(winId, {
        relative = 'editor',
        row = vim.go.lines - 1 - vim.o.cmdheight,
        col = vim.o.columns,
        width = width,
      })
      api.nvim_win_set_config(winId, {
        height = computeWinHeight(winId),
      })
    end,
  },
  dialog = {
    config = {
      relative = 'editor',
      width = 1,
      height = 1,
      row = vim.go.lines - 3,
      anchor = 'SW',
      col = 0,
      style = 'minimal',
      focusable = false,
      zindex = 999,
    },
    --- @diagnostic disable-next-line: missing-fields
    options = {
      wrap = true,
      eventignorewin = 'all',
    },
    after = function (winId, opts)
      local width = opts.maxLinesWidth
      if width and width > msgWinOpts.maxWidth then
        width = msgWinOpts.maxWidth
      end
      api.nvim_win_set_config(winId, {
        relative = 'editor',
        row = vim.go.lines - 1,
        col = 0,
        width = width,
      })
      api.nvim_win_set_config(winId, {
        height = computeWinHeight(winId),
      })
      api.nvim__redraw({
        flush = true,
        win = winId,
      })
    end,
  },
  history = {
    config = {
      relative = 'editor',
      width = vim.go.columns,
      height = math.floor(math.min(20, vim.go.lines / 2)),
      row = vim.go.lines - 1,
      anchor = 'SE',
      col = 0,
      border = 'single',
      style = 'minimal',
      title = 'Messages',
      title_pos = 'center',
      zindex = 997,
    },
    --- @diagnostic disable-next-line: missing-fields
    options = {
      winblend = 5,
      scrolloff = 0,
    },
    after = function (winId)
      api.nvim_win_set_config(winId, {
        width = vim.go.columns,
        height = math.floor(math.min(20, vim.go.lines / 2)),
        row = vim.go.lines - 1,
        col = vim.o.columns,
        relative = 'editor',
      })
      jumpToLastLine(winId)
    end,
  },
  debug = {
    config = {
      relative = 'editor',
      row = 0,
      col = vim.o.columns,
      width = 120,
      height = 14,
      anchor = 'NE',
      border = 'rounded',
      title_pos = 'center',
      title = ' Debug messages ',
      hide = true,
      style = 'minimal',
    },
    --- @diagnostic disable-next-line: missing-fields
    options = {
      number = true,
      eventignorewin = 'all',
      winblend = 25,
    },
    after = function (winId)
      api.nvim_win_set_config(winId, {
        relative = 'editor',
        row = 0,
        col = vim.o.columns,
        hide = false,
      })
      jumpToLastLine(winId)
    end,
  },
  cmdline = {
    config = {
      zindex = 201,
      focusable = false,
      relative = 'editor',
      row = vim.o.lines,
      col = 0,
      anchor = 'SW',
      height = 1,
      width = vim.o.columns,
      border = 'none',
      noautocmd = true,
      style = 'minimal',
      _cmdline_offset = vim.fn.has('nvim-0.12') == 1 and 0 or nil,
    },
    --- @diagnostic disable-next-line: missing-fields
    options = {
      eventignorewin = 'all',
      virtualedit = 'onemore',
    },
    after = function (winId, opts)
      local height = math.max(api.nvim_win_text_height(winId, {}).all, opts.savedCmdHeight)
      api.nvim_win_set_cursor(winId, {opts.cursorRow or 1, opts.cursorCol or 0})
      api.nvim_win_set_config(winId, {
        height = height,
        hide = opts.hide or false,
        relative = 'editor',
        row = vim.o.lines,
        col = 0,
        anchor = 'SW',
      })
      if not opts.hide then
        vim._with({noautocmd = true}, function ()
          vim.o.cmdheight = height
        end)
        api.nvim__redraw({
          flush = true,
          cursor = true,
          win = winId,
        })
      end
    end
  },
}

--- @param winId integer
--- @param options vim.wo
local function applyOptions(winId, options)
  for option, value in pairs(options or {}) do
    vim.wo[winId][option] = value
  end
end

--- @param winId integer
local function close(winId)
  if not winId then
    return
  end

  if api.nvim_win_is_valid(winId) then
    api.nvim_win_close(winId, true)
  end
end

--- @param buf integer
--- @param winId integer
--- @param winConfig window
--- @param opts table?
--- @return integer
local function open(buf, winId, winConfig, opts)
  if not winId or not api.nvim_win_is_valid(winId) then
    winId = api.nvim_open_win(buf, opts and opts.focus or false, winConfig.config)
    if opts and opts.ns then
      api.nvim_win_set_hl_ns(winId, opts.ns)
    end
    applyOptions(winId, winConfig.options)
  end
  if type(winConfig.after) == 'function' then
    winConfig.after(winId, opts or {})
  end

  return winId
end

return {
  hide = hide,
  close = close,
  open = open,
  settings = settings,
}
