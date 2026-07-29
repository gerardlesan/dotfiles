--- ~/.config/nvim/lua/config/lazy.lua
---
--- Bootstraps lazy.nvim (the de-facto plugin manager) and loads every spec under
--- lua/plugins/. Nothing else belongs in this file.
---
--- How the plugin tree is organised:
---   lua/plugins/*.lua        one file per concern — ui, git, lsp, editor, ...
---   lua/plugins/lang/*.lua   one file per language — rust, python, typescript
---
--- `import` only reads a single directory level, so the language folder is
--- imported explicitly on the second line of `spec`. Adding a new language means
--- dropping a file into lua/plugins/lang/ — no edit here.

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

-- Clone lazy.nvim on first launch. `vim.uv` is the modern name for `vim.loop`;
-- the fallback keeps this file working on older Neovim if you ever downgrade.
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local repo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "--branch=stable",
    repo,
    lazypath,
  })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nIs git installed and on your PATH? Press any key to exit." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end

-- Put lazy.nvim itself at the front of the runtimepath so `require("lazy")` works.
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    { import = "plugins" }, -- concerns
    { import = "plugins.lang" }, -- languages
  },

  defaults = {
    -- Plugins are lazy by default: nothing loads until an event, key, command or
    -- filetype asks for it. Specs that must load eagerly say `lazy = false`
    -- themselves (the colorscheme and nvim-treesitter both do).
    lazy = true,
    -- `version = false` means "track the default branch" rather than "latest
    -- tagged release". Most Neovim plugins do not tag releases, and those that do
    -- often tag rarely; following the branch is what the ecosystem actually
    -- tests against. Reproducibility comes from lazy-lock.json, not from tags.
    version = false,
  },

  -- Which colorscheme to apply while plugins are installing on a fresh clone, so
  -- the very first launch is not blinding white.
  install = { colorscheme = { "tokyonight", "habamax" } },

  -- Check for plugin updates in the background and mark them in the lazy UI, but
  -- never interrupt with a popup. Run `:Lazy update` when you feel like it.
  checker = { enabled = true, notify = false, frequency = 86400 },

  -- Reload specs when you edit a file in this repo, silently.
  change_detection = { enabled = true, notify = false },

  -- IMPORTANT on Windows: lazy.nvim can try to provision luarocks (via hererocks)
  -- for plugins that declare rock dependencies. That needs a working Lua/luarocks
  -- toolchain and is a reliable source of pain on Windows. Every plugin in this
  -- config is chosen to be pure Lua or to ship prebuilt binaries, so rocks are
  -- switched off entirely and stay off on Linux too, for parity.
  rocks = { enabled = false },

  ui = {
    border = require("config.palette").border,
    backdrop = 100, -- 100 = no dimming behind the lazy window; 60 dims the editor
    -- Escaped for the same reason as the palette icons — see the long note in
    -- lua/config/palette.lua about Private Use Area characters not surviving.
    icons = {
      ft = "\u{f07b} ", -- nf-fa-folder
      lazy = "\u{f0e7} ", -- nf-fa-bolt
      loaded = "\u{f111} ", -- nf-fa-circle (filled = loaded)
      not_loaded = "\u{f10c} ", -- nf-fa-circle_o (hollow = not yet loaded)
    },
  },

  performance = {
    rtp = {
      -- Neovim ships a pile of legacy vimscript plugins that this config either
      -- replaces or never uses. Disabling them shaves real milliseconds off
      -- startup and, more usefully, stops netrw from hijacking `:edit <dir>`
      -- (oil.nvim and neo-tree own directories here instead).
      disabled_plugins = {
        "gzip", -- transparently edit .gz files
        "netrwPlugin", -- built-in file browser + :Gbrowse-style URL opening
        "tarPlugin", -- browse .tar archives
        "tohtml", -- :TOhtml
        "tutor", -- :Tutor
        "zipPlugin", -- browse .zip archives
        -- Kept ENABLED on purpose:
        --   matchit / matchparen — replaced by vim.treesitter + mini.pairs, but
        --   harmless and still used for % in filetypes without a parser.
        --   editorconfig        — Neovim's built-in .editorconfig support. Worth
        --                         keeping: it makes this config respect project
        --                         indent settings automatically.
        --   man                 — `:Man` is genuinely useful on Linux.
      },
    },
  },
})

-- Convenience: `:Lazy` is the plugin dashboard. Bound to <leader>pl in keymaps.lua.
