--- after/ftplugin/yaml.lua
---
--- YAML is whitespace-significant, so indentation settings are correctness, not
--- style. 2 spaces is the universal convention and what prettier emits.

vim.bo.expandtab = true
vim.bo.shiftwidth = 2
vim.bo.tabstop = 2
vim.bo.softtabstop = 2

-- A literal tab character is a SYNTAX ERROR in YAML. 'expandtab' above prevents
-- you inserting one, and 'list' (on globally) makes any pre-existing tab visible
-- as a red-flag arrow.
vim.bo.textwidth = 0
vim.wo.colorcolumn = ""

-- Deeply nested YAML relies entirely on indentation to be readable, so the indent
-- guides from snacks.indent matter more here than anywhere else.

-- YAML keys often contain hyphens (`image-name:`), so treat them as part of a word
-- for `w`, `*` and completion.
vim.opt_local.iskeyword:append("-")