--- after/ftplugin/rust.lua
---
--- rustfmt's defaults, so nothing is reformatted on save that you did not type.
--- The heavy lifting (runnables, macro expansion, clippy) lives in
--- lua/plugins/lang/rust.lua under <leader>r.

-- rustfmt uses 4 spaces, hard_tabs = false.
vim.bo.expandtab = true
vim.bo.shiftwidth = 4
vim.bo.tabstop = 4
vim.bo.softtabstop = 4

-- rustfmt's max_width default is 100; guide one past it.
vim.wo.colorcolumn = "101"
vim.bo.textwidth = 0

-- Rust lifetimes (`'a`) mean a single quote is often unbalanced, which confuses
-- the autopair and matchpairs machinery. Removing it from 'matchpairs' stops `%`
-- jumping to a nonsense location.
vim.opt_local.matchpairs:remove("'")

-- ── Filetype-local keymaps: raw cargo, complementing rustaceanvim ────────────
-- rustaceanvim's <leader>rr understands the item under the cursor. These are the
-- blunt project-wide equivalents, which is what you want for a full build or a
-- clippy sweep.
local function map(keys, cmd, desc)
  vim.keymap.set("n", keys, function()
    vim.cmd("silent! wall")
    Snacks.terminal(cmd, { interactive = true, win = { position = "bottom", height = 0.4 } })
  end, { buffer = 0, desc = "Cargo: " .. desc })
end

map("<localleader>b", { "cargo", "build" }, "build")
map("<localleader>c", { "cargo", "check" }, "check")
map("<localleader>t", { "cargo", "test" }, "test (whole project)")
map("<localleader>r", { "cargo", "run" }, "run")
map("<localleader>l", { "cargo", "clippy", "--all-targets" }, "clippy")
map("<localleader>f", { "cargo", "fmt" }, "fmt (whole project)")
map("<localleader>d", { "cargo", "doc", "--open" }, "build and open docs")
map("<localleader>u", { "cargo", "update" }, "update dependencies")
