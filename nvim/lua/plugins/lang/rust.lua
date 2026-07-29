--- ~/.config/nvim/lua/plugins/lang/rust.lua
---
--- RUST. rustaceanvim is the de-facto Rust setup for Neovim (it superseded the
--- unmaintained rust-tools.nvim) and it does something unusual: it configures
--- rust_analyzer ITSELF, so you must NOT also enable rust_analyzer through
--- nvim-lspconfig. Doing both starts two clients that fight over the same buffer,
--- producing duplicated diagnostics and broken code actions. That exclusion is
--- handled in lua/plugins/lsp.lua — see the `automatic_enable.exclude` entry and
--- the note where rust_analyzer is conspicuously missing from `servers`.
---
--- What rustaceanvim adds over a plain LSP setup:
---   * runnables / testables — run the exact test or binary under the cursor,
---     with the right cargo invocation, via <leader>rr
---   * macro expansion — see what a derive or macro_rules! actually generates
---   * "open Cargo.toml", "parent module", "join lines" (Rust-aware)
---   * a neotest adapter that understands cargo workspaces and doc-tests
---   * correct handling of proc-macro and build-script errors
---
--- TOOLCHAIN: rust_analyzer comes from rustup, not mason:
---     rustup component add rust-analyzer rust-src clippy rustfmt
--- `rust-src` matters — without it, go-to-definition into the standard library
--- lands nowhere. The install scripts add all four.

