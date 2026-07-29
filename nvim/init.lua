--- ~/.config/nvim/init.lua ─ entry point
---
--- This file does as little as possible on purpose. It only fixes the *order* in
--- which the four core modules load, because that order actually matters:
---
---   1. config.options  — must run first. It sets <leader>, and a plugin spec that
---                        declares a "<leader>x" key is resolved at spec-load time,
---                        so a leader set later would silently map to the wrong key.
---                        It also sets 'shell', which lazy.nvim needs before it
---                        shells out to git.
---   2. config.lazy     — bootstraps lazy.nvim and imports lua/plugins/**.
---   3. config.keymaps  — editor-wide keymaps only. Keymaps that belong to one
---                        plugin live in that plugin's spec, so the plugin can stay
---                        lazy-loaded until the key is pressed.
---   4. config.autocmds — behaviour that reacts to events.
---
--- Anything machine-specific goes in lua/config/local.lua, which is git-ignored
--- and loaded last so it can override everything above.
---
--- Layout of this config:
---   init.lua                  this file
---   lua/config/palette.lua    all colour + icon definitions
---   lua/config/options.lua    every Vim option, documented and classified
---   lua/config/keymaps.lua    global keymaps
---   lua/config/autocmds.lua   autocommands
---   lua/config/lazy.lua       plugin-manager bootstrap
---   lua/plugins/*.lua         one file per concern (ui, git, lsp, ...)
---   lua/plugins/lang/*.lua    one file per language
---   lsp/*.lua                 one file per language server (Neovim 0.11+ native)
---   after/ftplugin/*.lua      per-filetype buffer-local settings

require("config.options")
require("config.lazy")
require("config.keymaps")
require("config.autocmds")

-- Optional, git-ignored, per-machine overrides. Absent by default; `pcall` so a
-- missing file is silent but a *broken* file still reports its error.
local ok, err = pcall(require, "config.local")
if not ok and not err:match("module 'config.local' not found") then
  vim.notify("config.local failed to load:\n" .. err, vim.log.levels.ERROR)
end
