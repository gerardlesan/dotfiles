--- ~/.config/nvim/lua/plugins/format.lua
---
--- FORMATTING via conform.nvim.
---
--- Why a dedicated formatter plugin rather than the LSP's own formatting:
---   * you often want a formatter the language server does not provide (prettier
---     for TypeScript, stylua for Lua, ruff for Python)
---   * you sometimes want to CHAIN them (ruff import-sort, then ruff format)
---   * format-on-save needs a per-buffer and global off switch, which raw
---     `vim.lsp.buf.format()` in an autocmd does not give you
---
--- Format-on-save is ON. Turn it off for the current buffer with <leader>uf, or
--- globally with <leader>uF — both survive as long as the session does. That
--- matters when a repo's checked-in formatter config disagrees with what the
--- project actually has committed, and reformatting would produce a 400-line diff.

return {
  {
    "stevearc/conform.nvim",
    dependencies = { "mason-org/mason.nvim" },
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },

    keys = {
      {
        "<leader>cf",
        function()
          require("conform").format({ async = true, lsp_format = "fallback" })
        end,
        mode = { "n", "v" },
        desc = "Format buffer / selection",
      },
      {
        "<leader>cF",
        function()
          -- Format with the LSP explicitly, bypassing conform's formatters. Useful
          -- to compare, or when a formatter is misbehaving.
          vim.lsp.buf.format({ async = true })
        end,
        mode = { "n", "v" },
        desc = "Format with LSP only",
      },
      { "<leader>cI", "<cmd>ConformInfo<cr>", desc = "Formatter info for this buffer" },
    },

    init = function()
      -- Route `gq` through conform, so the standard Vim "format this range"
      -- operator uses the real formatter.
      vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"

      -- ── Format-on-save toggles ────────────────────────────────────────────
      -- Registered in `init`, NOT in `config`, deliberately.
      --
      -- This plugin is lazy-loaded on BufWritePre, so `config` does not run until
      -- the first time you save a file — which meant <leader>uf did not exist for
      -- most of a session, and pressing it silently did nothing. `init` runs during
      -- startup for every plugin regardless of lazy state, and these toggles only
      -- flip a `vim.b`/`vim.g` flag that `format_on_save` below reads, so they need
      -- nothing from conform itself.
      vim.api.nvim_create_autocmd("User", {
        pattern = "VeryLazy",
        callback = function()
          Snacks.toggle
            .new({
              id = "autoformat_buffer",
              name = "Format on Save (buffer)",
              get = function()
                return not (vim.b.disable_autoformat or vim.g.disable_autoformat)
              end,
              set = function(state)
                vim.b.disable_autoformat = not state
              end,
            })
            :map("<leader>uf")

          Snacks.toggle
            .new({
              id = "autoformat_global",
              name = "Format on Save (global)",
              get = function()
                return not vim.g.disable_autoformat
              end,
              set = function(state)
                vim.g.disable_autoformat = not state
                -- Clear any per-buffer override so the global setting actually
                -- takes effect everywhere.
                vim.b.disable_autoformat = nil
              end,
            })
            :map("<leader>uF")
        end,
      })
    end,

    opts = {
      -- ── Which formatter runs for which filetype ──────────────────────────
      -- A LIST runs every entry in order (a pipeline).
      -- A nested list `{ { "a", "b" } }` means "first one that is installed".
      formatters_by_ft = {
        lua = { "stylua" },

        -- ruff twice, deliberately, in this order:
        --   ruff_organize_imports  sorts and dedupes imports (isort's job)
        --   ruff_format            reformats the code (black's job)
        -- Running format first would reformat imports that are about to be
        -- reordered, doing the work twice.
        python = { "ruff_organize_imports", "ruff_format" },

        -- prettierd is a long-running daemon version of prettier: same output,
        -- roughly 10x faster on save because it avoids Node startup each time.
        -- Falls back to plain prettier if the daemon is not installed.
        javascript = { "prettierd", "prettier", stop_after_first = true },
        javascriptreact = { "prettierd", "prettier", stop_after_first = true },
        typescript = { "prettierd", "prettier", stop_after_first = true },
        typescriptreact = { "prettierd", "prettier", stop_after_first = true },
        json = { "prettierd", "prettier", stop_after_first = true },
        jsonc = { "prettierd", "prettier", stop_after_first = true },
        yaml = { "prettierd", "prettier", stop_after_first = true },
        html = { "prettierd", "prettier", stop_after_first = true },
        css = { "prettierd", "prettier", stop_after_first = true },
        scss = { "prettierd", "prettier", stop_after_first = true },
        markdown = { "prettierd", "prettier", stop_after_first = true },

        -- Rust: rustfmt comes from rustup, not mason. rustaceanvim also exposes
        -- rust-analyzer's own formatting; conform is used so <leader>cf behaves
        -- identically in every language.
        rust = { "rustfmt" },

        sh = { "shfmt" },
        bash = { "shfmt" },
        toml = { "taplo" },

        -- Applied to EVERY filetype, including those with no formatter above.
        -- `trim_whitespace` here is safe in a way a blanket BufWritePre autocmd is
        -- not, because conform only rewrites the buffer when you asked it to
        -- format — it will not silently touch a file you merely opened and saved.
        ["_"] = { "trim_whitespace", "trim_newlines" },
      },

      -- ── Format on save ───────────────────────────────────────────────────
      -- A function rather than a table, so the toggles below can veto it.
      format_on_save = function(bufnr)
        -- Global and per-buffer opt-out, set by <leader>uF and <leader>uf.
        if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
          return
        end

        -- Never reformat a file you do not own. Nothing good comes from
        -- reformatting a dependency you are only reading.
        local path = vim.api.nvim_buf_get_name(bufnr)
        for _, pattern in ipairs({ "/node_modules/", "/%.venv/", "/target/", "/site%-packages/" }) do
          if path:find(pattern) then
            return
          end
        end

        return {
          timeout_ms = 1000,
          -- Fall back to the language server's formatter when no conform formatter
          -- is configured for this filetype. Means "format on save" works for a
          -- new language before you have set up a formatter for it.
          lsp_format = "fallback",
        }
      end,

      -- Show a message when a formatter is configured but its binary is missing,
      -- instead of silently not formatting.
      notify_on_error = true,
      notify_no_formatters = true,

      formatters = {
        shfmt = {
          -- 2-space indent, and indent case statements, matching Google's shell
          -- style guide. Without args, shfmt defaults to tabs.
          prepend_args = { "-i", "2", "-ci", "-bn" },
        },
        stylua = {
          -- stylua reads .stylua.toml from the project. This repo ships one so the
          -- config formats consistently on both machines.
          prepend_args = { "--indent-type", "Spaces", "--indent-width", "2" },
        },
        injected = {
          -- Formats embedded code blocks — a Python block inside a markdown file,
          -- SQL inside a Python string. Enabled below for markdown.
          options = { ignore_errors = true },
        },
      },
    },

    config = function(_, opts)
      require("conform").setup(opts)

      -- The <leader>uf / <leader>uF toggles are registered in `init` above, so they
      -- exist from startup rather than only after the first save.

      -- `:Format` / `:FormatDisable` / `:FormatEnable` for when you would rather
      -- type than remember a keybinding.
      vim.api.nvim_create_user_command("Format", function(args)
        local range = nil
        if args.count ~= -1 then
          -- Support `:'<,'>Format` on a visual selection.
          local end_line = vim.api.nvim_buf_get_lines(0, args.line2 - 1, args.line2, true)[1]
          range = {
            start = { args.line1, 0 },
            ["end"] = { args.line2, end_line:len() },
          }
        end
        require("conform").format({ async = true, lsp_format = "fallback", range = range })
      end, { range = true, desc = "Format buffer or range" })

      vim.api.nvim_create_user_command("FormatDisable", function(args)
        if args.bang then
          vim.b.disable_autoformat = true
        else
          vim.g.disable_autoformat = true
        end
      end, {
        desc = "Disable format-on-save (! for this buffer only)",
        bang = true,
      })

      vim.api.nvim_create_user_command("FormatEnable", function()
        vim.b.disable_autoformat = false
        vim.g.disable_autoformat = false
      end, { desc = "Re-enable format-on-save" })
    end,
  },
}
