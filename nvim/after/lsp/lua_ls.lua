--- after/lsp/lua_ls.lua — Lua language server
---
--- Tuned for editing Neovim configuration, which is the only Lua most people
--- write. lazydev.nvim (lua/plugins/lsp.lua) supplies the workspace library on
--- demand, so this file does NOT need to list Neovim's runtime paths — doing that
--- by hand is the slow, stale approach you will see in older configs.

return {
  settings = {
    Lua = {
      runtime = {
        -- Neovim embeds LuaJIT, which is Lua 5.1 with extensions. Telling the
        -- server this is what makes `bit`, `jit` and `goto` resolve correctly.
        version = "LuaJIT",
        -- Let `require("config.palette")` resolve to lua/config/palette.lua.
        path = { "lua/?.lua", "lua/?/init.lua" },
      },

      workspace = {
        -- Do not prompt "do you need to configure your work environment as
        -- luassert?" every time you open a file. lazydev handles the library.
        checkThirdParty = false,
        -- lazydev injects libraries dynamically; an empty list here is correct.
        library = {},
      },

      diagnostics = {
        -- `vim` is injected by Neovim, and `Snacks` by snacks.nvim. Without these
        -- the whole config is underlined as undefined-global.
        globals = { "vim", "Snacks", "dd", "bt" },
        disable = {
          -- Plugin `opts` tables are intentionally partial — you set three keys of
          -- a thirty-key table and the plugin fills the rest. Without this, every
          -- single spec in lua/plugins/ is flagged as missing fields.
          "missing-fields",
          -- Fires on `---@type` annotations that narrow a type, which is exactly
          -- what they are for.
          "duplicate-set-field",
        },
        unusedLocalExclude = { "_*" }, -- `local _ = x` is a deliberate discard
      },

      completion = {
        -- Insert the full function call with parameter placeholders, e.g.
        -- `vim.keymap.set(mode, lhs, rhs)`, rather than just the name. Combined
        -- with snippet support in blink.cmp you then Tab between the arguments.
        callSnippet = "Replace",
        keywordSnippet = "Replace",
        showWord = "Disable", -- do not offer plain-text words; LSP results are better
      },

      hint = {
        -- Inlay hints. `setType` is the useful one: it shows the inferred type of
        -- a local, which is otherwise invisible in Lua.
        enable = true,
        setType = true,
        paramType = true,
        paramName = "Literal",
        -- Array indices as inlay hints turn every table literal into `[1] [2] [3]`,
        -- which is noise in a config file full of lists.
        arrayIndex = "Disable",
      },

      -- stylua does the formatting (see lua/plugins/format.lua). Two formatters
      -- disagreeing over the same buffer produces a diff war on every save.
      format = { enable = false },

      -- "N references" annotations above functions.
      codeLens = { enable = true },

      telemetry = { enable = false },
    },
  },
}
