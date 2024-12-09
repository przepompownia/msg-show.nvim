# msg-show.nvim
Render cmdline area output in the same way as from vim.notify (preserving highlights). 

- Inspired in some way by https://github.com/echasnovski/mini.notify
- still very experimental, for example `list_cmd` works with https://github.com/neovim/neovim/pull/31525

Using this plugin requires Neovim at least on https://github.com/neovim/neovim/commit/1b6442034f6a821d357fe59cd75fdae47a7f7cff

## Todo
### redirection
- handle `:messages` and `:message clear`
### notifier
- display `list_cmd` messages in a special way (no timer, position)
- allow pause/recreate deletion timers
- test message kinds added in https://github.com/neovim/neovim/pull/31279
- display title if provided in `vim.notify()`
### nvim
- name kind on `:w` messages
