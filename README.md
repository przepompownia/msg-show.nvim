# msg-show.nvim
Render UI messages out of the cmdline area (preserving highlights). Handle `ext_emdline` events.

I hope it becomes redundant in favor of a built-in alternative (probably https://github.com/neovim/neovim/pull/27855), but for now I find it useful. Special thanks to @luukvbaal for solving many issues on Nvim side revealed while using this plugin.

Using this plugin requires Neovim on current master branch
- it's inspired in some way by https://github.com/echasnovski/mini.notify (at the moment not intended to display UI messages)
- still very experimental and not fully implemented
- can display LSP progress notification

## Configuration
```lua
local msgShow = require('msg-show')
msgShow.setup({notifier = {lspProgress = true, duration = 5000, msgWin = {maxWidth = 130}}}) -- defaults
vim.keymap.set('n', '<Leader>nh', msgShow.history)
vim.keymap.set('n', '<Leader><Leader>', msgShow.delayRemoval)
```

## Todo
### init
- handle `:messages` and `:message clear`
### cmdline
- multi-chunk highlight (see `:h E5406`)
- levels
- highlights
- `more` if needed
- `cmdline_block_*`, `cmdline_special_char` events
- wildmenu - depends on https://github.com/neovim/neovim/pull/31269
