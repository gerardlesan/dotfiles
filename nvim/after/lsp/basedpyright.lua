--- after/lsp/basedpyright.lua — Python types, completion and navigation
---
--- basedpyright is a community fork of Microsoft's pyright with the features that
--- are Pylance-only in the original unlocked: inlay hints, semantic highlighting
--- and call-hierarchy. It is a drop-in replacement — swap the name back to
--- "pyright" in lua/plugins/lsp.lua if you prefer upstream.
---
--- DIVISION OF LABOUR with ruff (after/lsp/ruff.lua):
---   basedpyright  types, completion, hover, go-to-definition, inlay hints
---   ruff          linting, import sorting, formatting
--- Both attach to every Python buffer. `disableOrganizeImports` below is what
--- stops them both offering "organise imports" as competing code actions.
---
--- FINDING YOUR VIRTUALENV is the thing that goes wrong most often. Order of
--- resolution: an active $VIRTUAL_ENV, then a `.venv`/`venv` directory beside
--- pyproject.toml. If imports are unresolved, pick the interpreter explicitly with
--- <leader>cv (venv-selector, see lua/plugins/lang/python.lua). The statusline
--- shows the active venv in Python buffers.

return {
  settings = {
    basedpyright = {
      -- ruff owns import organisation. Leaving this enabled gives you two
      -- "Organize Imports" entries in the code-action menu that disagree.
      disableOrganizeImports = true,

      analysis = {
        -- basedpyright defaults to "recommended", which is *strict* — it flags
        -- every missing annotation and every `Any`. Excellent for a greenfield
        -- typed codebase, exhausting on anything else.
        --   "off" | "basic" | "standard" | "strict" | "recommended" | "all"
        -- "standard" catches real errors without demanding full annotation.
        typeCheckingMode = "standard",

        -- Follow the project's own layout to find first-party imports.
        autoSearchPaths = true,
        -- Infer types from installed packages that ship no stubs. Slower on a
        -- large venv, but the alternative is `Unknown` for most third-party calls.
        useLibraryCodeForTypes = true,

        -- Analyse only open files rather than the whole workspace. On a big
        -- project "workspace" mode pins a CPU core for minutes and floods the
        -- diagnostics list with problems in files you are not touching. ruff
        -- covers project-wide linting far more cheaply.
        diagnosticMode = "openFilesOnly",

        -- Offer imports for symbols not yet imported, and add the import line on
        -- accept. One of the highest-value features here.
        autoImportCompletions = true,

        inlayHints = {
          variableTypes = true,
          callArgumentNames = true,
          functionReturnTypes = true,
          -- Generic type parameters get verbose fast in typed Python.
          genericTypes = false,
        },

        -- Silence rules that duplicate ruff, so a single problem is not reported
        -- twice by two servers with different wording.
        diagnosticSeverityOverrides = {
          reportUnusedImport = "none", -- ruff F401
          reportUnusedVariable = "none", -- ruff F841
          reportUnusedFunction = "none",
          reportUnusedClass = "none",
          -- Fires constantly in ordinary code that reads a dict of mixed types.
          reportAny = "none",
          reportExplicitAny = "none",
          -- Common and harmless in test files and scripts.
          reportMissingTypeStubs = "information",
        },
      },
    },
  },
}
