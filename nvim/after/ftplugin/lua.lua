--- after/ftplugin/lua.lua
---
--- Matches .stylua.toml at the repo root, so the editor and the formatter agree.

vim.bo.expandtab = true
vim.bo.shiftwidth = 2
vim.bo.tabstop = 2
vim.bo.softtabstop = 2

-- stylua's default column_width is 120; the guide sits one past it.
vim.wo.colorcolumn = "121"
vim.bo.textwidth = 0

-- `require("config.palette")` uses dots, so `gf` needs to know that a dot is part
-- of the "filename" and that .lua is the extension to try. With these, pressing
-- `gf` on a require() path opens the module.
vim.opt_local.includeexpr = "substitute(v:fname, '\\.', '/', 'g')"
vim.bo.suffixesadd = ".lua"
vim.opt_local.path:append("lua")

-- ── Filetype-local keymaps ──────────────────────────────────────────────────
local function map(keys, rhs, desc)
  vim.keymap.set("n", keys, rhs, { buffer = 0, desc = "Lua: " .. desc })
end

-- Source the current file into the running Neovim. The fastest way to iterate on
-- this config: edit a keymap, press <localleader>x, try it immediately — no
-- restart. Note that plugin `opts` changes still need `:Lazy reload <plugin>`,
-- because those are only read when the plugin is set up.
map("<localleader>x", "<cmd>source %<cr>", "Source this file")

-- Re-run the whole config. Useful after editing options.lua or keymaps.lua.
map("<localleader>r", function()
  for _, mod in ipairs({ "config.options", "config.keymaps", "config.autocmds", "config.palette" }) do
    package.loaded[mod] = nil
  end
  require("config.options")
  require("config.keymaps")
  require("config.autocmds")
  vim.notify("Reloaded core config", vim.log.levels.INFO, { title = "Lua" })
end, "Reload core config modules")
