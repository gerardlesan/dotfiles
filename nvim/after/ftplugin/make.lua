--- after/ftplugin/make.lua
---
--- MAKEFILES REQUIRE HARD TABS. A recipe line indented with spaces produces
--- "missing separator" and is one of the most confusing errors in build tooling.
--- This is the one place the global 'expandtab' MUST be overridden.

vim.bo.expandtab = false -- <Tab> inserts a real tab character
vim.bo.shiftwidth = 4
vim.bo.tabstop = 4
vim.bo.softtabstop = 0 -- 0 so <Tab> is never split into spaces
vim.bo.textwidth = 0
vim.wo.colorcolumn = ""

-- 'list' is on globally, so tabs render as the arrow from 'listchars' — which in a
-- Makefile is genuinely useful confirmation that the indent is a real tab.
