--- after/ftplugin/toml.lua
--- Cargo.toml, pyproject.toml. taplo formats these (see lua/plugins/format.lua),
--- and crates.nvim annotates dependency versions in Cargo.toml.

vim.bo.expandtab = true
vim.bo.shiftwidth = 2
vim.bo.tabstop = 2
vim.bo.softtabstop = 2
vim.bo.textwidth = 0
vim.wo.colorcolumn = ""
vim.opt_local.iskeyword:append("-")