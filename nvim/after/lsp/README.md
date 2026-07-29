# `after/lsp/` — one file per language server

Each `<server-name>.lua` here returns a table of settings for that language
server. Neovim 0.11+ reads every `lsp/<name>.lua` on the runtimepath and
**deep-merges** them in runtimepath order, so:

| Source | Provides | Who maintains it |
|---|---|---|
| `nvim-lspconfig`'s `lsp/<name>.lua` | `cmd`, `filetypes`, `root_markers` | the community |
| **this directory** (`after/lsp/<name>.lua`) | your `settings`, `init_options`, `on_attach` | you |

`after/` is guaranteed to be read **last**, so anything here wins. Verified
behaviour: overriding `cmd` replaces it, while sibling keys such as
`settings.foo` from the base config are preserved.

## Adding a server

1. Create `after/lsp/<server>.lua` returning `{ settings = { ... } }`.
   The file is optional — many servers need no configuration at all.
2. Add `"<server>"` to the `servers` list in `lua/plugins/lsp.lua`.
3. Restart. `mason-lspconfig` installs the binary automatically.

The server name must match nvim-lspconfig's filename. Browse the full list at
<https://github.com/neovim/nvim-lspconfig/tree/master/lsp> or run `:Mason`.

See `docs/ADDING-A-LANGUAGE.md` for a complete worked example that also covers
the treesitter parser, the formatter and the linter.

## Debugging

| Command | Shows |
|---|---|
| `:checkhealth vim.lsp` | attached clients, their root dirs and capabilities |
| `:LspLog` | the raw JSON-RPC log — where "server exited" reasons appear |
| `:lua =vim.lsp.config['lua_ls']` | the fully merged config for one server |
| `:lua =vim.lsp.get_clients()` | live clients in this buffer |

A server that never attaches is almost always one of: the binary is not on
`PATH` (check `:Mason`), or no `root_markers` matched so Neovim did not consider
the file part of a project.
