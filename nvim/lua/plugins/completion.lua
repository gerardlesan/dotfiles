--- ~/.config/nvim/lua/plugins/completion.lua
---
--- AUTO-COMPLETION. blink.cmp is the current de-facto choice, having largely
--- displaced nvim-cmp: it is faster (the fuzzy matcher is native code), needs a
--- fraction of the configuration, and bundles snippet, path, buffer and signature
--- support instead of requiring a separate plugin per source.
---
--- IF YOU FIND AN nvim-cmp TUTORIAL: the concepts map, the API does not. nvim-cmp
--- needs one plugin per source (`cmp-nvim-lsp`, `cmp-buffer`, `cmp-path`, ...);
--- blink has them built in and configured under `sources`.
---
--- ── HOW COMPLETION IS DRIVEN ─────────────────────────────────────────────────
--- The menu appears automatically as you type. Nothing is preselected
--- ('completeopt' has `noselect`, and `list.selection.preselect = false` below),
--- which means <CR> stays a newline until you deliberately choose an item. This
--- avoids the single most irritating completion failure: pressing Enter to break a
--- line and getting a random symbol inserted instead.
---
---   <Tab> / <S-Tab>   move through the menu, or jump between snippet placeholders
---   <C-y>             accept (blink's default; <CR> also accepts once selected)
---   <C-e>             dismiss
---   <C-space>         open the menu, then toggle documentation
---   <C-d> / <C-u>     scroll the documentation window
---   <C-k>             signature help

local P = require("config.palette")

return {
  -- ═════════════════════════════════════════════════════════════════════════
  -- SNIPPET ENGINE
  -- ═════════════════════════════════════════════════════════════════════════
  -- LuaSnip is the most capable engine and what friendly-snippets targets.
  -- blink can also use its own built-in engine or Neovim 0.10's native
  -- `vim.snippet`; LuaSnip is chosen for the much larger snippet ecosystem.
  {
    "L3MON4D3/LuaSnip",
    lazy = true,
    -- The `jsregexp` build step enables variable transformations in LSP snippets
    -- (e.g. capitalising a captured group). It needs a compiler and often fails on
    -- Windows, and everything else works fine without it — so it is deliberately
    -- omitted rather than left to fail noisily on every update.
    dependencies = {
      {
        "rafamadriz/friendly-snippets",
        config = function()
          -- Loads a large community snippet collection for ~50 languages, in
          -- VS Code format.
          require("luasnip.loaders.from_vscode").lazy_load()
          -- Also load your own snippets, if you write any. Create
          -- nvim/snippets/<filetype>.json in VS Code format; see
          -- docs/ADDING-A-LANGUAGE.md.
          require("luasnip.loaders.from_vscode").lazy_load({
            paths = { vim.fn.stdpath("config") .. "/snippets" },
          })
        end,
      },
    },
    opts = {
      -- Keep a snippet's placeholders active after you leave and re-enter it.
      history = true,
      -- Re-evaluate dynamic snippet nodes as you type, not only on entry.
      updateevents = "TextChanged,TextChangedI",
      -- Do not leave an abandoned snippet's jump points live forever; if the
      -- cursor moves outside the snippet region, forget it.
      region_check_events = "CursorMoved,CursorMovedI",
      delete_check_events = "TextChanged,InsertLeave",
    },
  },

  -- ═════════════════════════════════════════════════════════════════════════
  -- BLINK.CMP
  -- ═════════════════════════════════════════════════════════════════════════
  {
    "saghen/blink.cmp",
    event = { "InsertEnter", "CmdlineEnter" },
    -- Pin to the 1.x release line. blink ships PREBUILT binaries for its Rust
    -- fuzzy matcher on tagged releases, which is why a version is specified here
    -- while most plugins in this config track their branch: following `main` would
    -- require building the matcher locally.
    version = "1.*",
    dependencies = { "L3MON4D3/LuaSnip", "rafamadriz/friendly-snippets" },

    -- Lets language-specific files in lua/plugins/lang/ append sources without
    -- replacing this list. See lua/plugins/lang/rust.lua for an example.
    opts_extend = { "sources.default" },

    ---@module 'blink.cmp'
    ---@type blink.cmp.Config
    opts = {
      snippets = { preset = "luasnip" },

      -- ── Keymap ────────────────────────────────────────────────────────────
      keymap = {
        -- Start from blink's "default" preset (C-y accept, C-n/C-p navigate,
        -- C-space open) and override the keys worth changing.
        preset = "default",

        -- Tab does the obvious thing in context: move down the menu if it is open,
        -- jump to the next snippet placeholder if inside a snippet, otherwise
        -- insert a literal tab. "fallback" is what makes that last part work.
        ["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
        ["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },

        -- Enter accepts a SELECTED item, and is a newline otherwise.
        ["<CR>"] = { "accept", "fallback" },

        -- Same C-j / C-k navigation as the picker, so the muscle memory is shared.
        ["<C-j>"] = { "select_next", "fallback" },
        ["<C-k>"] = { "select_prev", "fallback" },

        ["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
        ["<C-e>"] = { "hide", "fallback" },
        ["<C-d>"] = { "scroll_documentation_down", "fallback" },
        ["<C-u>"] = { "scroll_documentation_up", "fallback" },
      },

      appearance = {
        -- "mono" tells blink the Nerd Font glyphs are single-width, which is
        -- correct for JetBrains Mono Nerd Font and keeps the menu columns aligned.
        -- Use "normal" if your font's glyphs are double-width.
        nerd_font_variant = "mono",
      },

      completion = {
        -- ── The menu ──────────────────────────────────────────────────────
        menu = {
          border = P.border,
          winblend = 0,
          scrollbar = true,
          draw = {
            -- Three columns: kind icon, label, then the source. Seeing which
            -- source produced a suggestion tells you whether it is a real LSP
            -- symbol or just a word from the buffer.
            columns = {
              { "kind_icon", "label", "label_description", gap = 1 },
              { "kind", "source_name", gap = 1 },
            },
            treesitter = { "lsp" }, -- syntax-highlight the label using treesitter
          },
        },

        -- ── Documentation popup ───────────────────────────────────────────
        documentation = {
          -- Show it automatically after a short pause. Long enough that scrolling
          -- fast through the menu does not flash a doc window for every item.
          auto_show = true,
          auto_show_delay_ms = 200,
          update_delay_ms = 50,
          window = { border = P.border, winblend = 0, max_width = 80 },
        },

        list = {
          selection = {
            -- Nothing preselected: see the note at the top of this file.
            preselect = false,
            -- Do not insert the highlighted item into the buffer as you move
            -- through the menu; only on accept. Inserting-as-you-move makes the
            -- buffer flicker and breaks the fuzzy filter you are typing.
            auto_insert = false,
          },
        },

        accept = {
          -- Add `()` when accepting a function, and put the cursor inside.
          auto_brackets = { enabled = true },
        },

        -- Inline preview of the selected completion, greyed out ahead of the
        -- cursor. Off: it is visually noisy alongside the menu, and it is easily
        -- confused with an AI suggestion.
        ghost_text = { enabled = false },
      },

      -- ── Signature help ────────────────────────────────────────────────────
      -- Shows the function signature with the current parameter highlighted while
      -- you type arguments. noice.nvim's own signature module is disabled so these
      -- do not fight (see lua/plugins/ui.lua).
      signature = {
        enabled = true,
        window = { border = P.border, winblend = 0 },
      },

      -- ── Sources ───────────────────────────────────────────────────────────
      sources = {
        -- Order matters only for tie-breaking; ranking is by fuzzy score plus the
        -- per-provider `score_offset` below.
        default = { "lsp", "path", "snippets", "buffer" },

        providers = {
          -- lazydev supplies Neovim-API completions when editing this config. The
          -- high score_offset floats them above generic buffer words.
          lazydev = {
            name = "LazyDev",
            module = "lazydev.integrations.blink",
            score_offset = 100,
          },
          -- Buffer words are the weakest source: useful as a fallback, but they
          -- should never outrank a real LSP symbol.
          buffer = { score_offset = -3, opts = { max_items = 5 } },
          path = {
            -- Complete paths relative to the current file, not the cwd, which is
            -- what you mean when typing an import or an include.
            opts = { get_cwd = function(_) return vim.fn.expand("%:p:h") end },
          },
        },
      },

      -- ── Fuzzy matcher ─────────────────────────────────────────────────────
      fuzzy = {
        -- "prefer_rust_with_warning" uses the prebuilt Rust matcher when it can
        -- and transparently falls back to the pure-Lua one if the binary is
        -- missing or incompatible, warning once. That fallback is why this config
        -- works on a machine with no toolchain — set it to "lua" to silence the
        -- warning and always use Lua.
        implementation = "prefer_rust_with_warning",
        -- Boost items you have accepted before, and items whose text is near the
        -- cursor. Both make the top suggestion right more often.
        use_frecency = true,
        use_proximity = true,
      },

      -- ── Command-line completion ───────────────────────────────────────────
      -- Completion for `:` commands and `/` searches, in the same popup style.
      cmdline = {
        enabled = true,
        keymap = { preset = "cmdline" },
        completion = {
          menu = { auto_show = true },
          -- Do NOT preselect on the command line either: `:w<CR>` must stay `:w`.
          list = { selection = { preselect = false } },
        },
      },

      -- ── Terminal completion ───────────────────────────────────────────────
      -- Off. Completing shell commands from buffer words is more distracting than
      -- helpful, and the shell has its own completion.
      term = { enabled = false },
    },
  },
}
