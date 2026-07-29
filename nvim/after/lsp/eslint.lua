--- after/lsp/eslint.lua — JavaScript/TypeScript linting
---
--- eslint runs as its own language server so its rules appear as diagnostics and
--- its fixes as code actions. It only attaches when the project actually has an
--- eslint config, so this is inert in a project that does not use it.
---
--- NOT a formatter here: prettier does formatting through conform.nvim. If your
--- project uses eslint-plugin-prettier (formatting *via* eslint rules), set
--- `format = true` below and remove prettier from lua/plugins/format.lua for
--- these filetypes — otherwise the two fight on every save.

return {
  settings = {
    -- Let eslint fix what it can on an explicit `:EslintFixAll`, but do not
    -- reformat the whole document.
    format = false,

    -- Use the project's flat config (eslint.config.js) when present. eslint 9+
    -- defaults to flat config; older projects use .eslintrc.
    experimental = { useFlatConfig = false },

    -- Run the linter as you type rather than only on save.
    run = "onType",

    -- Show the rule name in the diagnostic, so you can disable it precisely.
    problems = { shortenToSingleLine = false },

    -- Where to look for the eslint install. "node_modules" keeps it project-local,
    -- which is almost always what you want — a globally installed eslint will
    -- disagree with the project's plugins.
    nodePath = "",
    workingDirectories = { mode = "auto" },

    codeAction = {
      disableRuleComment = { enable = true, location = "separateLine" },
      showDocumentation = { enable = true },
    },
  },

  ---@param client vim.lsp.Client
  ---@param bufnr integer
  on_attach = function(client, bufnr)
    vim.keymap.set("n", "<leader>ce", "<cmd>EslintFixAll<cr>", {
      buffer = bufnr,
      desc = "ESLint: fix all auto-fixable problems",
    })
  end,
}
