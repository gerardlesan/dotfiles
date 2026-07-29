--- after/lsp/jsonls.lua — JSON, with schema validation
---
--- The value here is entirely in the schemas. With schemastore.nvim supplying a
--- few hundred of them, opening package.json / tsconfig.json / .eslintrc gives you
--- key completion, hover documentation for each field, and validation of values —
--- turning JSON config from guesswork into something with autocomplete.

return {
  -- Neovim can only supply schemas once schemastore is loaded, and jsonls starts
  -- before plugins finish. `settings` as a FUNCTION is evaluated lazily at server
  -- start, which is what makes this work reliably.
  before_init = function(_, config)
    config.settings = config.settings or {}
    config.settings.json = vim.tbl_deep_extend("force", config.settings.json or {}, {
      schemas = require("schemastore").json.schemas(),
      validate = { enable = true },
      -- Complete keys as you type them, not just on demand.
      format = { enable = false }, -- prettier handles formatting
    })
  end,

  settings = {
    json = {
      validate = { enable = true },
    },
  },
}
