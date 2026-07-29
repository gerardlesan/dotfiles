--- ~/.config/nvim/lua/plugins/editor.lua
---
--- Editing mechanics and navigation: the keybinding help screen, jump motions,
--- text objects, surround, comments, TODO tracking, the diagnostics panel, the
--- symbol outline, project-wide search-and-replace, and session persistence.

local P = require("config.palette")
local icons = P.icons

return {
  -- ═════════════════════════════════════════════════════════════════════════
  -- WHICH-KEY — THE KEYBINDING SCREEN
  -- ═════════════════════════════════════════════════════════════════════════
  -- Press <leader> (or any prefix) and pause: a panel lists every key available
  -- from that prefix with its description. This is not a static cheatsheet that
  -- drifts out of date — it reads Neovim's live keymap table, so anything mapped
  -- with a `desc` shows up automatically, including mappings added by plugins.
  --
  -- Three ways in:
  --   <leader>       browse from the top, drill down group by group
  --   <leader>?      every mapping active in THIS buffer (includes LSP mappings,
  --                  which only exist once a language server attaches)
  --   <leader>sk     fuzzy-SEARCH all keymaps by description — the right tool when
  --                  you know what you want to do but not which key does it
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts_extend = { "spec" },
    opts = {
      -- "helix" renders a tall panel on the right, which fits far more entries
      -- legibly than the classic bottom strip. Alternatives: "modern", "classic".
      preset = "helix",

      -- Show instantly for a plugin's own popup, otherwise respect 'timeoutlen'
      -- (300ms) so deliberately-typed sequences do not flash the panel.
      delay = function(ctx)
        return ctx.plugin and 0 or 300
      end,

      icons = {
        breadcrumb = icons.ui.chevron,
        separator = "\u{2192} ",
        group = "\u{f0da} ",
        -- Show which modifier keys are involved, spelled out.
        mappings = true,
        keys = {},
      },

      win = {
        border = P.border,
        padding = { 1, 2 },
        title = true,
        title_pos = "center",
        wo = { winblend = 0 },
      },

      layout = {
        width = { min = 20 },
        spacing = 3,
      },

      -- Sort groups before individual keys, then alphabetically. Makes the panel
      -- scannable rather than arbitrary.
      sort = { "local", "order", "group", "alphanum", "mod" },

      -- ── GROUP NAMES ────────────────────────────────────────────────────────
      -- Without these, the panel shows "+prefix" for each group instead of a
      -- meaningful label. Keep in sync with the leader map documented at the top
      -- of lua/config/keymaps.lua.
      spec = {
        {
          mode = { "n", "v" },
          { "<leader>b", group = "Buffer", icon = "\u{f0f6} " },
          { "<leader>c", group = "Code / LSP", icon = icons.ui.lsp },
          -- Reserved, deliberately empty. Kept in the panel as a signpost: if you
          -- add nvim-dap later, its mappings belong here and will populate it.
          -- See docs/ADDING-A-LANGUAGE.md.
          { "<leader>d", group = "Debug (not installed)", icon = icons.ui.debug },
          { "<leader>f", group = "File / Find", icon = icons.ui.folder },
          { "<leader>g", group = "Git", icon = icons.ui.branch },
          { "<leader>i", group = "Image", icon = "\u{f03e} " },
          { "<leader>l", group = "Lazy / Plugins", icon = icons.ui.package },
          { "<leader>o", group = "Outline / Symbols", icon = "\u{f02b} " },
          { "<leader>q", group = "Quit / Session", icon = "\u{f011} " },
          -- Language-specific "run / language actions". Currently populated only
          -- in Rust buffers (rustaceanvim + crates.nvim); the group is declared
          -- globally so the label is right wherever it does appear.
          { "<leader>r", group = "Run / Language actions", icon = "\u{e7a8} " },
          { "<leader>s", group = "Search", icon = icons.ui.search },
          { "<leader>t", group = "Test / Terminal", icon = icons.ui.test },
          { "<leader>u", group = "UI Toggles", icon = "\u{f013} " },
          { "<leader>w", group = "Window", icon = "\u{f2d2} " },
          { "<leader>x", group = "Diagnostics / Quickfix", icon = icons.diagnostics.Warn },
          { "<leader><tab>", group = "Tab pages", icon = "\u{f0c9} " },

          -- Non-leader prefixes worth labelling.
          { "[", group = "Previous ..." },
          { "]", group = "Next ..." },
          { "g", group = "Goto / misc" },
          { "gs", group = "Surround" },
          { "z", group = "Fold / view" },
          { "<leader><space>", desc = "Find files (smart)" },

          -- Explain the two register-ish prefixes people forget exist.
          { '"', group = "Registers" },
          { "'", group = "Marks" },
          { "`", group = "Marks (exact position)" },
        },
      },
    },
    keys = {
      {
        "<leader>?",
        function()
          require("which-key").show({ global = false })
        end,
        desc = "Keymaps for this buffer",
      },
      {
        -- A discoverable, spelled-out entry point. `:Keymaps` also works.
        "<F1>",
        function()
          require("which-key").show({ global = true })
        end,
        desc = "Show all keymaps",
      },
    },
    config = function(_, opts)
      local wk = require("which-key")
      wk.setup(opts)
      vim.api.nvim_create_user_command("Keymaps", function()
        wk.show({ global = true })
      end, { desc = "Show the keybinding panel" })
    end,
  },

  -- ═════════════════════════════════════════════════════════════════════════
  -- FLASH — jump anywhere on screen in ~3 keystrokes
  -- ═════════════════════════════════════════════════════════════════════════
  -- Press `s`, type two characters of where you want to go, then the highlighted
  -- label that appears next to your target. Replaces the "spam `w` twenty times"
  -- or "count the lines then `12j`" workflow entirely, and it works as an operator
  -- target too: `ds<label>` deletes to there.
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {
      labels = "asdfghjklqwertyuiopzxcvbnm", -- home row first
      search = { multi_window = true },
      jump = { autojump = false },
      label = {
        uppercase = false,
        rainbow = { enabled = false },
      },
      modes = {
        -- Enhance `f`, `F`, `t`, `T`: after the first press, repeat with `f`/`;`
        -- and jump to any occurrence on screen, not just the current line.
        char = {
          enabled = true,
          jump_labels = true,
          multi_line = true,
        },
        -- Show labels while typing a `/` search too, so you can jump straight to
        -- any match rather than pressing `n` repeatedly.
        search = { enabled = false }, -- off: it makes ordinary `/` feel busy
      },
    },
    keys = {
      { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash jump" },
      { "S", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Flash treesitter node" },
      -- Operate on a location *without moving there*: `yr<label>` yanks a remote
      -- text object and returns the cursor to where it started.
      { "r", mode = "o", function() require("flash").remote() end, desc = "Remote flash" },
      { "R", mode = { "o", "x" }, function() require("flash").treesitter_search() end, desc = "Treesitter search" },
      -- Toggle flash inside a normal `/` search, when you do want the labels.
      { "<C-s>", mode = { "c" }, function() require("flash").toggle() end, desc = "Toggle flash search" },
    },
  },

  -- ═════════════════════════════════════════════════════════════════════════
  -- MINI.* — small, focused, zero-dependency modules
  -- ═════════════════════════════════════════════════════════════════════════

  -- Better text objects. Extends `i`/`a` so that `vaf` selects a whole function,
  -- `dia` deletes an argument, `cif` changes a function body — all treesitter-aware
  -- and therefore correct in every language with a parser.
  {
    "echasnovski/mini.ai",
    event = "VeryLazy",
    opts = function()
      local ai = require("mini.ai")
      return {
        n_lines = 500, -- how far to search for a match
        custom_textobjects = {
          -- f = function (definition), c = class, these come from treesitter
          o = ai.gen_spec.treesitter({
            a = { "@block.outer", "@conditional.outer", "@loop.outer" },
            i = { "@block.inner", "@conditional.inner", "@loop.inner" },
          }),
          f = ai.gen_spec.treesitter({ a = "@function.outer", i = "@function.inner" }),
          c = ai.gen_spec.treesitter({ a = "@class.outer", i = "@class.inner" }),
          -- t = an HTML/JSX tag pair
          t = { "<([%p%w]-)%f[^<%w][^<>]->.-</%1>", "^<.->().*()</[^/]->$" },
          -- d = a digit run, u = a "usage" (function call), g = the whole buffer
          d = { "%f[%d]%d+" },
          g = function()
            return {
              from = { line = 1, col = 1 },
              to = {
                line = vim.fn.line("$"),
                col = math.max(vim.fn.getline("$"):len(), 1),
              },
            }
          end,
        },
      }
    end,
  },

  -- Surround. `gsa` add, `gsd` delete, `gsr` replace.
  -- NOTE the `gs` prefix rather than the more common `s`: flash.nvim owns `s` for
  -- jumping, and jumping is used far more often than surrounding. This is the
  -- standard resolution to that clash.
  {
    "echasnovski/mini.surround",
    keys = function(_, keys)
      -- Register the keys with lazy so the plugin loads on first use, and with
      -- which-key so they are documented.
      local opts = { mappings = {
        add = "gsa", delete = "gsd", find = "gsf", find_left = "gsF",
        highlight = "gsh", replace = "gsr", update_n_lines = "gsn",
      } }
      local mappings = {
        { opts.mappings.add, desc = "Add surrounding", mode = { "n", "v" } },
        { opts.mappings.delete, desc = "Delete surrounding" },
        { opts.mappings.find, desc = "Find surrounding (right)" },
        { opts.mappings.find_left, desc = "Find surrounding (left)" },
        { opts.mappings.highlight, desc = "Highlight surrounding" },
        { opts.mappings.replace, desc = "Replace surrounding" },
        { opts.mappings.update_n_lines, desc = "Update surround line count" },
      }
      return vim.list_extend(mappings, keys or {})
    end,
    opts = {
      mappings = {
        add = "gsa", delete = "gsd", find = "gsf", find_left = "gsF",
        highlight = "gsh", replace = "gsr", update_n_lines = "gsn",
      },
    },
  },

  -- Auto-pairs: type `(` and get `()`. Kept because mini.pairs is the least
  -- intrusive implementation — it does not fight treesitter or completion, and it
  -- skips insertion when the next character is alphanumeric (so typing `(` before
  -- an existing word does not produce `(word)`).
  {
    "echasnovski/mini.pairs",
    event = "VeryLazy",
    opts = {
      modes = { insert = true, command = false, terminal = false },
      -- Do not auto-pair before these characters.
      skip_next = [=[[%w%%%'%[%"%.%`%$]]=],
      skip_ts = { "string" }, -- do not pair inside a string literal
      skip_unbalanced = true, -- do not add a closer if brackets are already unbalanced
      markdown = true,        -- pair ``` fences in markdown
    },
  },

  -- ═════════════════════════════════════════════════════════════════════════
  -- COMMENTS
  -- ═════════════════════════════════════════════════════════════════════════
  -- Neovim 0.10+ has commenting built in: `gcc` toggles a line, `gc` is an
  -- operator (`gcap` comments a paragraph), `gbc` block-comments. No plugin needed
  -- for the mechanics.
  --
  -- What IS needed is a correct 'commentstring' inside embedded languages — a
  -- <script> block in HTML needs `//`, the surrounding HTML needs `<!-- -->`, and
  -- a Vue file has three different comment styles in one buffer. ts-comments
  -- resolves it from the treesitter node under the cursor.
  {
    "folke/ts-comments.nvim",
    event = "VeryLazy",
    opts = {},
  },

  -- ═════════════════════════════════════════════════════════════════════════
  -- TODO COMMENTS
  -- ═════════════════════════════════════════════════════════════════════════
  -- Highlights TODO / FIXME / HACK / WARN / PERF / NOTE / TEST in comments, and —
  -- the actually useful part — gives you a searchable project-wide list of them.
  {
    "folke/todo-comments.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    event = { "BufReadPost", "BufNewFile" },
    cmd = { "TodoTrouble", "TodoQuickFix" },
    keys = {
      { "]t", function() require("todo-comments").jump_next() end, desc = "Next todo comment" },
      { "[t", function() require("todo-comments").jump_prev() end, desc = "Previous todo comment" },
      { "<leader>st", "<cmd>TodoTrouble<cr>", desc = "Todo list (Trouble)" },
      { "<leader>sT", "<cmd>TodoTrouble keywords=TODO,FIX,FIXME<cr>", desc = "Todo/Fix only" },
      { "<leader>xt", "<cmd>TodoTrouble<cr>", desc = "Todo list (Trouble)" },
    },
    opts = {
      signs = true,
      keywords = {
        FIX = { icon = "\u{f188} ", color = "error", alt = { "FIXME", "BUG", "FIXIT", "ISSUE" } },
        TODO = { icon = "\u{f0ae} ", color = "info" },
        HACK = { icon = "\u{f0e7} ", color = "warning" },
        WARN = { icon = "\u{f071} ", color = "warning", alt = { "WARNING", "XXX" } },
        PERF = { icon = "\u{f062} ", alt = { "OPTIM", "PERFORMANCE", "OPTIMIZE" } },
        NOTE = { icon = "\u{f05a} ", color = "hint", alt = { "INFO" } },
        TEST = { icon = "\u{f0c3} ", color = "test", alt = { "TESTING", "PASSED", "FAILED" } },
      },
      -- Highlight only the keyword, not the whole comment line — a wall of
      -- highlighted text is harder to read than the comment itself.
      highlight = { keyword = "wide_fg", after = "" },
    },
  },

  -- ═════════════════════════════════════════════════════════════════════════
  -- TROUBLE — the diagnostics / quickfix / references panel
  -- ═════════════════════════════════════════════════════════════════════════
  -- A structured, navigable list of problems, grouped by file, with a live
  -- preview. Far more usable than the raw quickfix window for anything with more
  -- than three entries.
  {
    "folke/trouble.nvim",
    cmd = { "Trouble" },
    opts = {
      modes = {
        -- A tighter preset for symbol browsing, docked to the right.
        symbols = {
          desc = "Document symbols",
          win = { position = "right", size = 0.25 },
        },
      },
      win = { border = P.border },
      focus = true, -- move the cursor into the panel when it opens
    },
    keys = {
      { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", desc = "Diagnostics (project)" },
      { "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "Diagnostics (buffer)" },
      { "<leader>xs", "<cmd>Trouble symbols toggle<cr>", desc = "Symbols panel" },
      { "<leader>xl", "<cmd>Trouble loclist toggle<cr>", desc = "Location list" },
      { "<leader>xq", "<cmd>Trouble qflist toggle<cr>", desc = "Quickfix list" },
      { "<leader>xr", "<cmd>Trouble lsp toggle focus=false win.position=right<cr>", desc = "LSP references / definitions" },
      -- Walk the Trouble list from anywhere, without focusing the panel.
      {
        "[x",
        function() require("trouble").prev({ skip_groups = true, jump = true }) end,
        desc = "Previous Trouble item",
      },
      {
        "]x",
        function() require("trouble").next({ skip_groups = true, jump = true }) end,
        desc = "Next Trouble item",
      },
    },
  },

  -- ═════════════════════════════════════════════════════════════════════════
  -- AERIAL — symbol outline
  -- ═════════════════════════════════════════════════════════════════════════
  -- A sidebar of the current file's structure (classes, functions, methods),
  -- sourced from the LSP with a treesitter fallback. The IDE "Structure" panel.
  {
    "stevearc/aerial.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
    cmd = { "AerialToggle", "AerialOpen", "AerialNavToggle" },
    keys = {
      { "<leader>oo", "<cmd>AerialToggle<cr>", desc = "Outline (toggle sidebar)" },
      { "<leader>on", "<cmd>AerialNavToggle<cr>", desc = "Outline (floating navigator)" },
      { "{", "<cmd>AerialPrev<cr>", desc = "Previous symbol" },
      { "}", "<cmd>AerialNext<cr>", desc = "Next symbol" },
    },
    opts = {
      -- Prefer the LSP's symbol tree; fall back to treesitter where no server is
      -- attached, and to markdown headings in documents.
      backends = { "lsp", "treesitter", "markdown", "asciidoc", "man" },
      layout = {
        min_width = 28,
        default_direction = "right",
        placement = "edge",
      },
      attach_mode = "global",
      -- Show a guide line connecting nested symbols.
      show_guides = true,
      guides = {
        mid_item = "\u{251c}\u{2500}",
        last_item = "\u{2514}\u{2500}",
        nested_top = "\u{2502} ",
        whitespace = "  ",
      },
      -- Auto-collapse deep trees so the panel opens readable.
      manage_folds = false,
      filter_kind = false, -- show every symbol kind, not just the default subset
      icons = {},
    },
  },

  -- ═════════════════════════════════════════════════════════════════════════
  -- GRUG-FAR — project-wide search and replace
  -- ═════════════════════════════════════════════════════════════════════════
  -- Opens a buffer with search / replace / files-to-include fields, shows every
  -- match with context as you type, and applies the replacement across the whole
  -- project on demand. This is the piece `:%s/.../.../` and `:cdo` cannot do
  -- comfortably, and it is one of the things people most miss from a GUI IDE.
  {
    "MagicDuck/grug-far.nvim",
    cmd = "GrugFar",
    keys = {
      {
        "<leader>sr",
        function()
          local grug = require("grug-far")
          local ext = vim.bo.buftype == "" and vim.fn.expand("%:e")
          grug.open({
            transient = true,
            prefills = {
              -- Pre-limit the search to the current file's type, which is usually
              -- what you want and is trivial to clear.
              filesFilter = ext and ext ~= "" and ("*." .. ext) or nil,
            },
          })
        end,
        mode = { "n", "v" },
        desc = "Search & replace (project)",
      },
      {
        "<leader>sR",
        function()
          require("grug-far").open({ transient = true, prefills = { paths = vim.fn.expand("%") } })
        end,
        desc = "Search & replace (this file)",
      },
    },
    opts = {
      headerMaxWidth = 80,
      -- Uses ripgrep under the hood, which is already a dependency.
      engine = "ripgrep",
    },
  },

  -- ═════════════════════════════════════════════════════════════════════════
  -- PERSISTENCE — sessions
  -- ═════════════════════════════════════════════════════════════════════════
  -- Saves the open buffers, window layout and cwd per directory, so reopening a
  -- project restores exactly where you left off. What gets saved is controlled by
  -- 'sessionoptions' in lua/config/options.lua — notably NOT options, so a stale
  -- session cannot override your config.
  {
    "folke/persistence.nvim",
    event = "BufReadPre",
    opts = {},
    keys = {
      { "<leader>qs", function() require("persistence").load() end, desc = "Restore session (this directory)" },
      { "<leader>qS", function() require("persistence").select() end, desc = "Select a session" },
      { "<leader>ql", function() require("persistence").load({ last = true }) end, desc = "Restore last session" },
      {
        "<leader>qd",
        function() require("persistence").stop() end,
        desc = "Don't save this session on exit",
      },
    },
  },
}
