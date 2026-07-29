--- ~/.config/nvim/lua/plugins/treesitter.lua
---
--- Treesitter parses your code into a real syntax tree, which powers accurate
--- highlighting, indentation, folding, text objects, structural navigation and
--- bracket-nesting colours.
---
--- ⚠ THIS CONFIG TARGETS THE `main` BRANCH, WHICH IS A REWRITE.
---
--- nvim-treesitter's default branch changed from `master` to `main` and the API is
--- completely different. If you copy a snippet from a tutorial and it errors, this
--- is almost certainly why. The differences that matter:
---
---   master (old)                        main (this config)
---   ─────────────────────────────────   ────────────────────────────────────────
---   setup{ ensure_installed = {...} }   require("nvim-treesitter").install{...}
---   setup{ highlight = {enable=true} }  vim.treesitter.start() in a FileType autocmd
---   setup{ indent = {enable=true} }     set 'indentexpr' per buffer
---   setup{ incremental_selection={} }   REMOVED — reimplemented in util/incsel.lua
---   worked with lazy-loading            does NOT support lazy-loading (lazy=false)
---   bundled its own parser downloads    needs the `tree-sitter` CLI on PATH
---
--- REQUIREMENTS on both platforms — the install scripts handle these:
---   * a C compiler   (zig on Windows; gcc/clang on Linux)
---   * `tree-sitter`  CLI 0.26.1+
---   * `curl` and `tar` (built into Windows 10+ and every Linux distro)
---
--- Neovim 0.12 ships parsers for c, lua, markdown, query, vim and vimdoc, so those
--- work with no compilation at all. Everything else is built on demand.

local P = require("config.palette")

-- ═════════════════════════════════════════════════════════════════════════════
-- OPTIONS — every treesitter behaviour in this config, in one place
-- ═════════════════════════════════════════════════════════════════════════════
-- Change something here rather than hunting through the specs below. Each field is
-- read by exactly one place further down, and the comment says what it costs.
local ts = {
  --- Syntax highlighting from the parse tree.
  highlight = {
    enable = true,
    --- Filetypes to leave on Neovim's legacy regex syntax instead. Kept empty:
    --- treesitter highlighting is better everywhere a parser exists, and the
    --- FileType hook already degrades gracefully where one does not.
    ---@type string[]
    disable = {},
    --- Also run the old regex syntax engine ALONGSIDE treesitter. Off: it doubles
    --- the highlighting work and the two disagree, producing flicker. The only
    --- reason to enable it is a language whose parser lacks captures the old
    --- syntax file had.
    additional_regex = false,
  },

  --- Indentation via the parser's indent queries.
  indent = {
    enable = true,
    --- Languages whose treesitter indent is WORSE than the bundled vim indent
    --- script, and so keep the built-in one. Both of these are long-standing
    --- known weak spots rather than opinions:
    ---   python — mishandles continuation lines and hanging indents
    ---   yaml   — inconsistent inside nested sequences of mappings
    --- Check which is active in a buffer with `:verbose set indentexpr?`.
    ---@type string[]
    disable = { "python", "yaml" },
  },

  --- Folding. 'foldmethod' and 'foldexpr' are set globally in
  --- lua/config/options.lua section 17; this only controls the *appearance*.
  folds = {
    --- Custom fold text: the real first line, treesitter-highlighted, plus a
    --- "⋯ N lines" annotation. See lua/util/folds.lua.
    --- false = Neovim's built-in highlighted foldtext (loses the line count).
    custom_foldtext = true,
  },

  --- Colour brackets by nesting depth.
  rainbow = {
    enable = true,
    --- Filetypes to skip. Rainbow colours fight with markup where "brackets" are
    --- not really nesting.
    ---@type string[]
    blacklist = { "markdown", "text", "gitcommit", "help", "dashboard", "snacks_dashboard" },
    --- Per-filetype query. Controls WHAT gets coloured:
    ---   rainbow-delimiters  brackets, braces, parens        (the default)
    ---   rainbow-blocks      also block keywords: do/end, if/then, function/end
    ---   rainbow-tags        HTML/JSX opening and closing tag pairs
    ---   rainbow-parens      parentheses only
    ---@type table<string, string>
    query = {
      [""] = "rainbow-delimiters",
      lua = "rainbow-blocks",
      html = "rainbow-tags",
      javascriptreact = "rainbow-tags",
      typescriptreact = "rainbow-tags",
      vue = "rainbow-tags",
    },
  },

  --- The sticky header showing the enclosing function/class while you scroll.
  context = {
    enable = true,
    --- Rows of context to pin. 3 is informative; 10 eats half the window.
    max_lines = 3,
    --- Do not steal rows in a short split.
    min_window_height = 20,
    --- Collapse a multi-line function signature down to one line.
    multiline_threshold = 1,
    --- "cursor" follows the cursor's scope; "topline" follows the top of the
    --- window. "cursor" is more useful when navigating within a long function.
    mode = "cursor",
    --- "outer" trims the outermost context when there is not enough room,
    --- keeping the innermost (most relevant) scope visible.
    trim_scope = "outer",
  },

  --- Grow/shrink a visual selection along the syntax tree.
  --- Reimplemented locally because the upstream module was deleted; see
  --- lua/util/incsel.lua for the full explanation.
  incremental_selection = {
    enable = true,
    keys = {
      init = "<C-space>", -- normal mode: select the node under the cursor
      expand = "<C-space>", -- visual mode: grow to the parent node
      shrink = "<BS>", -- visual mode: back down to the child
      scope = "<A-space>", -- visual mode: jump out to the enclosing construct
    },
  },

  --- Install a parser automatically the first time you open a file of a type that
  --- does not have one yet. This is most of why "add a language" is nearly free.
  --- Set false if you would rather run :TSInstall by hand.
  auto_install = true,
}

