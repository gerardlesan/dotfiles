# Adding a language

Full support for a new language is **five small edits**, and only the first two are
usually needed. Worked example: **Go**.

| # | What | Where | Needed? |
|---|---|---|---|
| 1 | treesitter parser | `nvim/lua/plugins/treesitter.lua` | often automatic |
| 2 | language server | `nvim/lua/plugins/lsp.lua` + `nvim/after/lsp/<server>.lua` | yes |
| 3 | formatter | `nvim/lua/plugins/format.lua` | if it has one |
| 4 | linter | `nvim/lua/plugins/lint.lua` | only if not an LSP |
| 5 | indent & local keys | `nvim/after/ftplugin/<filetype>.lua` | recommended |

Plus optionally a test adapter and a language-specific plugin file.

---

## 1. Treesitter parser — usually nothing to do

**Open a `.go` file and the parser installs itself.** The `FileType` autocmd in
`lua/plugins/treesitter.lua` resolves the language from the filetype, notices no
parser is present, checks it exists upstream, and installs it in the background.

To make it explicit (recommended for a language you will always use), add it to
the **`parser_groups`** table in that file — append to the group it belongs to, or
add a new group:

```lua
local parser_groups = {
  rust = { "rust", "toml" },
  python = { "python", "requirements" },
  go = { "go", "gomod", "gosum" },   -- ← Go needs three
  ...
}
```

> **Edit `parser_groups`, not `ensure_parsers`.** `ensure_parsers` a few lines
> below is *generated* by flattening `parser_groups` with `vim.list_extend`, so
> anything you write into it directly is discarded.

Parsers are declared **only** here. Do not add an `optional = true`
nvim-treesitter spec to `lua/plugins/lang/<lang>.lua` calling `install()` — the
three language files used to do exactly that, and because lazy.nvim runs every
merged `opts` function it re-loaded `nvim-treesitter.parsers` on each startup and
split one concern across four files. Those specs were removed.

Verify with `:checkhealth nvim-treesitter`. List every available name with:

```vim
:lua =require("nvim-treesitter.config").get_available()
```

> **Gotcha:** some filetypes have no parser of their own and are handled by another
> grammar — `jsonc` uses `json`, `zsh` uses `bash`. Those go in the `aliases` table
> in the same file, **not** in `ensure_parsers`, or you get
> `skipping unsupported language`.

---

## 2. Language server — the one real step

### a. Add the server name

In `nvim/lua/plugins/lsp.lua`, one line in the `servers` list:

```lua
local servers = {
  "lua_ls",
  "basedpyright",
  "ruff",
  "gopls",        -- ←
  ...
}
```

