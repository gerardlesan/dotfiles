--- after/lsp/vtsls.lua — TypeScript and JavaScript
---
--- vtsls wraps the same `tsserver` that VS Code drives, but exposes it as a
--- standards-compliant language server. Compared with the official `ts_ls`
--- wrapper it has working inlay hints, better monorepo/project-reference
--- handling, and exposes tsserver's own commands (organise imports, add missing
--- imports, "go to source definition" which skips .d.ts files).
---
--- IMPORTANT: TypeScript's own version comes from the project's node_modules, not
--- from vtsls. A project with no `typescript` dependency falls back to the bundled
--- one, which may not match your tsconfig features.
---
--- eslint runs as a separate server (after/lsp/eslint.lua) and prettier as a
--- formatter through conform.nvim. Three tools, three jobs, no overlap.

-- Inlay hints are the main reason to prefer vtsls, so they are configured in
-- full. Each block is `{ enabled = ... }` in tsserver's own schema.
local inlay_hints = {
  -- Show the inferred type of a variable declared without an annotation.
  variableTypes = { enabled = false, suppressWhenTypeMatchesName = true },
  -- Parameter names at call sites: `foo(|name:| "x")`. "literals" shows them only
  -- for literal arguments, which is where they actually add information — a
  -- variable already named `userId` does not need a `userId:` hint in front of it.
  parameterNames = { enabled = "literals", suppressWhenArgumentMatchesName = true },
  parameterTypes = { enabled = true },
  propertyDeclarationTypes = { enabled = true },
  functionLikeReturnTypes = { enabled = true },
  enumMemberValues = { enabled = true },
}

return {
  settings = {
    -- ── vtsls' own behaviour ────────────────────────────────────────────────
    vtsls = {
      -- Enable the extra commands (organise imports, fix all, source actions)
      -- that tsserver supports but plain LSP does not expose.
      experimental = {
        completion = {
          -- Return unimported symbols as completion candidates and add the import
          -- on accept. The single most valuable TypeScript feature.
          enableServerSideFuzzyMatch = true,
          entriesLimit = 100,
        },
        -- Let vtsls resolve the project's own TypeScript from node_modules.
        maxInlayHintLength = 30,
      },
      autoUseWorkspaceTsdk = true,
    },

    -- ── Settings shared by both languages ───────────────────────────────────
    typescript = {
      inlayHints = inlay_hints,
      -- Use short relative paths in auto-imports rather than long absolute ones.
      preferences = {
        importModuleSpecifier = "shortest",
        preferTypeOnlyAutoImports = true,
        includePackageJsonAutoImports = "auto",
      },
      -- Update import paths automatically when a file is renamed. Works with
      -- <leader>cR (snacks.rename) and with oil.nvim renames.
      updateImportsOnFileMove = { enabled = "always" },
      suggest = { completeFunctionCalls = true },
      -- tsserver's own formatter is off; prettier handles formatting.
      format = { enable = false },
    },

    javascript = {
      inlayHints = inlay_hints,
      preferences = { importModuleSpecifier = "shortest" },
      updateImportsOnFileMove = { enabled = "always" },
      suggest = { completeFunctionCalls = true },
      format = { enable = false },
    },
  },

  --- Buffer-local TypeScript commands. These are vtsls-specific, so they belong
  --- here rather than in the generic LspAttach block in lua/plugins/lsp.lua.
  ---@param client vim.lsp.Client
  ---@param bufnr integer
  on_attach = function(client, bufnr)
    local function map(keys, cmd, desc)
      vim.keymap.set("n", keys, cmd, { buffer = bufnr, desc = "TS: " .. desc, silent = true })
    end

    -- Jump to the real implementation instead of landing in a .d.ts stub — the
    -- fix for "go to definition took me to a type declaration".
    map("gs", function()
      client:exec_cmd({
        command = "typescript.goToSourceDefinition",
        arguments = { vim.uri_from_bufnr(bufnr), vim.lsp.util.make_position_params(0, "utf-16").position },
      }, { bufnr = bufnr })
    end, "Go to source definition")

    map("<leader>cM", function()
      client:exec_cmd({
        command = "typescript.addMissingImports.ts",
        arguments = { vim.uri_from_bufnr(bufnr) },
      }, { bufnr = bufnr })
    end, "Add all missing imports")

    map("<leader>cu", function()
      client:exec_cmd({
        command = "typescript.removeUnusedImports.ts",
        arguments = { vim.uri_from_bufnr(bufnr) },
      }, { bufnr = bufnr })
    end, "Remove unused imports")

    map("<leader>cD", function()
      client:exec_cmd({
        command = "typescript.selectTypeScriptVersion",
        arguments = {},
      }, { bufnr = bufnr })
    end, "Select TypeScript version")
  end,
}