-- ═════════════════════════════════════════════════════════════════════════════
-- PARSERS
-- ═════════════════════════════════════════════════════════════════════════════
--- Grouped so it is obvious what each entry is FOR, and so a group can be removed
--- wholesale. Each parser is a one-off compile; already-installed ones are skipped
--- on later launches.
---
--- TO ADD A LANGUAGE: append to the right group. Or just open a file of that type
--- and let `auto_install` above handle it. `:checkhealth nvim-treesitter` lists
--- what is installed; the full catalogue of ~320 names is:
---     :lua =require("nvim-treesitter.config").get_available()
local parser_groups = {
  --- Editing this config, and Neovim's own files.
  editor = { "lua", "luadoc", "vim", "vimdoc", "query", "regex", "comment" },

  --- The three languages this config is set up for.
  rust = { "rust", "toml" },
  python = { "python", "requirements" },
  web = { "typescript", "tsx", "javascript", "jsdoc", "html", "css", "scss" },

  --- C and C++ — worth having even in a Rust-only setup, because FFI headers,
  --- build scripts and bindgen output all turn up eventually.
  c = { "c", "cpp" },

  --- Config and data formats.
  --- NOTE: there is no `jsonc` parser. JSON-with-comments is parsed by the `json`
  --- parser via the alias registered in the config below. Listing "jsonc" here
  --- produces "skipping unsupported language: jsonc".
  data = { "json", "json5", "yaml", "xml", "sql", "csv" },

  --- Shell and build tooling.
  build = { "bash", "make", "cmake", "ninja", "dockerfile", "just", "ssh_config" },

  --- Docs.
  docs = { "markdown", "markdown_inline", "rst" },

  --- Git.
  git = { "git_config", "git_rebase", "gitcommit", "gitignore", "gitattributes", "diff" },

  --- Miscellaneous but frequently embedded in other languages.
  misc = { "printf", "editorconfig" },
}

--- Flatten the groups into the list actually passed to install().
local ensure_parsers = {}
for _, group in pairs(parser_groups) do
  vim.list_extend(ensure_parsers, group)
end

