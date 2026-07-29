--- after/lsp/ruff.lua — Python linting, import sorting and formatting
---
--- ruff replaces flake8 + isort + pyupgrade + pydocstyle + black, is written in
--- Rust, and is fast enough to lint on every keystroke. It runs as a language
--- server here (rather than through nvim-lint) so it can offer its fixes as LSP
--- code actions on <leader>ca.
---
--- Project configuration in pyproject.toml or ruff.toml ALWAYS wins over the
--- settings below — which is what you want, so a shared repo's rules apply.
--- These are only the fallback for files with no project config.

return {
  init_options = {
    settings = {
      -- 88 columns, matching black's default and therefore most of the ecosystem.
      lineLength = 88,

      lint = {
        enable = true,
        -- A pragmatic starting set. `E`/`W` pycodestyle, `F` pyflakes (real bugs),
        -- `I` isort, `UP` pyupgrade, `B` bugbear, `SIM` simplify, `C4`
        -- comprehensions. Deliberately not the "select ALL" firehose.
        select = { "E", "W", "F", "I", "UP", "B", "SIM", "C4" },
        ignore = {
          "E501", -- line too long: the formatter handles length; a hard error on
          -- a long URL in a comment is pure noise
          "B008", -- function call in argument default: this is how FastAPI's
          -- Depends() is meant to be used
        },
      },

      format = {
        -- ruff's formatter is a black-compatible reimplementation. conform.nvim
        -- calls it on save (see lua/plugins/format.lua).
        preview = false,
      },

      -- Auto-fix everything safely fixable when a fix-all action runs.
      fixAll = true,
      organizeImports = true,
      -- Show the rule code ("F401") in the diagnostic message, so you can look it
      -- up or add it to `ignore` without guessing.
      showSyntaxErrors = true,
    },
  },

  --- Stop ruff answering requests basedpyright answers better.
  ---
  --- Both servers attach to every Python buffer. Without this, pressing `K` on a
  --- symbol gives you whichever server replied first — often ruff's empty hover
  --- instead of basedpyright's type signature and docstring. Disabling the
  --- capability on the client makes the choice deterministic.
  ---@param client vim.lsp.Client
  on_attach = function(client)
    client.server_capabilities.hoverProvider = false
    client.server_capabilities.definitionProvider = false
    client.server_capabilities.referencesProvider = false
    client.server_capabilities.documentSymbolProvider = false
  end,
}
