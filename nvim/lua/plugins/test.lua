--- ~/.config/nvim/lua/plugins/test.lua
---
--- TEST RUNNER. neotest gives you the IDE test experience: run a single test with
--- the cursor in it, see pass/fail as a sign in the gutter, read the failure output
--- without leaving the editor, and browse the whole suite in a tree.
---
--- neotest itself knows nothing about any test framework — ADAPTERS do. One per
--- ecosystem, listed below. Adding a language's tests means adding its adapter
--- here; see docs/ADDING-A-LANGUAGE.md.
---
---   <leader>tr   run the nearest test          <leader>ts  toggle the suite tree
---   <leader>tf   run every test in this file   <leader>to  show output for the
---   <leader>tA   run the whole suite                       test under the cursor
---   <leader>tl   re-run the last test          <leader>tO  toggle the output panel
---   <leader>tw   watch mode: re-run on save    <leader>tS  stop a running test
---
--- Rust tests are handled by rustaceanvim's own adapter, which understands cargo
--- workspaces, `#[test]`, `#[tokio::test]` and doc-tests — see
--- lua/plugins/lang/rust.lua.

local P = require("config.palette")
local icons = P.icons

return {
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter", -- adapters locate tests via treesitter
      "nvim-neotest/nvim-nio", -- async library neotest is built on
      "antoinemadec/FixCursorHold.nvim", -- works around a CursorHold performance bug

      -- ── Adapters ───────────────────────────────────────────────────────────
      "nvim-neotest/neotest-python",
      "marilari88/neotest-vitest",
      "nvim-neotest/neotest-jest",
    },

    keys = {
      {
        "<leader>tr",
        function()
          require("neotest").run.run()
        end,
        desc = "Test: run nearest",
      },
      {
        "<leader>tf",
        function()
          require("neotest").run.run(vim.fn.expand("%"))
        end,
        desc = "Test: run this file",
      },
      {
        "<leader>tA",
        function()
          require("neotest").run.run(vim.uv.cwd())
        end,
        desc = "Test: run whole suite",
      },
      {
        "<leader>tl",
        function()
          require("neotest").run.run_last()
        end,
        desc = "Test: re-run last",
      },
      {
        "<leader>ts",
        function()
          require("neotest").summary.toggle()
        end,
        desc = "Test: toggle suite tree",
      },
      {
        "<leader>to",
        function()
          require("neotest").output.open({ enter = true, auto_close = true })
        end,
        desc = "Test: show output",
      },
      {
        "<leader>tO",
        function()
          require("neotest").output_panel.toggle()
        end,
        desc = "Test: toggle output panel",
      },
      {
        "<leader>tS",
        function()
          require("neotest").run.stop()
        end,
        desc = "Test: stop running",
      },
      {
        -- Watch mode re-runs the affected tests every time you save. The tightest
        -- feedback loop available, and the main reason to use neotest over a
        -- terminal.
        "<leader>tw",
        function()
          require("neotest").watch.toggle(vim.fn.expand("%"))
        end,
        desc = "Test: toggle watch mode (this file)",
      },
      {
        "<leader>tW",
        function()
          require("neotest").watch.toggle()
        end,
        desc = "Test: toggle watch mode (nearest)",
      },
      -- Jump between failing tests, matching the ]x convention.
      {
        "]T",
        function()
          require("neotest").jump.next({ status = "failed" })
        end,
        desc = "Test: next failed",
      },
      {
        "[T",
        function()
          require("neotest").jump.prev({ status = "failed" })
        end,
        desc = "Test: previous failed",
      },
    },

    opts = function()
      return {
        adapters = {
          -- ── Python ────────────────────────────────────────────────────────
          require("neotest-python")({
            -- Let the adapter pick the runner from the project: it prefers pytest
            -- when available and falls back to unittest.
            runner = "pytest",
            -- Resolve the interpreter per project. Checks $VIRTUAL_ENV, then
            -- .venv/venv beside the project root, then falls back to `python`.
            -- This is what makes tests work without activating a venv first.
            python = function(root)
              for _, candidate in ipairs({
                root .. "/.venv/bin/python",
                root .. "/.venv/Scripts/python.exe", -- Windows venv layout
                root .. "/venv/bin/python",
                root .. "/venv/Scripts/python.exe",
              }) do
                if vim.fn.executable(candidate) == 1 then
                  return candidate
                end
              end
              return vim.fn.exepath("python3") ~= "" and "python3" or "python"
            end,
            args = { "--log-level", "DEBUG", "--color=no" },
            -- Treat every test file as its own module, avoiding import errors in
            -- projects without __init__.py everywhere.
            is_test_file = function(file)
              return file:match("test_.*%.py$") or file:match(".*_test%.py$")
            end,
          }),

          -- ── Vitest (the modern default for TS/JS) ──────────────────────────
          require("neotest-vitest")({
            -- Only attach in projects that actually use vitest, so a jest project
            -- does not get two adapters fighting over the same files.
            is_test_file = function(file)
              if not (file:match("%.test%.[jt]sx?$") or file:match("%.spec%.[jt]sx?$")) then
                return false
              end
              -- Look for a vitest config anywhere up the tree.
              local found = vim.fs.find(
                { "vitest.config.ts", "vitest.config.js", "vite.config.ts", "vite.config.js" },
                { upward = true, path = vim.fs.dirname(file) }
              )
              return #found > 0
            end,
          }),

          -- ── Jest (still everywhere in existing codebases) ──────────────────
          require("neotest-jest")({
            jestCommand = "npm test --",
            -- Run from the directory containing package.json, which is what jest
            -- expects — important in a monorepo.
            cwd = function(path)
              local found = vim.fs.find({ "package.json" }, { upward = true, path = vim.fs.dirname(path) })
              return found[1] and vim.fs.dirname(found[1]) or vim.uv.cwd()
            end,
            is_test_file = function(file)
              if not (file:match("%.test%.[jt]sx?$") or file:match("%.spec%.[jt]sx?$")) then
                return false
              end
              local found = vim.fs.find(
                { "jest.config.js", "jest.config.ts", "jest.config.mjs" },
                { upward = true, path = vim.fs.dirname(file) }
              )
              return #found > 0
            end,
          }),

          -- ── Rust ──────────────────────────────────────────────────────────
          -- Added by lua/plugins/lang/rust.lua, because it comes from
          -- rustaceanvim rather than a standalone adapter package.
        },

        -- ── Appearance ────────────────────────────────────────────────────────
        icons = {
          passed = "\u{f00c}",
          failed = "\u{f00d}",
          running = "\u{f110}",
          skipped = "\u{f068}",
          unknown = "\u{f059}",
          running_animated = { "\u{2807}", "\u{280b}", "\u{2819}", "\u{2838}", "\u{2834}", "\u{2826}" },
          -- Tree structure in the summary panel
          child_indent = "\u{2502}",
          child_prefix = "\u{251c}",
          final_child_prefix = "\u{2570}",
          final_child_indent = " ",
          non_collapsible = "\u{2500}",
          collapsed = "\u{25b8}",
          expanded = "\u{25be}",
          watching = "\u{f0f3}",
        },

        -- Show pass/fail as a sign in the gutter next to each test.
        status = { virtual_text = true, signs = true },

        -- Show the failure message inline at the failing assertion. This is the
        -- feature that removes the need to read a terminal at all.
        output = { open_on_run = false, enter = true },
        output_panel = { enabled = true, open = "botright split | resize 15" },

        quickfix = {
          -- Do not hijack the quickfix list on every run; the summary panel and
          -- inline signs are better, and the quickfix list is wanted for other things.
          enabled = false,
          open = false,
        },

        summary = {
          enabled = true,
          animated = true,
          follow = true,
          expand_errors = true,
          open = "botright vsplit | vertical resize 50",
          mappings = {
            expand = { "<CR>", "<2-LeftMouse>" },
            expand_all = "L",
            output = "o",
            short = "O",
            run = "r",
            run_marked = "R",
            stop = "u",
            jumpto = "i",
            watch = "w",
            mark = "m",
            next_failed = "J",
            prev_failed = "K",
          },
        },

        floating = {
          border = P.border,
          max_height = 0.8,
          max_width = 0.8,
        },

        -- Discover tests lazily rather than scanning the whole project at
        -- startup. On a large repo, eager discovery is a multi-second freeze.
        discovery = { enabled = false, concurrent = 1 },
        running = { concurrent = true },
      }
    end,

    config = function(_, opts)
      -- Route neotest's diagnostic output (inline failure messages) through
      -- vim.diagnostic, so it uses the same signs and virtual text as everything
      -- else and respects <leader>uD.
      local neotest_ns = vim.api.nvim_create_namespace("neotest")
      vim.diagnostic.config({
        virtual_text = {
          format = function(diagnostic)
            -- Collapse a multi-line assertion failure to one line for the inline
            -- display; the full text is still available in the output panel.
            return (diagnostic.message or ""):gsub("\n", " "):gsub("%s+", " "):sub(1, 120)
          end,
        },
      }, neotest_ns)

      require("neotest").setup(opts)

      -- `q` closes the output float, matching every other utility window.
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "neotest-output", "neotest-output-panel", "neotest-summary" },
        callback = function(event)
          vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = event.buf, silent = true })
        end,
      })
    end,
  },
}
