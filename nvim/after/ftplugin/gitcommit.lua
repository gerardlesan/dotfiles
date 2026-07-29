--- after/ftplugin/gitcommit.lua
---
--- Enforces the conventional git message shape: a <=50 character subject, a blank
--- line, then a body wrapped at 72.

vim.opt_local.spell = true
vim.opt_local.spelllang = { "en_us" }

-- 72 is the body wrap width that keeps `git log` readable in an 80-column terminal.
vim.bo.textwidth = 72
vim.opt_local.formatoptions:append("t")

-- Two guides: 51 marks the subject-line limit, 73 the body limit. Seeing both is
-- what makes the convention automatic rather than remembered.
vim.wo.colorcolumn = "51,73"

vim.wo.wrap = true
vim.wo.linebreak = true

-- Start on line 1 in insert mode: you opened this to type a message.
-- (The last-location autocmd in lua/config/autocmds.lua explicitly skips
-- gitcommit for this reason.)
vim.api.nvim_win_set_cursor(0, { 1, 0 })
if vim.api.nvim_get_current_line() == "" then
  vim.cmd("startinsert")
end

-- No line numbers or sign column: this is a message, not code.
vim.wo.number = false
vim.wo.relativenumber = false