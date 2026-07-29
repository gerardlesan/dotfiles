# `after/ftplugin/` — per-filetype buffer settings

One file per filetype. Neovim sources `after/ftplugin/<filetype>.lua` every time a
buffer of that type is opened, *after* the built-in and plugin ftplugins — so
anything here wins.

This is the correct place for per-language settings, and it is better than a
`FileType` autocmd for three reasons:

1. It runs after everything else, so a plugin's ftplugin cannot override you.
2. It is one obvious file per language, discoverable by name.
3. Neovim handles the `b:undo_ftplugin` bookkeeping, so switching a buffer's
   filetype cleanly reverts these settings.

## Rules

**Use buffer-local or window-local scope, never global.** A global `vim.opt` here
leaks into every other buffer:

```lua
vim.bo.shiftwidth = 4    -- buffer-local  ✔
vim.wo.wrap = true       -- window-local  ✔
vim.opt_local.spell = true -- either, resolved automatically  ✔
vim.opt.shiftwidth = 4   -- GLOBAL — wrong, affects every file  ✘
```

**Keymaps must pass `buffer = 0`**, or they apply everywhere:

```lua
vim.keymap.set("n", "<localleader>r", "...", { buffer = 0, desc = "..." })
```

`<localleader>` is `\` (set in `lua/config/options.lua`) and is reserved for
exactly this: filetype-specific commands that cannot collide with a global
binding.

## What lives here vs elsewhere

| Concern | Where |
|---|---|
| indent width, text width, wrap, spell | here |
| filetype-local keymaps | here |
| language server settings | `after/lsp/<server>.lua` |
| formatter / linter choice | `lua/plugins/format.lua`, `lua/plugins/lint.lua` |
| plugins for a language | `lua/plugins/lang/<lang>.lua` |

## Debugging

`:verbose set shiftwidth?` prints the current value **and the file that last set
it** — the fastest way to find out which ftplugin or plugin is fighting you.
`:set filetype?` confirms Neovim detected the type you expect.
