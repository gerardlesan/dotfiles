--- ~/.config/nvim/lua/plugins/lang/python.lua
---
--- PYTHON. Most of the work is already done elsewhere:
---   after/lsp/basedpyright.lua   types, completion, inlay hints
---   after/lsp/ruff.lua           linting and import sorting as code actions
---   lua/plugins/format.lua       ruff_organize_imports then ruff_format on save
---   lua/plugins/test.lua         neotest-python, with per-project interpreter
---
--- What is left is the one thing that reliably goes wrong: WHICH INTERPRETER.
--- A Python language server that cannot find your virtualenv reports every
--- third-party import as unresolved, and there is no way to tell from the error
--- message that the venv is the problem. This file makes the interpreter explicit
--- and switchable.

return {
  -- ═════════════════════════════════════════════════════════════════════════
  -- VENV-SELECTOR — pick the interpreter, tell the LSP about it
  -- ═════════════════════════════════════════════════════════════════════════
  -- <leader>cv opens a picker of every virtualenv it can find (project-local
  -- .venv, poetry, pipenv, conda, uv, pyenv, and anything under the search paths
  -- below). Choosing one restarts the language servers pointed at that
  -- interpreter, so imports resolve immediately.
  --
  -- The statusline shows the active venv in Python buffers (see the `python_env`
  -- component in lua/plugins/ui.lua), so you can always see which one is in use.
  {
    "linux-cultist/venv-selector.nvim",
    branch = "regexp", -- the actively maintained branch; `main` is the old rewrite
    dependencies = {
      "neovim/nvim-lspconfig",
      "mfussenegger/nvim-dap-python", -- optional; skipped gracefully if absent
      "nvim-lua/plenary.nvim",
    },
    ft = "python",
    cmd = { "VenvSelect", "VenvSelectCached" },
    keys = {
      { "<leader>cv", "<cmd>VenvSelect<cr>", desc = "Select Python interpreter" },
      { "<leader>cV", "<cmd>VenvSelectCached<cr>", desc = "Use last Python interpreter" },
    },
    opts = {
      settings = {
        options = {
          -- Remember the choice per project directory, so you pick once and it
          -- sticks across sessions.
          activate_venv_in_terminal = true,
          set_environment_variables = true, -- exports VIRTUAL_ENV for :terminal
          notify_user_on_venv_activation = true,
          -- Show the venv path in the picker, not just its name — essential when
          -- three projects all have a `.venv`.
          debug = false,
        },
        search = {
          -- Project-local venvs, checked first and by far the most common layout.
          cwd = {
            command = "fd '/bin/python$|/Scripts/python.exe$' "
              .. vim.fn.getcwd()
              .. " --full-path --color never --hidden --no-ignore-vcs -a -E /proc",
          },
          -- uv keeps venvs in the project too, but also caches them centrally.
          -- Add or remove entries here to match how you actually create venvs.
        },
      },
    },
  },

  -- ═════════════════════════════════════════════════════════════════════════
  -- FALLBACK INTERPRETER RESOLUTION
  -- ═════════════════════════════════════════════════════════════════════════
  -- Even without opening the picker, the right interpreter should usually be
  -- found. This hooks basedpyright's config to point at a project-local venv when
  -- one exists, which covers the common case with no interaction at all.
  {
    "neovim/nvim-lspconfig",
    optional = true,
    opts = function()
      --- Find a virtualenv's python for a given project root.
      --- Handles both layouts: `bin/python` on Unix, `Scripts/python.exe` on
      --- Windows. Getting this wrong is why so many configs are Linux-only.
      ---@param root string
      ---@return string|nil
      local function find_venv_python(root)
        local candidates = {
          -- An explicitly activated venv always wins.
          os.getenv("VIRTUAL_ENV"),
          root .. "/.venv",
          root .. "/venv",
          root .. "/env",
        }
        for _, venv in ipairs(candidates) do
          if venv and venv ~= "" then
            for _, rel in ipairs({ "/bin/python", "/Scripts/python.exe" }) do
              local exe = venv .. rel
              if vim.fn.executable(exe) == 1 then
                return exe
              end
            end
          end
        end
        return nil
      end

      -- `vim.lsp.config()` merges into the config assembled from
      -- nvim-lspconfig's lsp/basedpyright.lua and this repo's
      -- after/lsp/basedpyright.lua, so the settings there are preserved.
      vim.lsp.config("basedpyright", {
        before_init = function(_, config)
          local root = config.root_dir or vim.uv.cwd()
          local python = find_venv_python(root)
          if python then
            config.settings = config.settings or {}
            config.settings.python = vim.tbl_deep_extend("force", config.settings.python or {}, { pythonPath = python })
          end
        end,
      })

      -- ruff needs the same treatment so it lints with the project's rule set and
      -- plugin versions rather than mason's copy in isolation.
      vim.lsp.config("ruff", {
        before_init = function(_, config)
          local root = config.root_dir or vim.uv.cwd()
          local python = find_venv_python(root)
          if python then
            config.init_options = config.init_options or {}
            config.init_options.settings = config.init_options.settings or {}
            config.init_options.settings.interpreter = { python }
          end
        end,
      })
    end,
  },

  -- ═════════════════════════════════════════════════════════════════════════
  -- TREESITTER PARSER
  -- ═════════════════════════════════════════════════════════════════════════
  -- Declared in the `parser_groups` table in lua/plugins/treesitter.lua, not
  -- here: `python` and `requirements` are in its `python` group and `toml` in
  -- its `rust` group. A duplicate `optional = true` nvim-treesitter spec used to
  -- live here re-installing them — lazy.nvim runs every merged `opts` function,
  -- so that was pure startup cost plus a second place to edit.
}