return {
  -- ═════════════════════════════════════════════════════════════════════════
  -- NVIM-TREESITTER (main branch)
  -- ═════════════════════════════════════════════════════════════════════════
  {
    "nvim-treesitter/nvim-treesitter",
    -- Required: the main branch explicitly does not support lazy loading.
    lazy = false,
    branch = "main",
    -- Recompile every installed parser after the plugin updates, since a parser
    -- built against an older ABI can crash Neovim.
    build = ":TSUpdate",

    cmd = { "TSInstall", "TSUpdate", "TSLog", "TSUninstall" },

    config = function()
      require("nvim-treesitter").setup({
        -- Parsers land in stdpath("data")/site/parser, which is already on the
        -- runtimepath. Deliberately NOT inside this repo — compiled .so/.dll files
        -- are platform-specific and must not be committed or synced to Linux.
        install_dir = vim.fn.stdpath("data") .. "/site",
      })

      -- ── Filetype → parser aliases ─────────────────────────────────────────
      -- Some filetypes have no parser of their own and are handled by another
      -- language's grammar. Registering the alias is what makes highlighting work
      -- in these files; without it they fall back to no treesitter at all.
      local aliases = {
        json = { "jsonc" }, -- JSON with comments (tsconfig, .eslintrc)
        bash = { "zsh", "sh", "shell" }, -- no separate zsh grammar exists
        markdown = { "mdx" },
        ini = { "properties", "dosini" },
      }
      for lang, filetypes in pairs(aliases) do
        pcall(vim.treesitter.language.register, lang, filetypes)
      end

      -- ── Install the parsers, in the background ────────────────────────────
      -- `install()` is async and returns immediately; it will not block startup.
      if vim.fn.executable("tree-sitter") == 1 then
        require("nvim-treesitter").install(ensure_parsers)
      else
        vim.schedule(function()
          vim.notify(
            "The `tree-sitter` CLI is not on your PATH, so parsers cannot be built.\n"
              .. "Install it, then run :TSInstall.\n"
              .. "  Windows: install.ps1 -InstallTools\n"
              .. "  Linux:   ./install.sh --tools",
            vim.log.levels.WARN,
            { title = "nvim-treesitter" }
          )
        end)
      end

      -- ── Prettier folds ────────────────────────────────────────────────────
      if ts.folds.custom_foldtext then
        require("util.folds").enable()
      end

      -- ── Incremental selection ─────────────────────────────────────────────
      if ts.incremental_selection.enable then
        require("util.incsel").setup(ts.incremental_selection.keys)
      end

      -- ── Enable highlighting and indentation per buffer ─────────────────────
      -- On the main branch this is your job, not the plugin's. Rather than
      -- maintaining a hardcoded filetype list, this resolves the language from the
      -- filetype and starts treesitter if a parser exists — so it works for every
      -- parser you install later without editing this file.
      local group = vim.api.nvim_create_augroup("treesitter_start", { clear = true })

      -- Languages we have already tried to auto-install, so one with no parser
      -- available does not retry on every buffer.
      local attempted = {}

      vim.api.nvim_create_autocmd("FileType", {
        group = group,
        desc = "Start treesitter highlighting and indentation",
        callback = function(ev)
          local ft = vim.bo[ev.buf].filetype
          if ft == "" then
            return
          end

          -- snacks.bigfile sets this on huge files; respect it rather than
          -- freezing on a 40 MB log. This also disables rainbow delimiters and
          -- folding for that buffer, since both are treesitter-driven.
          if vim.b[ev.buf].bigfile then
            return
          end

          if vim.tbl_contains(ts.highlight.disable, ft) then
            return
          end

          local lang = vim.treesitter.language.get_lang(ft) or ft

          -- pcall because a filetype can map to a language whose parser is not
          -- installed, which is not an error worth reporting.
          local started = ts.highlight.enable and pcall(vim.treesitter.start, ev.buf, lang)

          if started then
            if ts.indent.enable and not vim.tbl_contains(ts.indent.disable, lang) then
              vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
            end
            if ts.highlight.additional_regex then
              vim.bo[ev.buf].syntax = "ON"
            end
          elseif ts.auto_install and not attempted[lang] then
            -- ── AUTO-INSTALL A MISSING PARSER ──────────────────────────────
            -- Open a .go file for the first time and its parser installs itself.
            attempted[lang] = true
            local ok, config = pcall(require, "nvim-treesitter.config")
            if ok and vim.tbl_contains(config.get_available() or {}, lang) then
              vim.notify("Installing treesitter parser: " .. lang, vim.log.levels.INFO, { title = "nvim-treesitter" })
              require("nvim-treesitter").install({ lang }):await(function()
                -- Re-enter the buffer so highlighting starts now rather than on
                -- the next open.
                if vim.api.nvim_buf_is_valid(ev.buf) then
                  pcall(vim.treesitter.start, ev.buf, lang)
                end
              end)
            end
          end
        end,
      })

      -- ── Convenience command: what is treesitter doing in this buffer? ─────
      vim.api.nvim_create_user_command("TSStatus", function()
        local buf = vim.api.nvim_get_current_buf()
        local ft = vim.bo[buf].filetype
        local lang = vim.treesitter.language.get_lang(ft) or ft
        local active = vim.treesitter.highlighter.active[buf] ~= nil
        local lines = {
          "# Treesitter status",
          "",
          ("filetype       %s"):format(ft ~= "" and ft or "(none)"),
          ("language       %s"):format(lang),
          ("highlighting   %s"):format(active and "ON" or "off"),
          ("indentexpr     %s"):format(vim.bo[buf].indentexpr ~= "" and vim.bo[buf].indentexpr or "(vim default)"),
          ("foldmethod     %s / %s"):format(vim.wo.foldmethod, vim.wo.foldexpr),
          ("foldtext       %s"):format(vim.o.foldtext ~= "" and vim.o.foldtext or "(built-in)"),
          ("bigfile        %s"):format(tostring(vim.b[buf].bigfile or false)),
        }
        vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "TSStatus" })
      end, { desc = "Report treesitter state for the current buffer" })
    end,
  },

  -- ═════════════════════════════════════════════════════════════════════════
  -- RAINBOW DELIMITERS — bracket nesting by colour
  -- ═════════════════════════════════════════════════════════════════════════
  -- The clearest win is Rust generics and nested closures: matching the closing
  -- angle bracket in `Result<Vec<HashMap<String, Box<dyn Error>>>, io::Error>` by
  -- eye is otherwise guesswork. Colours come from lua/config/palette.lua
  -- (M.rainbow) and are applied as highlight groups in lua/plugins/colorscheme.lua.
  {
    "HiPhish/rainbow-delimiters.nvim",
    branch = "master",
    enabled = ts.rainbow.enable,
    event = { "BufReadPost", "BufNewFile" },
    keys = {
      {
        "<leader>ur",
        function()
          require("rainbow-delimiters").toggle(0)
        end,
        desc = "Toggle rainbow delimiters (buffer)",
      },
    },
    config = function()
      -- rainbow-delimiters is configured through a global table rather than a
      -- setup() call, which is unusual but deliberate: it lets a project-local
      -- .nvim.lua override it.
      local rd = require("rainbow-delimiters")

      -- Nesting order = the order of the highlight groups in this list.
      local highlight = {}
      for _, level in ipairs(P.rainbow) do
        table.insert(highlight, "RainbowDelimiter" .. level.name)
      end

      vim.g.rainbow_delimiters = {
        strategy = {
          -- "global" colours every delimiter in the buffer. "local" colours only
          -- the ones enclosing the cursor, which is cheaper on very large files
          -- but makes the colours move as you navigate.
          [""] = rd.strategy["global"],
        },
        query = ts.rainbow.query,
        highlight = highlight,
        -- Above treesitter's default 100 so the nesting colour wins over the
        -- normal punctuation highlight, but below semantic tokens (125) so it
        -- never overrides LSP information.
        priority = { [""] = 110 },
        blacklist = ts.rainbow.blacklist,
      }
    end,
  },

  -- ═════════════════════════════════════════════════════════════════════════
  -- TEXT OBJECTS: structural MOVEMENT and SWAPPING
  -- ═════════════════════════════════════════════════════════════════════════
  -- Selection text objects (`af`, `if`, `ac`, `ic`, `aa`, `ia`) come from mini.ai
  -- in lua/plugins/editor.lua, which uses the same treesitter queries.
  -- This plugin adds the two things mini.ai does not do:
  --   MOVE  ]f / [f jump between functions, ]c / [c between classes
  --   SWAP  <leader>cs swaps the argument under the cursor with the next one
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    branch = "main",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      require("nvim-treesitter-textobjects").setup({
        move = {
          -- Add each jump to the jumplist, so <C-o> comes back.
          set_jumps = true,
        },
      })

      local move = require("nvim-treesitter-textobjects.move")
      local swap = require("nvim-treesitter-textobjects.swap")

      --- Build a movement mapping for a treesitter capture.
      local function map_move(key, capture, dir, edge, desc)
        local fn = ("goto_%s_%s"):format(dir, edge)
        vim.keymap.set({ "n", "x", "o" }, key, function()
          move[fn](capture, "textobjects")
        end, { desc = desc, silent = true })
      end

      -- Jump between definitions. `]f` to the start of the next function, `]F` to
      -- its end — the pair means you can step through a file structurally instead
      -- of scrolling.
      map_move("]f", "@function.outer", "next", "start", "Next function start")
      map_move("[f", "@function.outer", "prev", "start", "Previous function start")
      map_move("]F", "@function.outer", "next", "end", "Next function end")
      map_move("[F", "@function.outer", "prev", "end", "Previous function end")

      map_move("]c", "@class.outer", "next", "start", "Next class start")
      map_move("[c", "@class.outer", "prev", "start", "Previous class start")

      map_move("]a", "@parameter.inner", "next", "start", "Next parameter")
      map_move("[a", "@parameter.inner", "prev", "start", "Previous parameter")

      map_move("]/", "@comment.outer", "next", "start", "Next comment")
      map_move("[/", "@comment.outer", "prev", "start", "Previous comment")

      -- Reorder arguments and list items without cutting and pasting.
      vim.keymap.set("n", "<leader>cs", function()
        swap.swap_next("@parameter.inner")
      end, { desc = "Swap parameter with next" })
      vim.keymap.set("n", "<leader>cS", function()
        swap.swap_previous("@parameter.inner")
      end, { desc = "Swap parameter with previous" })
    end,
  },

  -- ═════════════════════════════════════════════════════════════════════════
  -- STICKY CONTEXT HEADER
  -- ═════════════════════════════════════════════════════════════════════════
  -- Pins the enclosing function/class/if signature to the top of the window while
  -- you scroll through a long body. Answers "which function am I in?" without
  -- scrolling back up — the most useful passive treesitter feature.
  {
    "nvim-treesitter/nvim-treesitter-context",
    enabled = ts.context.enable,
    event = { "BufReadPost", "BufNewFile" },
    keys = {
      { "<leader>ut", "<cmd>TSContextToggle<cr>", desc = "Toggle sticky context" },
      {
        -- Jump up to the context line, i.e. to the enclosing function's signature.
        "[C",
        function()
          require("treesitter-context").go_to_context(vim.v.count1)
        end,
        desc = "Jump to enclosing context",
      },
    },
    opts = function()
      return {
        enable = true,
        max_lines = ts.context.max_lines,
        min_window_height = ts.context.min_window_height,
        multiline_threshold = ts.context.multiline_threshold,
        trim_scope = ts.context.trim_scope,
        mode = ts.context.mode,
        -- A separator line under the context reads as heavy against a coloured
        -- background; the TreesitterContext highlight already separates it.
        separator = nil,
        zindex = 20,
        -- Do not show context in these — they have their own headers.
        exclude_filetypes = { "markdown", "dashboard", "snacks_dashboard", "help" },
      }
    end,
  },

  -- ═════════════════════════════════════════════════════════════════════════
  -- AUTO-CLOSE HTML / JSX TAGS
  -- ═════════════════════════════════════════════════════════════════════════
  -- Type `<div>` and get `</div>`; rename the opening tag and the closing one
  -- follows. Treesitter-aware, so it works inside .tsx and template strings.
  {
    "windwp/nvim-ts-autotag",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    ft = {
      "html",
      "xml",
      "javascript",
      "javascriptreact",
      "typescript",
      "typescriptreact",
      "svelte",
      "vue",
      "markdown",
      "php",
      "astro",
    },
    opts = {
      opts = {
        enable_close = true,
        enable_rename = true,
        enable_close_on_slash = true,
      },
    },
  },
}
