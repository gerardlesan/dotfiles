--- after/lsp/yamlls.lua — YAML, with schema validation
---
--- Most valuable in .github/workflows (full GitHub Actions completion),
--- docker-compose.yml, and Kubernetes manifests. Without a schema, YAML editing is
--- entirely from memory.

return {
  before_init = function(_, config)
    config.settings = config.settings or {}
    config.settings.yaml = vim.tbl_deep_extend("force", config.settings.yaml or {}, {
      schemaStore = {
        -- Disable yamlls' own bundled schema store in favour of schemastore.nvim,
        -- which is kept far more current. Enabling both makes the server fetch the
        -- catalogue over the network on every start.
        enable = false,
        url = "",
      },
      schemas = require("schemastore").yaml.schemas(),
    })
  end,

  settings = {
    -- Neovim's YAML client needs this to report the schema in use, which is what
    -- makes "why is this key not completing" debuggable.
    redhat = { telemetry = { enabled = false } },

    yaml = {
      validate = true,
      -- Show which schema matched, in the hover.
      hover = true,
      completion = true,
      -- Keep the document formatter off; prettier handles YAML.
      format = { enable = false },
      -- Helm templates and Ansible use non-standard YAML that the validator
      -- reports as broken. Ignore those paths rather than living with red files.
      customTags = {
        "!reference sequence", -- GitLab CI
        "!Ref", "!GetAtt", "!Sub", "!Join", "!Select", -- CloudFormation
      },
    },
  },
}
