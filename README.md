# msg-show.nvim
Render UI messages out of the cmdline area (preserving highlights). It started as a reproduction for some Nvim issue. I hope it becomes redundant in favor of a built-in alternative (probably https://github.com/neovim/neovim/pull/27855), but for now I find it useful. 

Using this plugin requires Neovim on current master branch
- it's inspired in some way by https://github.com/echasnovski/mini.notify (at the moment not intended to display UI messages)
- still very experimental
- can display LSP progress notification

## Configuration
```lua
local notifier = require('msg-show.notifier')
notifier.setup({notify = true, debug = true, lspProgress = true, duration = 5000, msgWin = {maxWidth = 130}}) -- defaults

require('msg-show.redir').init(notifier.addUiMessage, notifier.updateUiMessage, notifier.debug, notifier.clearPromptMessage)
vim.keymap.set('n', '<Leader>nh', notifier.showHistory)
```

## Todo
### redirection
- handle `:messages` and `:message clear`
- verify which `nvim__redraw` calls with current options can be redundant
### notifier
- display `list_cmd` messages in a special way (position)
- allow pause/recreate deletion timers
- test message kinds added in https://github.com/neovim/neovim/pull/31279