return {
  -- ═════════════════════════════════════════════════════════════════════════
  -- RUSTACEANVIM
  -- ═════════════════════════════════════════════════════════════════════════
  {
    "mrcjkb/rustaceanvim",
    version = "^6",
    -- Loads itself on Rust files; it is not a plugin you `setup()`. Configuration
    -- goes in the global `vim.g.rustaceanvim` table, which is unusual but
    -- deliberate — it lets a project-local .nvim.lua override it.
    lazy = false,
    ft = { "rust" },

    config = function()
      vim.g.rustaceanvim = {
        -- ── Editor-level tools ────────────────────────────────────────────
        tools = {
          -- Show inlay hints for chained method calls, which is where Rust's
          -- type inference is least obvious.
          hover_actions = { replace_builtin_hover = true },
          float_win_config = {
            border = require("config.palette").border,
          },
          -- Use the picker for the runnables/testables list rather than a
          -- numbered prompt on the command line.
          executor = "termopen",
          test_executor = "background",
        },

        -- ── rust_analyzer ─────────────────────────────────────────────────
        server = {
          -- Called when rust_analyzer attaches to a Rust buffer. The generic
          -- LspAttach handler in lua/plugins/lsp.lua also runs, so `gd`, `gr`,
          -- `K`, `<leader>ca` etc. are already mapped — this only adds the
          -- Rust-specific extras.
          on_attach = function(_, bufnr)
            local function map(keys, cmd, desc)
              vim.keymap.set("n", keys, cmd, { buffer = bufnr, desc = "Rust: " .. desc })
            end

            -- Run or test whatever is under the cursor. rustaceanvim figures out
            -- the correct `cargo run --bin x` / `cargo test path::to::test`.
            map("<leader>rr", function()
              vim.cmd.RustLsp("runnables")
            end, "Runnables")
            map("<leader>rR", function()
              vim.cmd.RustLsp({ "runnables", bang = true })
            end, "Re-run last runnable")
            map("<leader>rd", function()
              vim.cmd.RustLsp("debuggables")
            end, "Debuggables (needs nvim-dap)")

            -- See what a macro expands to. Invaluable with derive macros, and the
            -- single feature people miss most when moving from an IDE.
            map("<leader>rm", function()
              vim.cmd.RustLsp("expandMacro")
            end, "Expand macro")

            -- Explain the error under the cursor in full, including the long-form
            -- rustc explanation (`rustc --explain E0499`).
            map("<leader>re", function()
              vim.cmd.RustLsp("explainError")
            end, "Explain error")
            map("<leader>rD", function()
              vim.cmd.RustLsp("renderDiagnostic")
            end, "Render diagnostic (full)")

            -- Navigate the module tree.
            map("<leader>rp", function()
              vim.cmd.RustLsp("parentModule")
            end, "Go to parent module")
            map("<leader>rc", function()
              vim.cmd.RustLsp("openCargo")
            end, "Open Cargo.toml")
            -- `ro` not `rD`: <leader>rD is already the full diagnostic renderer
            -- above, and a key mapped twice silently keeps only the last one.
            map("<leader>ro", function()
              vim.cmd.RustLsp("openDocs")
            end, "Open docs.rs for symbol")

            -- Rust-aware join: merges lines and fixes up trailing commas and
            -- braces, unlike plain `J`.
            map("<leader>rj", function()
              vim.cmd.RustLsp("joinLines")
            end, "Join lines (Rust-aware)")

            -- Move an item up/down past its sibling, keeping syntax valid.
            map("<leader>rk", function()
              vim.cmd.RustLsp({ "moveItem", "up" })
            end, "Move item up")
            map("<leader>rJ", function()
              vim.cmd.RustLsp({ "moveItem", "down" })
            end, "Move item down")

            -- Hover actions: like `K`, but the popup's entries are actionable
            -- (jump to impl, open docs, view full type).
            map("K", function()
              vim.cmd.RustLsp({ "hover", "actions" })
            end, "Hover with actions")
          end,

          default_settings = {
            ["rust-analyzer"] = {
              -- ── Cargo ───────────────────────────────────────────────────
              cargo = {
                -- Enable all features by default, so code behind a feature flag
                -- still gets analysed rather than appearing dead.
                allFeatures = true,
                loadOutDirsFromCheck = true,
                -- Analyse build scripts, so generated code resolves.
                buildScripts = { enable = true },
              },

              -- ── Diagnostics: use clippy, not just cargo check ───────────
              -- This is the highest-value setting in the file. clippy's lints
              -- catch idiom and correctness problems that `cargo check` does not,
              -- and running it as the check command means you see them as you
              -- type instead of in CI.
              check = {
                command = "clippy",
                extraArgs = { "--no-deps" }, -- do not lint dependencies: much faster
                allTargets = true, -- include tests and benches
              },

              -- ── Inlay hints ─────────────────────────────────────────────
              -- Rust infers almost every type, so hints are how you see them.
              inlayHints = {
                bindingModeHints = { enable = false },
                closureReturnTypeHints = { enable = "with_block" },
                chainingHints = { enable = true },
                parameterHints = { enable = true },
                typeHints = { enable = true },
                -- Show `.into()` / deref coercions that are happening implicitly.
                reborrowHints = { enable = "mutable" },
                lifetimeElisionHints = { enable = "skip_trivial", useParameterNames = false },
                maxLength = 30,
              },

              -- ── Completion ──────────────────────────────────────────────
              completion = {
                -- Offer methods and traits that are not yet imported, and add the
                -- `use` line on accept. The Rust equivalent of auto-import.
                autoimport = { enable = true },
                postfix = { enable = true }, -- `expr.ok` -> `Ok(expr)`
                callable = { snippets = "fill_arguments" },
                -- Suggest private items in the same crate.
                privateEditable = { enable = true },
              },

              -- ── Procedural macros ───────────────────────────────────────
              procMacro = {
                enable = true,
                -- These macros are known to be slow or to crash the analyser and
                -- provide no useful completion, so skip expanding them.
                ignored = {
                  ["async-trait"] = { "async_trait" },
                  ["napi-derive"] = { "napi" },
                  ["async-recursion"] = { "async_recursion" },
                },
              },

              -- ── Misc quality of life ────────────────────────────────────
              -- Show "N implementations" / "N references" above items.
              lens = {
                enable = true,
                implementations = { enable = true },
                references = { adt = { enable = true }, trait = { enable = true } },
              },
              -- Highlight the whole `match` when the cursor is on an arm, etc.
              semanticHighlighting = {
                operator = { specialization = { enable = true } },
                punctuation = { enable = false },
              },
              -- Do not warn about unlinked files in a workspace; instead offer to
              -- add them to the module tree.
              files = {
                excludeDirs = { ".git", "target", ".venv", "node_modules" },
              },
              -- Rust 2024 `gen` blocks and other unstable syntax.
              diagnostics = {
                enable = true,
                experimental = { enable = false }, -- experimental lints are noisy
                disabled = { "unlinked-file" },
              },
            },
          },
        },

        -- ── DAP ────────────────────────────────────────────────────────────
        -- Debugging is not installed (you opted out), but rustaceanvim will pick
        -- up codelldb automatically if you later add nvim-dap and install codelldb
        -- through mason. <leader>rd is already mapped above and will start working
        -- at that point. See docs/ADDING-A-LANGUAGE.md.
        dap = {},
      }
    end,
  },

  -- ═════════════════════════════════════════════════════════════════════════
  -- CRATES.NVIM — dependency management inside Cargo.toml
  -- ═════════════════════════════════════════════════════════════════════════
  -- Shows the latest available version next to each dependency, warns when yours
  -- is outdated, completes crate names and versions, and opens a crate's docs or
  -- repository. Turns Cargo.toml from a file you edit blind into one with
  -- autocomplete.
  {
    "Saecki/crates.nvim",
    event = { "BufRead Cargo.toml" },
    opts = {
      completion = {
        -- Feed crate names and versions into blink.cmp, so <C-space> in
        -- Cargo.toml completes from crates.io.
        crates = { enabled = true, max_results = 20, min_chars = 2 },
      },
      lsp = {
        -- Expose crates.nvim's features as a language server, so hover, code
        -- actions ("upgrade to 1.2.3") and completion all work through the normal
        -- LSP keymaps rather than plugin-specific ones.
        enabled = true,
        on_attach = function(_, bufnr)
          local crates = require("crates")
          local function map(keys, fn, desc)
            vim.keymap.set("n", keys, fn, { buffer = bufnr, desc = "Crates: " .. desc })
          end
          map("<leader>rt", crates.toggle, "Toggle crates info")
          map("<leader>ru", crates.upgrade_crate, "Upgrade crate")
          map("<leader>rU", crates.upgrade_all_crates, "Upgrade all crates")
          map("<leader>rv", crates.show_versions_popup, "Show versions")
          map("<leader>rf", crates.show_features_popup, "Show features")
          map("<leader>ro", crates.open_documentation, "Open documentation")
          map("<leader>rH", crates.open_homepage, "Open homepage")
          map("<leader>rC", crates.open_crates_io, "Open crates.io")
        end,
        actions = true,
        completion = true,
        hover = true,
      },
    },
  },

  -- ═════════════════════════════════════════════════════════════════════════
  -- NEOTEST ADAPTER
  -- ═════════════════════════════════════════════════════════════════════════
  -- rustaceanvim ships its own neotest adapter rather than there being a separate
  -- neotest-rust package. Appending it here (rather than in lua/plugins/test.lua)
  -- keeps everything Rust in one file — lazy.nvim merges the two specs.
  {
    "nvim-neotest/neotest",
    optional = true, -- do not pull neotest in if it is ever removed
    opts = function(_, opts)
      opts.adapters = opts.adapters or {}
      table.insert(opts.adapters, require("rustaceanvim.neotest"))
    end,
  },

  -- Make sure the Rust parser is present even if someone trims the treesitter
  -- list. lazy.nvim merges this into the treesitter spec.
  {
    "nvim-treesitter/nvim-treesitter",
    optional = true,
    opts = function()
      -- The main branch has no `ensure_installed` option, so parsers are
      -- installed imperatively. Safe to call repeatedly: already-present parsers
      -- are skipped.
      if vim.fn.executable("tree-sitter") == 1 then
        pcall(function()
          require("nvim-treesitter").install({ "rust", "toml" })
        end)
      end
    end,
  },
}
