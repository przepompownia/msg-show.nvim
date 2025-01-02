# msg-show.nvim
Render UI messages out of the cmdline area (preserving highlights). It started as a reproduction for some Nvim issue. I hope it becomes redundant in favor of a built-in alternative, but for now I find it useful. 

Using this plugin requires Neovim at least on https://github.com/neovim/neovim/commit/43d552c56648bc3125c7509b3d708b6bf6c0c09c
- it's inspired in some way by https://github.com/echasnovski/mini.notify (at the moment not intended to display UI messages)
- still very experimental
- can display LSP progress notification

## Configuration
```lua
local notifier = require('msg-show.notifier')
notifier.setup({notify = true, debug = true, lspProgress = true, duration = 5000}) -- defaults

require('msg-show.redir').init(notifier.addUiMessage, notifier.updateUiMessage, notifier.debug)
vim.keymap.set('n', '<Leader>nh', notifier.showHistory)
```

## Todo
### redirection
- handle `:messages` and `:message clear`
- verify which `nvim__redraw` calls with current options can be redundant
### notifier
- display `list_cmd` messages in a special way (no timer, position)
- allow pause/recreate deletion timers
- test message kinds added in https://github.com/neovim/neovim/pull/31279
- verify if lsp progress messages not always replaced
- wrap lines longer than max
### nvim
- inputlist entered from telescope cmd history (maybe from feedkeys)