The name must match nvim-lspconfig's filename. Browse them at
[nvim-lspconfig/lsp](https://github.com/neovim/nvim-lspconfig/tree/master/lsp), or
run `:Mason` and search. `mason-lspconfig` installs the binary on next start.

That is genuinely all that is required — nvim-lspconfig already supplies `cmd`,
`filetypes` and `root_markers`.

### b. Optionally, add settings

Create `nvim/after/lsp/gopls.lua` returning a table:

```lua
--- after/lsp/gopls.lua
return {
  settings = {
    gopls = {
      analyses = {
        unusedparams = true,
        shadow = true,
      },
      staticcheck = true,
      gofumpt = true,
      hints = {
        assignVariableTypes = true,
        compositeLiteralFields = true,
        parameterNames = true,
        rangeVariableTypes = true,
      },
    },
  },
}
```

**Why `after/lsp/` and not `lsp/`:** Neovim collects every `lsp/<name>.lua` on the
runtimepath and deep-merges them in runtimepath order. `after/` is read last, so
your settings win while nvim-lspconfig's `cmd`/`filetypes`/`root_markers` are
preserved. Verified: overriding `cmd` replaces it, and sibling keys from the base
config survive.

You can also use `on_attach` here for server-specific keymaps — see
`after/lsp/vtsls.lua` for a substantial example.

### c. If two servers overlap

When you run two servers on one filetype (as this config does for Python:
`basedpyright` for types, `ruff` for lints), disable the duplicated capabilities on
the weaker one so requests resolve deterministically. See `after/lsp/ruff.lua`:

```lua
on_attach = function(client)
  client.server_capabilities.hoverProvider = false
  client.server_capabilities.definitionProvider = false
end,
```

Without this, pressing `K` gives you whichever server replied first.

---

## 3. Formatter

In `nvim/lua/plugins/format.lua`, add to `formatters_by_ft`:

```lua
go = { "goimports", "gofumpt" },   -- a list runs them IN ORDER, as a pipeline
```

Then add the tool to `ensure_installed` in the `mason-tool-installer` spec in
`nvim/lua/plugins/lsp.lua`:

```lua
ensure_installed = {
  "stylua", "prettierd", "shfmt",
  "goimports", "gofumpt",   -- ←
  ...
}
```

Two useful forms:

```lua
python = { "ruff_organize_imports", "ruff_format" },              -- pipeline, both run
javascript = { "prettierd", "prettier", stop_after_first = true } -- fallback chain
```

Check what will run in the current buffer with `:ConformInfo`.

---

## 4. Linter — only if it is not a language server

Most modern linters ship an LSP, in which case step 2 already covered it. Prefer
that: LSP linters give you code actions, not just diagnostics.

If it is a plain CLI tool, add it in `nvim/lua/plugins/lint.lua`:

```lua
linters_by_ft = {
  sh = { "shellcheck" },
  go = { "golangcilint" },   -- ←
},
```

The config only runs linters whose executable exists, so a missing tool degrades
quietly rather than erroring on every save.

> **Do not double up.** If `gopls` already reports a problem, adding a linter that
> reports the same thing gives you two diagnostics for one issue. The
> `linters_by_ft` table has a comment block listing what is deliberately omitted
> for this reason.

---

## 5. Indent and filetype-local keymaps

Create `nvim/after/ftplugin/go.lua`:

```lua
--- after/ftplugin/go.lua
-- Go uses TABS, enforced by gofmt. This must override the global expandtab.
vim.bo.expandtab = false
vim.bo.shiftwidth = 4
vim.bo.tabstop = 4
vim.bo.softtabstop = 0
vim.wo.colorcolumn = ""   -- gofmt does not wrap
vim.bo.textwidth = 0

-- <localleader> is `\` and is reserved for filetype-specific commands.
vim.keymap.set("n", "<localleader>r", function()
  vim.cmd("silent! wall")
  Snacks.terminal({ "go", "run", "." }, { interactive = true })
end, { buffer = 0, desc = "Go: run" })

vim.keymap.set("n", "<localleader>t", function()
  vim.cmd("silent! wall")
  Snacks.terminal({ "go", "test", "./..." }, { interactive = true })
end, { buffer = 0, desc = "Go: test all" })
```

Rules: use `vim.bo`/`vim.wo`/`vim.opt_local` (never `vim.opt`, which is global), and
pass `buffer = 0` on every keymap. See `nvim/after/ftplugin/README.md`.

---

## 6. Optional: a test adapter

In `nvim/lua/plugins/test.lua`, add the adapter package to `dependencies` and an
entry to `adapters`:

```lua
dependencies = { ..., "nvim-neotest/neotest-go" },

adapters = {
  ...
  require("neotest-go")({ args = { "-count=1", "-timeout=60s" } }),
},
```

All the `<leader>t*` bindings then work for Go with no further changes.

## 7. Optional: a language plugin file

For anything beyond the above — a dedicated ecosystem plugin, dependency-file
annotations, an interpreter picker — create `nvim/lua/plugins/lang/go.lua`. It is
imported automatically; no registration needed. Use the existing three as models:

- `lang/rust.lua` — the most involved: rustaceanvim owns the LSP entirely, plus
  crates.nvim and a neotest adapter
- `lang/python.lua` — solving one specific problem (which interpreter?)
- `lang/typescript.lua` — a small ecosystem extra plus parser registration

Note the pattern for extending another plugin's config from a language file:

```lua
{
  "nvim-neotest/neotest",
  optional = true,   -- do not pull it in if it is not already installed
  opts = function(_, opts)
    table.insert(opts.adapters, require("neotest-go"))
  end,
}
```

---

## Adding a debugger (nvim-dap)

Not installed, by choice. `<leader>d` is reserved for it in the which-key spec and
appears in the panel as `Debug (not installed)`, and `<leader>rd` in Rust buffers is
already wired to rustaceanvim's `debuggables`.

To add it, create `nvim/lua/plugins/dap.lua`:

```lua
return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      { "rcarriga/nvim-dap-ui", dependencies = { "nvim-neotest/nvim-nio" } },
      "theHamsta/nvim-dap-virtual-text",
      -- Installs the adapters themselves through mason.
      {
        "jay-babu/mason-nvim-dap.nvim",
        opts = {
          ensure_installed = { "codelldb", "python", "js" },
          handlers = {},
        },
      },
    },
    keys = {
      { "<leader>db", function() require("dap").toggle_breakpoint() end, desc = "Toggle breakpoint" },
      { "<leader>dc", function() require("dap").continue() end, desc = "Continue / start" },
      { "<leader>di", function() require("dap").step_into() end, desc = "Step into" },
      { "<leader>do", function() require("dap").step_over() end, desc = "Step over" },
      { "<leader>dO", function() require("dap").step_out() end, desc = "Step out" },
      { "<leader>dt", function() require("dap").terminate() end, desc = "Terminate" },
      { "<leader>du", function() require("dapui").toggle() end, desc = "Toggle debug UI" },
    },
    config = function()
      require("dapui").setup()
      require("nvim-dap-virtual-text").setup({})
      -- Open the UI automatically when a session starts.
      local dap, dapui = require("dap"), require("dapui")
      dap.listeners.after.event_initialized.dapui = function() dapui.open({}) end
      dap.listeners.before.event_terminated.dapui = function() dapui.close({}) end
    end,
  },
}
```

Then update the which-key group in `nvim/lua/plugins/editor.lua`:

```lua
{ "<leader>d", group = "Debug", icon = icons.ui.debug },
```

Rust and Python get their adapters for free: rustaceanvim detects `codelldb`
automatically, and `mfussenegger/nvim-dap-python` is already a declared dependency
of venv-selector.

---

## Checklist

```
[ ] parser installs           :checkhealth nvim-treesitter
[ ] highlighting works        open a file — is it coloured?
[ ] server attaches           :checkhealth vim.lsp
[ ] completion works          type in insert mode
[ ] gd / K / <leader>ca work  they come from the shared LspAttach handler
[ ] formatter runs            :ConformInfo, then save
[ ] indent is right           :verbose set shiftwidth?
```

If the server never attaches, it is almost always one of two things: the binary is
not on `PATH` (check `:Mason`), or no `root_markers` matched so Neovim did not treat
the file as part of a project. `:LspLog` has the reason.
