# msg-show.nvim
Render UI messages out of the cmdline area (preserving highlights). It started as a reproduction for some Nvim issue. I hope it becomes redundant in favor of a built-in alternative (probably https://github.com/neovim/neovim/pull/27855), but for now I find it useful. Special thanks to @luukvbaal for solving many issues on Nvim side revealed while using this plugin.

Using this plugin requires Neovim on current master branch
- it's inspired in some way by https://github.com/echasnovski/mini.notify (at the moment not intended to display UI messages)
- still very experimental
- can display LSP progress notification

## Configuration
```lua
local notifier = require('msg-show.notifier')
notifier.setup({notify = true, debug = true, lspProgress = true, duration = 5000, msgWin = {maxWidth = 130}}) -- defaults

require('msg-show.redir').init()
vim.keymap.set('n', '<Leader>nh', notifier.showHistory)
vim.keymap.set('n', '<Leader><Leader>', notifier.delayRemoval)
```

## Todo
### redirection
- handle `:messages` and `:message clear`
- verify which `nvim__redraw` calls with current options can be redundant
### notifier
- allow pause/recreate deletion timers
