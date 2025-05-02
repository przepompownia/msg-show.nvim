# msg-show.nvim
Render UI messages out of the cmdline area (preserving highlights). Handle `ext_emdline` events.

This plugin becomes redundant in favor of the built-in alternative (`see :help vim._extui`), but for now I find it useful. Special thanks to @luukvbaal and the community for solving many issues on Nvim side revealed while using this plugin.

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
- multi-chunk highlight (see `:h E5406`) (priority over ts?)
- cmdline_special_char
- levels
- `more` if needed
