--- ~/.config/nvim/lua/plugins/treesitter.lua
---
--- Treesitter parses your code into a real syntax tree, which powers accurate
--- highlighting, indentation, folding, text objects and structural navigation.
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

--- Parsers installed up front. Keep this list to things you actually open —
--- each one is a compile step.
---
--- TO ADD A LANGUAGE: append it here, restart, and run `:TSInstall <lang>` (or
--- just open a file of that type — the autocmd below installs it automatically).
--- `:checkhealth nvim-treesitter` lists what is installed.
local ensure_parsers = {
  -- The three languages this config is set up for
  "rust", "python", "typescript", "javascript", "tsx",
  -- Config and data formats you cannot avoid.
  -- NOTE: there is no separate `jsonc` parser — JSON-with-comments is parsed by
  -- the `json` parser, wired up via language.register() in the config below.
  -- Listing "jsonc" here produces "skipping unsupported language: jsonc".
  "json", "yaml", "toml", "xml", "sql",
  -- Web
  "html", "css", "scss",
  -- Shell and build
  "bash", "make", "cmake", "ninja", "dockerfile",
  -- Docs
  "markdown", "markdown_inline", "rst",
  -- Git
  "git_config", "git_rebase", "gitcommit", "gitignore", "diff",
  -- Editing this config
  "lua", "luadoc", "vim", "vimdoc", "query",
  -- Miscellaneous but frequently embedded
  "regex", "comment", "printf", "ssh_config", "requirements",
}

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

    keys = {
      -- Incremental selection: start at the smallest node under the cursor and
      -- grow outward through the syntax tree. `<C-space>` to expand,
      -- `<BS>` to shrink. Far more precise than `v` plus motions.
      {
        "<C-space>",
        function()
          require("nvim-treesitter.incremental_selection").init_selection()
        end,
        mode = "n",
        desc = "Start incremental selection",
      },
    },

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
        json = { "jsonc", "json5" },      -- JSON with comments / trailing commas
        bash = { "zsh", "sh" },           -- no separate zsh grammar
        markdown = { "mdx" },
        typescript = { "javascript.jsx" },
      }
      for lang, filetypes in pairs(aliases) do
        vim.treesitter.language.register(lang, filetypes)
      end

      -- ── Install the parsers listed above, in the background ───────────────
      -- `install()` is async and returns immediately; it will not block startup.
      -- Already-installed parsers are skipped, so this is cheap on every launch
      -- after the first.
      if vim.fn.executable("tree-sitter") == 1 then
        require("nvim-treesitter").install(ensure_parsers)
      else
        vim.schedule(function()
          vim.notify(
            "The `tree-sitter` CLI is not on your PATH, so parsers cannot be built.\n"
              .. "Install it, then run :TSInstall.\n"
              .. "  Windows: install.ps1 -InstallTools\n"
              .. "  Linux:   cargo install tree-sitter-cli  (or your package manager)",
            vim.log.levels.WARN,
            { title = "nvim-treesitter" }
          )
        end)
      end

      -- ── Enable highlighting and indentation per buffer ─────────────────────
      -- On the main branch this is your job, not the plugin's. Rather than
      -- maintaining a hardcoded filetype list, this resolves the language from the
      -- filetype and starts treesitter if a parser exists — so it works for every
      -- parser you install later without editing this file.
      local ts_group = vim.api.nvim_create_augroup("treesitter_start", { clear = true })

      -- Remember which languages we have already tried to auto-install, so a
      -- language with no parser available does not retry on every buffer.
      local attempted = {}

      vim.api.nvim_create_autocmd("FileType", {
        group = ts_group,
        desc = "Start treesitter highlighting and indentation",
        callback = function(ev)
          local ft = vim.bo[ev.buf].filetype
          if ft == "" then
            return
          end

          -- snacks.bigfile sets this on huge files; respect it rather than
          -- freezing on a 40 MB log.
          if vim.b[ev.buf].bigfile then
            return
          end

          local lang = vim.treesitter.language.get_lang(ft) or ft

          -- Start highlighting. pcall because a filetype can map to a language
          -- whose parser is not installed, which is not an error worth reporting.
          local started = pcall(vim.treesitter.start, ev.buf, lang)

          if started then
            -- Treesitter-based indentation. Set per buffer, and only when a parser
            -- actually loaded — otherwise you get an indentexpr that errors on
            -- every newline.
            --
            -- Exception: some languages' treesitter indent queries are worse than
            -- their hand-written vim indent script. Python is the notable one
            -- (continuation lines and hanging indents), so it keeps the built-in.
            if lang ~= "python" then
              vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
            end
          elseif not attempted[lang] then
            -- ── AUTO-INSTALL A MISSING PARSER ──────────────────────────────
            -- Open a .go file for the first time and its parser installs itself.
            -- This is the main reason "add a new language" is nearly free here.
            attempted[lang] = true
            local ok, config = pcall(require, "nvim-treesitter.config")
            if ok and vim.tbl_contains(config.get_available() or {}, lang) then
              vim.notify("Installing treesitter parser: " .. lang, vim.log.levels.INFO,
                { title = "nvim-treesitter" })
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
      --- @param key string the key to map
      --- @param capture string e.g. "@function.outer"
      --- @param dir "next"|"prev"
      --- @param edge "start"|"end"
      --- @param desc string
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
  -- scrolling back up — the single most useful passive treesitter feature.
  {
    "nvim-treesitter/nvim-treesitter-context",
    event = { "BufReadPost", "BufNewFile" },
    keys = {
      { "<leader>ut", "<cmd>TSContextToggle<cr>", desc = "Toggle sticky context" },
      {
        -- Jump to the context line, i.e. up to the enclosing function's signature.
        "[C",
        function() require("treesitter-context").go_to_context(vim.v.count1) end,
        desc = "Jump to enclosing context",
      },
    },
    opts = {
      enable = true,
      -- Keep it shallow: three nested lines of context is informative, ten eats
      -- half the window.
      max_lines = 3,
      min_window_height = 20, -- do not steal rows in a short split
      multiline_threshold = 1, -- collapse a multi-line signature to one line
      trim_scope = "outer",
      mode = "cursor",
      separator = nil, -- a separator line looks heavy with a coloured background
      zindex = 20,
    },
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
      "html", "xml", "javascript", "javascriptreact", "typescript",
      "typescriptreact", "svelte", "vue", "markdown", "php", "astro",
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
