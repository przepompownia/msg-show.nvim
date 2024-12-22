# msg-show.nvim
Render UI messages out of the cmdline area (preserving highlights). It started as a reproduction for some Nvim issue. I hope it becomes redundant in favor of a built-in alternative, but for now I find it useful. 

Using this plugin requires Neovim at least on https://github.com/neovim/neovim/commit/798f928479
- it's inspired in some way by https://github.com/echasnovski/mini.notify (at the moment not intended to display UI messages)
- still very experimental, for example `list_cmd` works with https://github.com/neovim/neovim/pull/31525 and history logic depends on https://github.com/neovim/neovim/pull/31661
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
### notifier
- display `list_cmd` messages in a special way (no timer, position)
- allow pause/recreate deletion timers
- test message kinds added in https://github.com/neovim/neovim/pull/31279
- lsp progress messages not always replaced
### nvim
- inputlist entered from telescope cmd history (maybe from feedkeys)
