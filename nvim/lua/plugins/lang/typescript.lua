--- ~/.config/nvim/lua/plugins/lang/typescript.lua
---
--- TYPESCRIPT / JAVASCRIPT. As with Python, the core is configured elsewhere:
---   after/lsp/vtsls.lua      completion, inlay hints, auto-import, TS commands
---   after/lsp/eslint.lua     linting as diagnostics + code actions
---   lua/plugins/format.lua   prettierd on save
---   lua/plugins/test.lua     neotest-vitest and neotest-jest, auto-detected
---   lua/plugins/treesitter.lua  nvim-ts-autotag for JSX tag closing
---
--- This file adds the ecosystem-specific extras.
---
--- NODE IS REQUIRED. vtsls, eslint and prettier all run on Node; without it they
--- install through mason but fail to start. `:checkhealth` reports this.

return {
  -- ═════════════════════════════════════════════════════════════════════════
  -- PACKAGE-INFO — dependency versions inside package.json
  -- ═════════════════════════════════════════════════════════════════════════
  -- The npm counterpart to crates.nvim: shows the installed and latest version
  -- next to each dependency as virtual text, flags outdated ones, and lets you
  -- change or delete a dependency without leaving the file.
  {
    "vuki656/package-info.nvim",
    dependencies = { "MunifTanjim/nui.nvim" },
    event = { "BufRead package.json" },
    -- Bound under `<leader>cp` ("code → packages") rather than `<leader>n`,
    -- because `<leader>n` is already the notification history. A key cannot be
    -- both a complete mapping and a prefix without introducing a 'timeoutlen'
    -- delay on every key beneath it.
    keys = {
      { "<leader>cps", function() require("package-info").show({ force = true }) end, desc = "npm: show versions" },
      { "<leader>cph", function() require("package-info").hide() end, desc = "npm: hide versions" },
      { "<leader>cpt", function() require("package-info").toggle() end, desc = "npm: toggle versions" },
      { "<leader>cpu", function() require("package-info").update() end, desc = "npm: update package" },
      { "<leader>cpd", function() require("package-info").delete() end, desc = "npm: delete package" },
      { "<leader>cpi", function() require("package-info").install() end, desc = "npm: install new package" },
      { "<leader>cpv", function() require("package-info").change_version() end, desc = "npm: change version" },
    },
    opts = {
      colors = {
        up_to_date = require("config.palette").colors.comment,
        outdated = require("config.palette").colors.warn,
        invalid = require("config.palette").colors.error,
      },
      icons = {
        enable = true,
        style = {
          up_to_date = "|  ",
          outdated = "|  ",
          invalid = "|  ",
        },
      },
      -- Detect the package manager from the lockfile rather than assuming npm.
      package_manager = (function()
        local cwd = vim.uv.cwd() or "."
        if vim.uv.fs_stat(cwd .. "/pnpm-lock.yaml") then return "pnpm" end
        if vim.uv.fs_stat(cwd .. "/yarn.lock") then return "yarn" end
        if vim.uv.fs_stat(cwd .. "/bun.lockb") then return "bun" end
        return "npm"
      end)(),
      autostart = true,
      hide_up_to_date = true, -- only annotate what needs attention
      hide_unstable_versions = true,
    },
  },

  -- ═════════════════════════════════════════════════════════════════════════
  -- TREESITTER PARSERS
  -- ═════════════════════════════════════════════════════════════════════════
  -- Note the separate `tsx` parser: .tsx files use it rather than `typescript`,
  -- and without it JSX in a .tsx file is unhighlighted. This catches people out.
  {
    "nvim-treesitter/nvim-treesitter",
    optional = true,
    opts = function()
      if vim.fn.executable("tree-sitter") == 1 then
        pcall(function()
          -- No "jsonc": JSON-with-comments uses the `json` parser via an alias
          -- registered in lua/plugins/treesitter.lua.
          require("nvim-treesitter").install({
            "typescript", "tsx", "javascript", "jsdoc", "json", "css", "html",
          })
        end)
      end
    end,
  },

  -- ═════════════════════════════════════════════════════════════════════════
  -- WHICH-KEY GROUP for the npm bindings above
  -- ═════════════════════════════════════════════════════════════════════════
  -- `opts_extend = { "spec" }` on the which-key spec (lua/plugins/editor.lua)
  -- means this APPENDS to the group list rather than replacing it.
  {
    "folke/which-key.nvim",
    optional = true,
    opts = {
      spec = {
        { "<leader>cp", group = "Packages (npm)", icon = "\u{e71e} " },
      },
    },
  },
}
