# msg-show.nvim
Render UI messages out of the cmdline area (preserving highlights). Handle `ext_emdline` events.

I hope it becomes redundant in favor of a built-in alternative (probably https://github.com/neovim/neovim/pull/27855), but for now I find it useful. Special thanks to @luukvbaal for solving many issues on Nvim side revealed while using this plugin.

Using this plugin requires Neovim on current master branch
- it's inspired in some way by https://github.com/echasnovski/mini.notify (at the moment not intended to display UI messages)
- still very experimental and not fully implemented
- can display LSP progress notification

## Configuration
```lua
local notifier = require('msg-show.notifier')
notifier.setup({lspProgress = true, duration = 5000, msgWin = {maxWidth = 130}}) -- defaults

require('msg-show').init()
vim.keymap.set('n', '<Leader>nh', notifier.showHistory)
vim.keymap.set('n', '<Leader><Leader>', notifier.delayRemoval)
```

## Todo
### init
- handle `:messages` and `:message clear`
- verify which `nvim__redraw` calls with current options can be redundant
### notifier
- allow pause/recreate deletion timers
### cmdline
- multi-chunk content
- indents
- highlights
- `more` if needed
- `cmdline_block_*`, `cmdline_special_char` events
