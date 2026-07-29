--- after/ftplugin/sh.lua
--- Also applies to bash and .env files (mapped to `sh` in lua/config/options.lua).

vim.bo.expandtab = true
vim.bo.shiftwidth = 2
vim.bo.tabstop = 2
vim.bo.softtabstop = 2
vim.wo.colorcolumn = "101"
vim.bo.textwidth = 0

-- shfmt is the formatter and shellcheck the linter; see lua/plugins/format.lua
-- and lua/plugins/lint.lua.

-- Make the current script executable and run it.
vim.keymap.set("n", "<localleader>r", function()
  vim.cmd("silent! write")
  local file = vim.fn.expand("%:p")
  if vim.fn.has("win32") == 0 then
    vim.fn.system({ "chmod", "+x", file })
  end
  Snacks.terminal({ vim.o.shell, file }, { interactive = true })
end, { buffer = 0, desc = "Shell: run this script" })
