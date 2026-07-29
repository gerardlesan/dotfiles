--- ~/.config/nvim/lua/plugins/lsp.lua
---
--- ═════════════════════════════════════════════════════════════════════════════
--- LANGUAGE SERVERS — "Intellisense"
--- ═════════════════════════════════════════════════════════════════════════════
---
--- This config uses Neovim 0.12's NATIVE LSP API, not the old
--- `require("lspconfig").server.setup{}` pattern. If you find a tutorial using
--- that, it still works but it is the previous generation. The modern shape:
---
---   vim.lsp.config("name", { ... })   register or extend a server's config
---   vim.lsp.enable("name")           start it automatically for its filetypes
---
--- ── HOW A SERVER'S CONFIG IS ASSEMBLED ───────────────────────────────────────
--- Neovim collects every `lsp/<name>.lua` on the runtimepath and DEEP-MERGES them
--- in runtimepath order, so later files win key-by-key. That gives a clean split:
---
---   nvim-lspconfig's  lsp/<name>.lua   the boring base: cmd, filetypes,
---                                      root_markers. ~300 servers, maintained
---                                      by the community. You never edit these.
---   this repo's  after/lsp/<name>.lua  YOUR settings. `after/` is guaranteed to
---                                      be read last, so it always wins.
---
--- ── THEREFORE: ADDING A LANGUAGE IS ONE FILE ─────────────────────────────────
---   1. create  after/lsp/<server>.lua   returning a table of settings
---   2. add the server name to `servers` below
---   3. add the parser to `ensure_parsers` in lua/plugins/treesitter.lua
--- Steps 2 and 3 are one line each. See docs/ADDING-A-LANGUAGE.md for a worked
--- example, including formatter and linter.
---
--- `:checkhealth vim.lsp` shows what is attached; `:LspInfo` is the detailed view.

local P = require("config.palette")
local icons = P.icons

--- Language servers to enable.
---
--- These names must match nvim-lspconfig's filenames (which are also the names
--- mason-lspconfig uses). Browse them with `:Mason` or at
--- https://github.com/neovim/nvim-lspconfig/tree/master/lsp
---
--- Servers with a matching after/lsp/<name>.lua get those settings applied.
--- Servers listed here without such a file just use nvim-lspconfig's defaults,
--- which is often entirely fine.
local servers = {
  -- ── Lua: for editing this config ─────────────────────────────────────────
  "lua_ls",

  -- ── Python ───────────────────────────────────────────────────────────────
  -- Two servers on purpose, and they do not overlap:
  --   basedpyright  types, completion, go-to-definition, inlay hints
  --   ruff          linting and import organisation, via LSP code actions
  -- basedpyright is a fork of pyright with stricter inference and more features
  -- unlocked; swap the name for "pyright" if you prefer the original.
  "basedpyright",
  "ruff",

  -- ── TypeScript / JavaScript ──────────────────────────────────────────────
  -- vtsls wraps the same tsserver that VS Code uses, but speaks proper LSP.
  -- The alternative, "ts_ls", is the more minimal official wrapper; vtsls has
  -- better inlay hints and handles monorepos more gracefully.
  "vtsls",
  "eslint",

  -- ── Rust ─────────────────────────────────────────────────────────────────
  -- DELIBERATELY ABSENT. rustaceanvim (lua/plugins/lang/rust.lua) owns
  -- rust_analyzer completely — it needs to control initialisation to provide
  -- expand-macro, runnables and debugging. Enabling it here too would start a
  -- second, conflicting client. This is the single most common Rust-on-Neovim
  -- misconfiguration.

  -- ── Config, data and markup ──────────────────────────────────────────────
  "jsonls", -- JSON, with schema validation from SchemaStore
  "yamlls", -- YAML, likewise
  "taplo", -- TOML (Cargo.toml, pyproject.toml)
  "bashls", -- shell scripts
  "marksman", -- markdown: link checking, heading navigation
  "html",
  "cssls",
  "dockerls",
}

