# msg-show.nvim
Render cmdline area output in the same way as from vim.notify (preserving colors). 

- Inspired in some way by https://github.com/echasnovski/mini.notify
- still very experimental: for example some message kinds are still not handled correctly (inputlist does not work)

Using this plugin requires Neovim at least on https://github.com/neovim/neovim/commit/1b6442034f6a821d357fe59cd75fdae47a7f7cff

## Todo
### redirection
- handle `:messages` and `:message clear`
### notifier
- allow pause/recreate deletion timers
- test message kinds added in https://github.com/neovim/neovim/pull/31279
- LSP progress handler
- display title if provided in `vim.notify()`
### nvim
- name kind on `:w` messages
