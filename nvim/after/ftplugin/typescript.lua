--- after/ftplugin/typescript.lua
---
--- prettier's defaults, so format-on-save never reflows what you just typed:
--- 2-space indent, printWidth 80.
---
--- Everything else for this language lives elsewhere:
---   after/lsp/vtsls.lua              completion, inlay hints, TS-specific commands
---   after/lsp/eslint.lua             linting
---   lua/plugins/format.lua           prettierd on save
---   lua/plugins/lang/typescript.lua  package.json version hints
--- Note the SEPARATE typescriptreact filetype for .tsx — it needs its own parser
--- and its own ftplugin file, which is a common thing to forget.

vim.bo.expandtab = true
vim.bo.shiftwidth = 2
vim.bo.tabstop = 2
vim.bo.softtabstop = 2

vim.wo.colorcolumn = "81"
vim.bo.textwidth = 0

-- `gf` on an import specifier should find the module. Node resolution means the
-- extension is usually omitted in the source, so list the candidates.
vim.bo.suffixesadd = ".ts,.tsx,.js,.jsx,.mjs,.cjs,.json"

-- Hyphens are not part of an identifier in TS/JS, so leave 'iskeyword' alone —
-- unlike CSS below, where they are.