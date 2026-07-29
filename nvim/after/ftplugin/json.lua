--- after/ftplugin/json.lua

vim.bo.expandtab = true
vim.bo.shiftwidth = 2
vim.bo.tabstop = 2
vim.bo.softtabstop = 2

-- JSON has no comments, so there is nothing to wrap and no comment leader.
vim.bo.textwidth = 0
vim.wo.colorcolumn = ""

-- Quotes are syntactically required in JSON, so concealing them (which some
-- configs do for readability) hides whether the file is actually valid. Keep the
-- global conceallevel of 0.
vim.wo.conceallevel = 0

-- Pretty-print the buffer. Handy for a minified API response pasted in.
vim.keymap.set("n", "<localleader>p", function()
  if vim.fn.executable("prettierd") == 1 or vim.fn.executable("prettier") == 1 then
    require("conform").format({ async = false, bufnr = 0 })
  else
    -- Fall back to Neovim's own JSON round-trip, which normalises formatting.
    local ok, decoded = pcall(vim.json.decode, table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n"))
    if not ok then
      vim.notify("Invalid JSON: " .. tostring(decoded), vim.log.levels.ERROR)
      return
    end
    local encoded = vim.json.encode(decoded)
    vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(encoded, "\n"))
  end
end, { buffer = 0, desc = "JSON: pretty-print" })
