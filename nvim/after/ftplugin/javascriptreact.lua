--- after/ftplugin/javascriptreact.lua
---
--- prettier's defaults: 2 spaces, printWidth 80. See after/ftplugin/typescript.lua
--- for the full commentary — the settings are identical across the four
--- TypeScript/JavaScript filetypes, and Neovim needs one file per filetype.

vim.bo.expandtab = true
vim.bo.shiftwidth = 2
vim.bo.tabstop = 2
vim.bo.softtabstop = 2

-- prettier's printWidth default is 80; the guide sits one past it.
vim.wo.colorcolumn = "81"
vim.bo.textwidth = 0

-- `gf` on an import specifier should find the module.
vim.bo.suffixesadd = ".ts,.tsx,.js,.jsx,.mjs,.cjs,.json"
