--- ~/.config/nvim/lua/plugins/lint.lua
---
--- LINTING for tools that are NOT language servers.
---
--- Most linting in this config already arrives through the LSP: ruff lints Python,
--- eslint lints TypeScript, and both report as ordinary diagnostics with code
--- actions. nvim-lint fills the remaining gap — standalone command-line linters
--- with no LSP wrapper, which it runs on save and converts into diagnostics.
---
--- So this file is intentionally short. If you are adding a language and its
--- linter has an LSP (most do now), prefer `after/lsp/<name>.lua`; only come here
--- when it does not.

return {
  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPost", "BufNewFile", "BufWritePost" },

    opts = {
      -- Milliseconds of idle before linting on text change. Only used by the
      -- InsertLeave/TextChanged trigger below.
      events = { "BufWritePost", "BufReadPost", "InsertLeave" },

      linters_by_ft = {
        -- Shell: shellcheck catches real bugs (unquoted variables, `[` vs `[[`)
        -- that no formatter will. bashls does invoke shellcheck itself when it can
        -- find it, but running it here means it works for `sh` files too and the
        -- version is the one mason installed.
        sh = { "shellcheck" },
        bash = { "shellcheck" },

        -- Markdown style: heading levels, list consistency, line length.
        markdown = { "markdownlint-cli2" },

        -- ── Deliberately NOT listed, because an LSP already covers them ────
        -- python           → ruff, via after/lsp/ruff.lua
        -- typescript, tsx  → eslint, via after/lsp/eslint.lua
        -- lua              → lua_ls diagnostics
        -- json, yaml       → schema validation via jsonls / yamlls
        -- rust             → clippy, via rustaceanvim (lua/plugins/lang/rust.lua)
        --
        -- Adding one of these here would double-report every problem.
      },

      -- Per-linter overrides.
      linters = {
        -- Do not fail on the "shell not specified" warning for files without a
        -- shebang; assume bash, which is what almost everything is.
        shellcheck = {
          args = { "--format=json", "--external-sources", "--shell=bash", "-" },
        },
      },
    },

    config = function(_, opts)
      local lint = require("lint")

      lint.linters_by_ft = opts.linters_by_ft

      for name, override in pairs(opts.linters or {}) do
        if type(override) == "table" and lint.linters[name] then
          lint.linters[name] = vim.tbl_deep_extend("force", lint.linters[name], override)
        end
      end

      --- Run only the linters whose executable actually exists, so a machine
      --- missing shellcheck gets no diagnostics rather than an error popup on
      --- every save. This is the main thing people add by hand to nvim-lint.
      local function debounced_lint()
        local names = lint._resolve_linter_by_ft(vim.bo.filetype)
        names = vim.list_extend({}, names)

        -- Fall back to any linter registered for all filetypes.
        vim.list_extend(names, lint.linters_by_ft["_"] or {})

        local runnable = {}
        for _, name in ipairs(names) do
          local linter = lint.linters[name]
          if linter then
            local cmd = type(linter) == "table" and linter.cmd or nil
            -- mason puts its binaries on Neovim's PATH, so `executable()` finds
            -- them without special handling.
            if not cmd or vim.fn.executable(cmd) == 1 then
              table.insert(runnable, name)
            end
          end
        end

        if #runnable > 0 then
          lint.try_lint(runnable)
        end
      end

      -- Debounce so linting does not fire on every keystroke in insert mode.
      local timer = assert(vim.uv.new_timer())
      local DEBOUNCE_MS = 200

      vim.api.nvim_create_autocmd(opts.events, {
        group = vim.api.nvim_create_augroup("nvim_lint", { clear = true }),
        desc = "Run linters for this filetype",
        callback = function()
          timer:stop()
          timer:start(DEBOUNCE_MS, 0, vim.schedule_wrap(debounced_lint))
        end,
      })

      -- Manual trigger, for when you want to re-lint without saving.
      vim.api.nvim_create_user_command("Lint", debounced_lint, {
        desc = "Run the linters for this buffer now",
      })
      vim.keymap.set("n", "<leader>cL", debounced_lint, { desc = "Run linters now" })
    end,
  },
}