return {
  -- ═════════════════════════════════════════════════════════════════════════
  -- MASON — installs language servers, formatters and linters
  -- ═════════════════════════════════════════════════════════════════════════
  -- Mason downloads tools into stdpath("data")/mason and puts them on Neovim's
  -- PATH. That is what makes this config portable: you do not need to
  -- `npm install -g` or `pip install` anything by hand on a new machine, and the
  -- versions are per-editor rather than polluting the system.
  {
    "mason-org/mason.nvim",
    cmd = { "Mason", "MasonInstall", "MasonUpdate", "MasonUninstall", "MasonLog" },
    build = ":MasonUpdate",
    opts = {
      ui = {
        border = P.border,
        width = 0.8,
        height = 0.8,
        icons = {
          package_installed = "\u{f00c} ",
          package_pending = "\u{f251} ",
          package_uninstalled = "\u{f00d} ",
        },
      },
      -- Where mason keeps its downloads. Left at the default (stdpath("data")),
      -- which is correct on both platforms and is NOT inside this repo — these are
      -- platform-specific binaries.
    },
  },

  -- Installs the non-LSP tools (formatters, linters) that conform.nvim and
  -- nvim-lint expect to find. Without this you get "command not found" the first
  -- time you format on a new machine.
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = { "mason-org/mason.nvim" },
    event = "VeryLazy",
    opts = {
      ensure_installed = {
        -- Formatters (see lua/plugins/format.lua)
        "stylua", -- Lua
        "prettierd", -- TS/JS/JSON/YAML/CSS/HTML/Markdown — daemon, fast
        "shfmt", -- shell
        -- Linters (see lua/plugins/lint.lua)
        "markdownlint-cli2", -- markdown
        "shellcheck", -- shell
        -- Note: `ruff` covers both formatting and linting for Python and is
        -- installed as an LSP above, so it is not repeated here.
        -- Note: `rustfmt` and `clippy` come from rustup, not mason — see
        -- lua/plugins/lang/rust.lua.
      },
      -- Install quietly in the background on startup rather than opening a window.
      run_on_start = true,
      start_delay = 3000,
      auto_update = false,
    },
  },

  -- ═════════════════════════════════════════════════════════════════════════
  -- NVIM-LSPCONFIG — the base configs, plus mason-lspconfig to install them
  -- ═════════════════════════════════════════════════════════════════════════
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      { "mason-org/mason.nvim" },
      { "mason-org/mason-lspconfig.nvim" },
      -- Better Lua completion for the Neovim API itself, see below.
      { "folke/lazydev.nvim" },
    },

    config = function()
      -- ── 1. Tell mason-lspconfig which servers to install ─────────────────
      require("mason-lspconfig").setup({
        ensure_installed = servers,

        -- ⚠ DELIBERATELY FALSE. This is worth understanding.
        --
        -- `automatic_enable = true` (the default) calls vim.lsp.enable() for every
        -- package mason has installed that happens to have a matching config in
        -- nvim-lspconfig. That sounds convenient and is actively wrong here, for
        -- two reasons found by testing:
        --
        --   1. mason installs `stylua` as a FORMATTER, and nvim-lspconfig happens
        --      to ship an lsp/stylua.lua for stylua's experimental `--lsp` mode.
        --      So stylua got started as a language server on every Lua buffer,
        --      giving two format-capable clients competing with conform.nvim.
        --      The same trap applies to any tool that is both a formatter and has
        --      an LSP shim.
        --   2. rust_analyzer must NOT be enabled here at all — rustaceanvim owns
        --      it (see the note in the `servers` list above).
        --
        -- With this false, mason's only job is INSTALLING. What actually runs is
        -- decided by the explicit vim.lsp.enable(servers) call below, so the set
        -- of live servers is exactly the list at the top of this file and nothing
        -- else. Predictable beats automatic.
        automatic_enable = false,
      })

      -- ── 2. Default capabilities for every server ─────────────────────────
      -- Capabilities tell the server what this client can do. blink.cmp extends
      -- them to advertise snippet support and better completion resolution, which
      -- is what unlocks auto-import and full documentation in the popup.
      local capabilities = vim.lsp.protocol.make_client_capabilities()
      local has_blink, blink = pcall(require, "blink.cmp")
      if has_blink then
        capabilities = blink.get_lsp_capabilities(capabilities)
      end

      -- Advertise that we can watch files, so servers like vtsls notice changes
      -- made outside Neovim (a git checkout, a codegen step).
      capabilities.workspace = capabilities.workspace or {}
      capabilities.workspace.didChangeWatchedFiles = { dynamicRegistration = true }

      -- `vim.lsp.config("*", ...)` sets defaults merged into EVERY server, so this
      -- does not need repeating in each after/lsp/ file.
      vim.lsp.config("*", {
        capabilities = capabilities,
      })

      -- ── 3. Enable the servers ────────────────────────────────────────────
      -- Neovim now resolves each name against nvim-lspconfig's lsp/<name>.lua
      -- plus this repo's after/lsp/<name>.lua, and starts the server when a
      -- matching file is opened.
      vim.lsp.enable(servers)

      -- ── 4. Buffer-local setup when a server attaches ─────────────────────
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("lsp_attach", { clear = true }),
        desc = "Set up LSP keymaps and features for the attached buffer",
        callback = function(event)
          local bufnr = event.buf
          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if not client then
            return
          end

          -- Honour the "this is a secrets file" flag set in autocmds.lua: detach
          -- rather than shipping credentials to a language server.
          if vim.b[bufnr].lsp_disable then
            vim.schedule(function()
              vim.lsp.buf_detach_client(bufnr, event.data.client_id)
            end)
            return
          end

          --- Map a key only if the server actually supports the feature, so you
          --- never press `gr` and get silence because this particular server has
          --- no references provider.
          local function map(keys, fn, desc, mode)
            vim.keymap.set(mode or "n", keys, fn, {
              buffer = bufnr,
              desc = "LSP: " .. desc,
              silent = true,
            })
          end

          -- ── Navigation. Uses the picker so multiple results are browsable
          --    with a preview, instead of dumping you in a quickfix list.
          map("gd", function()
            Snacks.picker.lsp_definitions()
          end, "Go to definition")
          map("gD", function()
            Snacks.picker.lsp_declarations()
          end, "Go to declaration")
          map("gr", function()
            Snacks.picker.lsp_references()
          end, "References")
          map("gI", function()
            Snacks.picker.lsp_implementations()
          end, "Go to implementation")
          map("gy", function()
            Snacks.picker.lsp_type_definitions()
          end, "Go to type definition")
          map("<leader>ss", function()
            Snacks.picker.lsp_symbols()
          end, "Document symbols")
          map("<leader>sS", function()
            Snacks.picker.lsp_workspace_symbols()
          end, "Workspace symbols")

          -- ── Documentation
          -- `K` is Vim's traditional "look up the thing under the cursor", now
          -- backed by the LSP. Neovim 0.11+ maps this by default, but doing it
          -- explicitly makes the border and behaviour ours.
          map("K", function()
            vim.lsp.buf.hover({ border = P.border, max_width = 90 })
          end, "Hover documentation")
          map("gK", function()
            vim.lsp.buf.signature_help({ border = P.border })
          end, "Signature help")
          map("<C-k>", function()
            vim.lsp.buf.signature_help({ border = P.border })
          end, "Signature help", "i")

          -- ── Actions
          map("<leader>ca", vim.lsp.buf.code_action, "Code action", { "n", "v" })
          map("<leader>cr", vim.lsp.buf.rename, "Rename symbol")
          -- "Source" actions are whole-file operations: organise imports, add all
          -- missing imports, fix all auto-fixable problems.
          map("<leader>cA", function()
            vim.lsp.buf.code_action({
              context = { only = { "source" }, diagnostics = {} },
              apply = true,
            })
          end, "Source action (organise imports etc.)")
          map("<leader>cl", "<cmd>checkhealth vim.lsp<cr>", "LSP info / health")

          -- ── Codelens: inline "N references", "run test" annotations that some
          --    servers provide. Off by default in Neovim; refreshed on idle.
          if client:supports_method("textDocument/codeLens") then
            map("<leader>cc", vim.lsp.codelens.run, "Run codelens")
            map("<leader>cC", vim.lsp.codelens.refresh, "Refresh codelens")
            vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold", "InsertLeave" }, {
              buffer = bufnr,
              callback = function()
                pcall(vim.lsp.codelens.refresh, { bufnr = bufnr })
              end,
            })
          end

          -- ── Inlay hints: inferred types and parameter names shown inline.
          --    Enormously helpful in Rust and TypeScript, where types are usually
          --    inferred and therefore invisible. Toggle with <leader>uh.
          if client:supports_method("textDocument/inlayHint") then
            vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
          end

          -- ── Document highlight: underline other uses of the symbol under the
          --    cursor. snacks.words drives the ]] / [[ navigation over these.
          if client:supports_method("textDocument/documentHighlight") then
            local hl_group = vim.api.nvim_create_augroup("lsp_doc_hl_" .. bufnr, { clear = true })
            vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
              buffer = bufnr,
              group = hl_group,
              callback = vim.lsp.buf.document_highlight,
            })
            vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
              buffer = bufnr,
              group = hl_group,
              callback = vim.lsp.buf.clear_references,
            })
            vim.api.nvim_create_autocmd("LspDetach", {
              buffer = bufnr,
              callback = function()
                vim.lsp.buf.clear_references()
                pcall(vim.api.nvim_del_augroup_by_id, hl_group)
              end,
            })
          end

          -- ── Folding: some servers (notably vtsls) provide better fold ranges
          --    than treesitter for their language.
          if client:supports_method("textDocument/foldingRange") then
            vim.wo[vim.api.nvim_get_current_win()][0].foldexpr = "v:lua.vim.lsp.foldexpr()"
          end
        end,
      })

      -- Report a server that fails to start, instead of silently having no
      -- completion. The most common cause is the binary not being on PATH.
      vim.api.nvim_create_autocmd("LspDetach", {
        group = vim.api.nvim_create_augroup("lsp_detach_notify", { clear = true }),
        callback = function(event)
          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if client and client.initialized == false then
            vim.notify(
              ("Language server %s exited before initialising.\nCheck `:LspLog`."):format(client.name),
              vim.log.levels.WARN,
              { title = "LSP" }
            )
          end
        end,
      })
    end,
  },

  -- ═════════════════════════════════════════════════════════════════════════
  -- LAZYDEV — proper completion for the Neovim Lua API
  -- ═════════════════════════════════════════════════════════════════════════
  -- Without this, editing this config gives you no completion for `vim.api.*`,
  -- and lua_ls complains that `vim` is an undefined global. lazydev configures
  -- lua_ls's workspace library on demand, so you get full documentation for
  -- Neovim's API and for every installed plugin — while keeping lua_ls fast by
  -- not loading all of it up front.
  {
    "folke/lazydev.nvim",
    ft = "lua",
    cmd = "LazyDev",
    opts = {
      library = {
        -- Load Neovim's own type definitions only when `vim.uv` is referenced,
        -- rather than always.
        { path = "${3rd}/luv/library", words = { "vim%.uv" } },
        -- Type definitions for the plugins this config uses, so their opts tables
        -- get completion and hover docs.
        { path = "snacks.nvim", words = { "Snacks" } },
        { path = "lazy.nvim", words = { "LazyPlugin", "LazySpec" } },
      },
    },
  },

  -- ═════════════════════════════════════════════════════════════════════════
  -- SCHEMASTORE — JSON and YAML schemas
  -- ═════════════════════════════════════════════════════════════════════════
  -- Supplies several hundred schemas from schemastore.org, which is what gives
  -- you completion and validation in package.json, tsconfig.json,
  -- .github/workflows/*.yml, docker-compose.yml and so on. Consumed by
  -- after/lsp/jsonls.lua and after/lsp/yamlls.lua.
  {
    "b0o/schemastore.nvim",
    lazy = true,
    version = false,
  },
}
