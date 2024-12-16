# msg-show.nvim
Render cmdline area output in the same way as from vim.notify (preserving highlights). 

- Inspired in some way by https://github.com/echasnovski/mini.notify
- still very experimental, for example `list_cmd` works with https://github.com/neovim/neovim/pull/31525

Using this plugin requires Neovim at least on https://github.com/neovim/neovim/commit/798f928479

## Todo
### redirection
- handle `:messages` and `:message clear`
### notifier
- display `list_cmd` messages in a special way (no timer, position)
- allow pause/recreate deletion timers
- test message kinds added in https://github.com/neovim/neovim/pull/31279
- display title if provided in `vim.notify()`
- lsp progress messages not always replaced
### nvim
- tabs in `hi` not preserved
- inputlist entered from telescope cmd history (maybe from feedkeys)
