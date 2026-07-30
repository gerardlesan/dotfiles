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
--- TOOLCHAIN: rust_analyzer does NOT come from mason. Two routes, and on a
--- distro that packages Rust itself the distro route is the right one:
---
---   * Arch / CachyOS (and any distro shipping `rust`): install from the repos —
---         sudo pacman -S rust-analyzer rust-src
---     pacman's `rustup` CONFLICTS with its `rust` package, so if you already
---     have `rust` installed, `rustup component add` is not available to you.
---     `rust-src` depends on `rust`, which version-locks it to the installed
---     rustc — exactly what you want.
---
---   * Anywhere else (or if you manage toolchains per-project):
---         rustup component add rust-analyzer rust-src clippy rustfmt
---
--- `rust-src` matters either way — without it, go-to-definition into the
--- standard library lands nowhere. Arch's `rust` package does not ship it.
--- install.sh picks the distro route when the package manager provides it and
--- falls back to rustup.

return {
  -- ═════════════════════════════════════════════════════════════════════════
  -- RUSTACEANVIM
  -- ═════════════════════════════════════════════════════════════════════════
  {
    "mrcjkb/rustaceanvim",
    -- Pinned to a major because rustaceanvim releases breaking changes in major
    -- bumps and this config passes it a large `vim.g.rustaceanvim` table.
    --
    -- Was `^6` until 2026-07-30. v6.9.7 (the last v6, Nov 2025) calls
    -- `vim.lsp.get_buffers_by_client_id()` in `server_status.lua` — deprecated,
    -- removed in Neovim 0.13 — so every rust-analyzer attach logged a
    -- deprecation warning. Upstream fixed it in fe91aad, first released in
    -- v7.0.0, so no v6 ever gets the fix. Checked the three breaking changes
    -- between v6 and v9 against this config: v7 dropped ra-multiplex (lspmux
    -- instead), v8 dropped `.vscode/settings.json` reading, v9 dropped Neovim
    -- 0.11. This config uses none of them and needs 0.12+ anyway (§ treesitter
    -- main branch, native vim.lsp.config).
    version = "^9",
    -- Loads itself on Rust files; it is not a plugin you `setup()`. Configuration
    -- goes in the global `vim.g.rustaceanvim` table, which is unusual but
    -- deliberate — it lets a project-local .nvim.lua override it.
    --
    -- rustaceanvim's own docs say "do not lazy-load", and `lazy = false` used to
    -- be set here alongside `ft` — but `lazy = false` wins, so the `ft` line was
    -- dead and rustaceanvim loaded even when opening a Python file. The
    -- "do not lazy-load" advice exists because rustaceanvim installs its own
    -- FileType hook; since this spec's entire body is a `config` that assigns
    -- vim.g.rustaceanvim, `ft` is sufficient — lazy.nvim's own ft handler fires
    -- first, so the global is set before rustaceanvim looks at it. If
    -- rust_analyzer ever stops attaching, restore `lazy = false` and delete the
    -- `ft` line instead: correctness beats the fraction of a millisecond.
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
                -- Give rust-analyzer its OWN target directory
                -- (target/rust-analyzer). Without this, the `cargo clippy` below
                -- and your own `cargo build` share target/ with different flags,
                -- so each invocation evicts the other's fingerprints and every
                -- analysis becomes a near-full rebuild. This is the single
                -- biggest cause of "rust-analyzer takes forever every time" —
                -- with it, a re-analysis only recompiles what actually changed.
                -- Costs disk, saves minutes.
                targetDir = true,
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
                -- Check only the crate being edited, not every crate in the
                -- workspace. On a multi-crate workspace the difference is the
                -- whole point: you get diagnostics for the file in front of you
                -- without paying to re-check unrelated crates on every save.
                workspace = false,
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
                -- Let rust-analyzer watch the filesystem itself instead of
                -- asking the editor to. The default is "client", which routes
                -- file watching through Neovim's vim._watch — and with no
                -- fswatch/inotifywait binary present that falls back to a libuv
                -- recursive poll implemented in Lua, which walks target/ on a
                -- Rust project. The server's own watcher is native and
                -- target/-aware. See the didChangeWatchedFiles note in
                -- lua/plugins/lsp.lua: that capability stays advertised
                -- to every server (vtsls needs it), and this is what takes
                -- rust-analyzer off that path.
                watcher = "server",
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

  -- NO treesitter spec here. `rust` and `toml` live in the `rust` entry of the
  -- `parser_groups` table in lua/plugins/treesitter.lua, which is the one place
  -- parsers are declared. A second `optional = true` nvim-treesitter spec in
  -- this file used to re-install them: lazy.nvim runs every merged `opts`
  -- function, so three lang/ files each calling install() made
  -- nvim-treesitter.parsers load seven times at startup for no benefit — and it
  -- meant two places to edit for one concern. Add parsers to `parser_groups`.
}
