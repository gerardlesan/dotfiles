--- ~/.config/nvim/lua/plugins/snacks.lua
---
--- snacks.nvim is a collection of ~25 small, independent modules by the author of
--- lazy.nvim and which-key. It is used here for a lot of what would otherwise be
--- eight separate plugins:
---
---   picker        fuzzy finder (files, grep, symbols, keymaps, git, undo, ...)
---   image         inline image rendering in the terminal   ← "image viewing"
---   dashboard     the startup screen
---   notifier      floating notifications (replaces nvim-notify)
---   indent        indent guides + active-scope highlight
---   scroll        smooth scrolling
---   statuscolumn  merged number / sign / fold gutter
---   bigfile       auto-disable expensive features on huge files
---   lazygit       lazygit in a float, with the theme applied
---   terminal      toggleable floating terminal
---   zen           distraction-free mode
---   toggle        option toggles that show live state in which-key
---   bufdelete     close a buffer without wrecking the window layout
---   words         highlight other occurrences of the symbol under the cursor
---   scope, quickfile, input, rename, gitbrowse
---
--- WHY THIS INSTEAD OF TELESCOPE for the picker: telescope's fast sorter
--- (telescope-fzf-native) is a C extension that must be compiled with make/cmake.
--- On Windows that means dragging in a build toolchain purely for a fuzzy sorter,
--- and it is a recurring source of "works on my Linux box, broken on Windows".
--- snacks.picker is pure Lua, needs no compilation, is faster in practice, and is
--- identical on both platforms — which is the whole point of this config.
--- Telescope remains the more widely documented choice; see the README for how to
--- swap it in if you would rather.

local P = require("config.palette")
local icons = P.icons

return {
  {
    "folke/snacks.nvim",
    -- Not lazy: several modules (bigfile, quickfile, statuscolumn, dashboard)
    -- must be active before the first buffer is drawn to do their job at all.
    priority = 1000,
    lazy = false,

    ---@type snacks.Config
    opts = {
      -- ══ Big files ═══════════════════════════════════════════════════════════
      -- Above ~1.5 MB, turn off treesitter, LSP, folding, syntax and indent
      -- guides for that buffer. Opening a 40 MB log file goes from "Neovim hangs
      -- for a minute" to instant. This replaces the hand-rolled LargeFile autocmd
      -- most configs carry.
      bigfile = { enabled = true },

      -- ══ Quickfile ═══════════════════════════════════════════════════════════
      -- When you run `nvim file.rs`, render the file *before* loading plugins, so
      -- the text appears immediately instead of after the plugin sync.
      quickfile = { enabled = true },

      -- ══ Statuscolumn ════════════════════════════════════════════════════════
      -- One gutter that intelligently merges line numbers, git signs, diagnostic
      -- signs and fold markers, instead of them fighting for the same column.
      statuscolumn = {
        enabled = true,
        left = { "mark", "sign" }, -- marks and non-git signs on the left
        right = { "fold", "git" }, -- fold markers and git signs on the right
        folds = {
          open = true, -- show the fold marker only when foldable
          git_hl = true, -- colour the fold marker by git status
        },
        git = { patterns = { "GitSign", "MiniDiffSign" } },
      },

      -- ══ Indent guides ═══════════════════════════════════════════════════════
      indent = {
        enabled = true,
        indent = {
          char = "│",
          -- Colour comes from SnacksIndent (near-invisible) in colorscheme.lua.
          hl = "SnacksIndent",
        },
        -- The "scope" is the block the cursor is currently inside. Highlighting
        -- just that one guide in red is what makes indent guides genuinely useful
        -- rather than fifty decorative vertical lines.
        scope = {
          enabled = true,
          char = "│",
          underline = false,
          hl = "SnacksIndentScope",
        },
        -- Animate the scope guide drawing in. Purely cosmetic; this is the
        -- "flourish" you asked for and it costs nothing because it is rendered
        -- with extmarks, not by redrawing the buffer.
        animate = {
          enabled = true,
          duration = { step = 15, total = 200 },
        },
        chunk = { enabled = false }, -- bracket-style chunk outline; busy with scope on
      },

      -- ══ Scope detection ═════════════════════════════════════════════════════
      -- Treesitter-aware text objects for "the current block": `ii`/`ai` in
      -- operator-pending mode, and `]i`/`[i` to jump between scopes.
      scope = { enabled = true },

      -- ══ Smooth scrolling ════════════════════════════════════════════════════
      -- Animates <C-d>, <C-u>, `gg`, `G` and search jumps so you can see *where*
      -- you moved rather than teleporting. Genuinely helps orientation in a long
      -- file. Toggle with <leader>uS if it ever feels slow.
      scroll = {
        enabled = true,
        animate = { duration = { step = 15, total = 250 }, easing = "linear" },
      },

      -- ══ Word highlighting ═══════════════════════════════════════════════════
      -- Highlights other occurrences of the symbol under the cursor using LSP
      -- document highlight, and lets you jump between them with `]]` / `[[`.
      words = { enabled = true, debounce = 200 },

      -- ══ Notifications ═══════════════════════════════════════════════════════
      -- Replaces the command-line message area for vim.notify with stacked
      -- floating toasts. History is browsable with <leader>n.
      notifier = {
        enabled = true,
        timeout = 3000,
        style = "compact",
        top_down = false, -- stack up from the bottom-right, out of the way
        icons = {
          error = icons.diagnostics.Error,
          warn = icons.diagnostics.Warn,
          info = icons.diagnostics.Info,
          debug = icons.ui.debug,
          trace = icons.ui.dot,
        },
      },

      -- ══ Better vim.ui.input ═════════════════════════════════════════════════
      -- Turns the bottom-line prompt (used by LSP rename, among others) into a
      -- small float at the cursor.
      input = { enabled = true },

      -- ══ Fuzzy picker ════════════════════════════════════════════════════════
      picker = {
        enabled = true,
        -- "select" replaces vim.ui.select, so LSP code-action menus and similar
        -- use the picker instead of a numbered list on the command line.
        ui_select = true,
        layout = {
          preset = "default", -- side-by-side list + preview
          cycle = true,
        },
        matcher = {
          fuzzy = true,
          smartcase = true,
          -- Rank files whose *path* matches too, not just the filename.
          filename_bonus = true,
          -- Boost recently-opened files, which is usually what you want.
          frecency = true,
        },
        formatters = {
          file = {
            filename_first = true, -- "options.lua  lua/config/" reads better than
            -- the full path with the name buried at the end
            truncate = 80,
          },
        },
        win = {
          input = {
            keys = {
              -- <Esc> closes the picker from insert mode directly, rather than
              -- dropping to normal mode inside it first.
              ["<Esc>"] = { "close", mode = { "n", "i" } },
              ["<C-c>"] = { "close", mode = { "n", "i" } },
              -- Ctrl-based navigation so your hands never leave the home row.
              ["<C-j>"] = { "list_down", mode = { "i", "n" } },
              ["<C-k>"] = { "list_up", mode = { "i", "n" } },
              ["<C-d>"] = { "list_scroll_down", mode = { "i", "n" } },
              ["<C-u>"] = { "list_scroll_up", mode = { "i", "n" } },
              -- Send the whole result set to the quickfix list — the escape hatch
              -- when a picker gives you 200 matches you want to work through.
              ["<C-q>"] = { "qflist", mode = { "i", "n" } },
              ["<C-s>"] = { "edit_split", mode = { "i", "n" } },
              ["<C-v>"] = { "edit_vsplit", mode = { "i", "n" } },
              -- Toggle the preview pane when you need the full width for the list.
              ["<C-p>"] = { "toggle_preview", mode = { "i", "n" } },
            },
          },
        },
        -- Exclude noise from every file/grep picker. ripgrep and fd already
        -- respect .gitignore; these are the directories that are not in it.
        exclude = {
          ".git",
          "node_modules",
          "target",
          "dist",
          "build",
          "__pycache__",
          ".venv",
          "venv",
          ".mypy_cache",
          ".ruff_cache",
          ".pytest_cache",
          "*.lock",
          ".next",
          ".turbo",
        },
        sources = {
          files = { hidden = true }, -- show dotfiles: this repo is one
          grep = { hidden = true },
          explorer = { hidden = true },
        },
      },

      -- ══ Image viewing ═══════════════════════════════════════════════════════
      -- Renders real images in the terminal via the Kitty graphics protocol.
      --
      -- WHAT WORKS:
      --   * `nvim screenshot.png` shows the image, not binary garbage
      --   * images referenced in markdown render inline under the link
      --   * LaTeX math in markdown renders as an image
      --   * <leader>ii shows the image under the cursor in a float
      --
      -- TERMINAL SUPPORT — read this before filing a bug against yourself:
      --   Kitty, Ghostty  full support
      --   WezTerm         works, but its Kitty-graphics implementation is partial
      --                   (no Unicode placeholders), so inline images inside a
      --                   scrolling document can leave artefacts. Press <C-l> to
      --                   redraw if that happens. Float mode (<leader>ii) is
      --                   reliable.
      --   tmux            needs `set -g allow-passthrough on`
      --   Windows Console / conhost   no support at all
      --
      -- ImageMagick (`magick`) is required for anything that is not already a PNG
      -- — it converts on the fly. Installed by the install script.
      image = {
        enabled = true,
        formats = {
          "png",
          "jpg",
          "jpeg",
          "gif",
          "bmp",
          "webp",
          "tiff",
          "heic",
          "avif",
          "svg",
          "pdf",
        },
        doc = {
          enabled = true,
          -- Render images inline in the document at the reference.
          inline = true,
          -- Also allow opening in a float with <leader>ii.
          float = true,
          max_width = 60,
          max_height = 30,
        },
        -- Directories searched for a relative image path in markdown.
        img_dirs = {
          "img",
          "images",
          "assets",
          "static",
          "public",
          "media",
          "attachments",
          "docs/images",
        },
        convert = {
          notify = true, -- tell you when ImageMagick is missing rather than
          -- silently rendering nothing
        },
        -- Render $...$ and $$...$$ LaTeX as images in markdown. Needs a TeX
        -- distribution; harmless if absent (it just does nothing).
        math = { enabled = true },
      },

      -- ══ Dashboard ═══════════════════════════════════════════════════════════
      dashboard = {
        enabled = true,
        preset = {
          -- Box-drawing characters, not Nerd Font glyphs, so this renders in any
          -- font. Colour comes from SnacksDashboardHeader (red) in colorscheme.lua.
          header = table.concat({
            "",
            "   ███╗   ██╗██╗   ██╗██╗███╗   ███╗",
            "   ████╗  ██║██║   ██║██║████╗ ████║",
            "   ██╔██╗ ██║██║   ██║██║██╔████╔██║",
            "   ██║╚██╗██║╚██╗ ██╔╝██║██║╚██╔╝██║",
            "   ██║ ╚████║ ╚████╔╝ ██║██║ ╚═╝ ██║",
            "   ╚═╝  ╚═══╝  ╚═══╝  ╚═╝╚═╝     ╚═╝",
            "",
          }, "\n"),
          keys = {
            { icon = icons.ui.search, key = "f", desc = "Find File", action = ":lua Snacks.dashboard.pick('files')" },
            { icon = icons.file.newfile, key = "n", desc = "New File", action = ":ene | startinsert" },
            {
              icon = icons.ui.search,
              key = "g",
              desc = "Grep Text",
              action = ":lua Snacks.dashboard.pick('live_grep')",
            },
            {
              icon = icons.ui.folder,
              key = "r",
              desc = "Recent Files",
              action = ":lua Snacks.dashboard.pick('oldfiles')",
            },
            { icon = icons.ui.branch, key = "G", desc = "Lazygit", action = ":lua Snacks.lazygit()" },
            {
              icon = icons.ui.lsp,
              key = "c",
              desc = "Config",
              action = ":lua Snacks.dashboard.pick('files', { cwd = vim.fn.stdpath('config') })",
            },
            { icon = icons.ui.chevron, key = "s", desc = "Restore Session", section = "session" },
            {
              icon = icons.ui.lightning,
              key = "l",
              desc = "Lazy",
              action = ":Lazy",
              enabled = package.loaded.lazy ~= nil,
            },
            { icon = icons.diagnostics.Error, key = "q", desc = "Quit", action = ":qa" },
          },
        },
        sections = {
          { section = "header" },
          { section = "keys", gap = 1, padding = 1 },
          {
            section = "recent_files",
            icon = icons.ui.folder,
            title = "Recent Files",
            indent = 2,
            padding = 1,
            limit = 5,
          },
          -- Uncommitted changes in the current repo, right on the start screen.
          {
            section = "git",
            icon = icons.ui.branch,
            title = "Git Status",
            enabled = function()
              return Snacks.git.get_root() ~= nil
            end,
            cmd = "git status --short --branch --renames",
            height = 6,
            padding = 1,
            indent = 2,
          },
          { section = "startup" },
        },
      },

      -- ══ Styles ══════════════════════════════════════════════════════════════
      -- Per-window overrides for snacks' own floats.
      styles = {
        notification = {
          wo = { wrap = true }, -- wrap long notification text instead of clipping
        },
        lazygit = {
          width = 0, -- 0 = full width
          height = 0, -- 0 = full height
        },
      },

      -- ══ Explicitly DISABLED modules ═════════════════════════════════════════
      -- snacks has its own file explorer, but neo-tree (lua/plugins/explorer.lua)
      -- is the more capable and far more widely documented choice, with git
      -- status, buffer and symbol sources built in. Running both would give you
      -- two competing explorers on <leader>e.
      explorer = { enabled = false },
      -- Neovim 0.11+ has good built-in LSP progress reporting, and noice.nvim
      -- renders it in the statusline. This module would duplicate it.
      -- gitbrowse and rename ARE available as functions without being "enabled".
    },

    -- ══ Keymaps ═════════════════════════════════════════════════════════════
    -- Defined in the spec (not keymaps.lua) so lazy.nvim knows these keys belong
    -- to snacks. Since snacks is `lazy = false` that does not change loading, but
    -- it keeps each plugin's bindings discoverable in one place.
    keys = {
      -- ── Top-level, most-used ──────────────────────────────────────────────
      {
        "<leader><space>",
        function()
          Snacks.picker.smart()
        end,
        desc = "Find files (smart)",
      },
      {
        "<leader>/",
        function()
          Snacks.picker.grep()
        end,
        desc = "Grep project",
      },
      {
        "<leader>,",
        function()
          Snacks.picker.buffers()
        end,
        desc = "Switch buffer",
      },
      {
        "<leader>:",
        function()
          Snacks.picker.command_history()
        end,
        desc = "Command history",
      },
      {
        "<leader>n",
        function()
          Snacks.picker.notifications()
        end,
        desc = "Notification history",
      },

      -- ── Find (<leader>f) ──────────────────────────────────────────────────
      {
        "<leader>ff",
        function()
          Snacks.picker.files()
        end,
        desc = "Find files",
      },
      {
        "<leader>fF",
        function()
          Snacks.picker.files({ cwd = vim.fn.expand("%:p:h") })
        end,
        desc = "Find files (this dir)",
      },
      {
        "<leader>fg",
        function()
          Snacks.picker.git_files()
        end,
        desc = "Find git files",
      },
      {
        "<leader>fr",
        function()
          Snacks.picker.recent()
        end,
        desc = "Recent files",
      },
      {
        "<leader>fb",
        function()
          Snacks.picker.buffers()
        end,
        desc = "Buffers",
      },
      {
        "<leader>fC",
        function()
          Snacks.picker.files({ cwd = vim.fn.stdpath("config") })
        end,
        desc = "Find in config",
      },
      {
        "<leader>fz",
        function()
          Snacks.picker.zoxide()
        end,
        desc = "Zoxide directories",
      },

      -- ── Search (<leader>s) ────────────────────────────────────────────────
      {
        "<leader>sg",
        function()
          Snacks.picker.grep()
        end,
        desc = "Grep project",
      },
      {
        "<leader>sB",
        function()
          Snacks.picker.grep_buffers()
        end,
        desc = "Grep open buffers",
      },
      {
        "<leader>sw",
        function()
          Snacks.picker.grep_word()
        end,
        desc = "Grep word under cursor",
        mode = { "n", "x" },
      },
      {
        "<leader>sb",
        function()
          Snacks.picker.lines()
        end,
        desc = "Search lines in buffer",
      },
      -- THE KEYBINDINGS SCREEN, searchable. which-key shows what is available
      -- from a prefix; this searches every mapping by description.
      {
        "<leader>sk",
        function()
          Snacks.picker.keymaps()
        end,
        desc = "Search keymaps",
      },
      {
        "<leader>sh",
        function()
          Snacks.picker.help()
        end,
        desc = "Help pages",
      },
      {
        "<leader>sd",
        function()
          Snacks.picker.diagnostics()
        end,
        desc = "Diagnostics (project)",
      },
      {
        "<leader>sD",
        function()
          Snacks.picker.diagnostics_buffer()
        end,
        desc = "Diagnostics (buffer)",
      },
      {
        "<leader>sc",
        function()
          Snacks.picker.commands()
        end,
        desc = "Commands",
      },
      {
        "<leader>sa",
        function()
          Snacks.picker.autocmds()
        end,
        desc = "Autocommands",
      },
      {
        "<leader>sH",
        function()
          Snacks.picker.highlights()
        end,
        desc = "Highlight groups",
      },
      {
        "<leader>sm",
        function()
          Snacks.picker.marks()
        end,
        desc = "Marks",
      },
      {
        "<leader>sj",
        function()
          Snacks.picker.jumps()
        end,
        desc = "Jump list",
      },
      {
        "<leader>sq",
        function()
          Snacks.picker.qflist()
        end,
        desc = "Quickfix list",
      },
      {
        "<leader>sl",
        function()
          Snacks.picker.loclist()
        end,
        desc = "Location list",
      },
      {
        "<leader>sR",
        function()
          Snacks.picker.resume()
        end,
        desc = "Resume last picker",
      },
      {
        "<leader>su",
        function()
          Snacks.picker.undo()
        end,
        desc = "Undo history",
      },
      {
        '<leader>s"',
        function()
          Snacks.picker.registers()
        end,
        desc = "Registers",
      },
      {
        "<leader>s/",
        function()
          Snacks.picker.search_history()
        end,
        desc = "Search history",
      },
      {
        "<leader>sC",
        function()
          Snacks.picker.colorschemes()
        end,
        desc = "Colorschemes (live preview)",
      },
      {
        "<leader>si",
        function()
          Snacks.picker.icons()
        end,
        desc = "Icons / emoji",
      },
      {
        "<leader>sp",
        function()
          Snacks.picker.projects()
        end,
        desc = "Projects",
      },
      {
        "<leader>sM",
        function()
          Snacks.picker.man()
        end,
        desc = "Man pages",
      },

      -- ── Git (<leader>g) — see also lua/plugins/git.lua ───────────────────
      {
        "<leader>gg",
        function()
          Snacks.lazygit()
        end,
        desc = "Lazygit",
      },
      {
        "<leader>gf",
        function()
          Snacks.lazygit.log_file()
        end,
        desc = "Lazygit: file history",
      },
      {
        "<leader>gl",
        function()
          Snacks.picker.git_log()
        end,
        desc = "Git log",
      },
      {
        "<leader>gL",
        function()
          Snacks.picker.git_log_line()
        end,
        desc = "Git log (current line)",
      },
      {
        "<leader>gs",
        function()
          Snacks.picker.git_status()
        end,
        desc = "Git status",
      },
      {
        "<leader>gS",
        function()
          Snacks.picker.git_stash()
        end,
        desc = "Git stash",
      },
      {
        "<leader>gB",
        function()
          Snacks.picker.git_branches()
        end,
        desc = "Git branches",
      },
      {
        "<leader>gd",
        function()
          Snacks.picker.git_diff()
        end,
        desc = "Git diff (hunks)",
      },
      -- Open the current file (or selection) on the git forge in a browser.
      -- Understands GitHub, GitLab, Bitbucket and Gitea remotes.
      {
        "<leader>go",
        function()
          Snacks.gitbrowse()
        end,
        desc = "Open in browser (git forge)",
        mode = { "n", "x" },
      },

      -- ── Buffers (<leader>b) ───────────────────────────────────────────────
      -- Deletes the buffer while LEAVING THE WINDOW OPEN. Plain `:bdelete` closes
      -- the window too, which silently destroys your split layout.
      {
        "<leader>bd",
        function()
          Snacks.bufdelete()
        end,
        desc = "Delete buffer",
      },
      {
        "<leader>bo",
        function()
          Snacks.bufdelete.other()
        end,
        desc = "Delete other buffers",
      },
      {
        "<leader>bD",
        function()
          Snacks.bufdelete.all()
        end,
        desc = "Delete all buffers",
      },

      -- ── Terminal ──────────────────────────────────────────────────────────
      -- A floating terminal on a single key. <C-/> is what most terminal emulators
      -- send for Ctrl+slash; <C-_> is the same chord as seen by some terminals, so
      -- both are bound.
      {
        "<C-/>",
        function()
          Snacks.terminal()
        end,
        desc = "Toggle terminal",
        mode = { "n", "t" },
      },
      {
        "<C-_>",
        function()
          Snacks.terminal()
        end,
        desc = "Toggle terminal",
        mode = { "n", "t" },
      },
      {
        "<leader>tt",
        function()
          Snacks.terminal()
        end,
        desc = "Toggle terminal",
      },

      -- ── Image (<leader>i) ─────────────────────────────────────────────────
      {
        "<leader>ii",
        function()
          Snacks.image.hover()
        end,
        desc = "Show image under cursor",
      },

      -- ── Zen / focus ───────────────────────────────────────────────────────
      {
        "<leader>z",
        function()
          Snacks.zen()
        end,
        desc = "Zen mode",
      },
      {
        "<leader>Z",
        function()
          Snacks.zen.zoom()
        end,
        desc = "Zoom current window",
      },

      -- ── Rename, with LSP-aware import updating ───────────────────────────
      {
        "<leader>cR",
        function()
          Snacks.rename.rename_file()
        end,
        desc = "Rename file (update imports)",
      },

      -- ── Word navigation (LSP references under cursor) ────────────────────
      {
        "]]",
        function()
          Snacks.words.jump(vim.v.count1)
        end,
        desc = "Next reference",
        mode = { "n", "t" },
      },
      {
        "[[",
        function()
          Snacks.words.jump(-vim.v.count1)
        end,
        desc = "Previous reference",
        mode = { "n", "t" },
      },
    },

    init = function()
      -- Everything here needs snacks to be loaded, so it runs on the VeryLazy
      -- event (after startup, before you can interact).
      vim.api.nvim_create_autocmd("User", {
        pattern = "VeryLazy",
        callback = function()
          -- Global debug helpers, available from `:lua` and from any config file.
          -- `dd(anything)` pretty-prints it in a float — far better than
          -- `print(vim.inspect(x))`. `bt()` prints a backtrace.
          _G.dd = function(...)
            Snacks.debug.inspect(...)
          end
          _G.bt = function()
            Snacks.debug.backtrace()
          end
          -- Route Neovim's own `vim.print` (used by `:=expr`) through it too.
          vim.print = _G.dd

          -- ══ Force the vim.ui overrides ═══════════════════════════════════
          -- `input.enabled = true` and `picker.ui_select = true` above are the
          -- documented way to ask snacks to replace vim.ui.input and
          -- vim.ui.select. But snacks installs each override inside that
          -- module's own setup(), which it defers until the module is first
          -- accessed — so until something happens to touch the picker,
          -- vim.ui.select is still Neovim's built-in.
          --
          -- That matters because vim.ui.select is what LSP code actions
          -- (<leader>ca) go through: without the override you get a numbered
          -- list on the command line instead of the picker. Confirmed by
          -- `:checkhealth snacks`, which reports it as an error.
          --
          -- Assigning through a closure rather than binding the function
          -- directly means snacks can still swap its own implementation later
          -- (its toggle/disable path reassigns these) without this line
          -- pinning a stale reference.
          vim.ui.select = function(...)
            return Snacks.picker.select(...)
          end
          vim.ui.input = function(...)
            return Snacks.input.input(...)
          end

          -- ══ UI TOGGLES (<leader>u) ═══════════════════════════════════════
          -- Snacks.toggle registers each of these with which-key *including its
          -- current state*, so the <leader>u popup shows a filled or hollow icon
          -- per toggle rather than just a list of names. That is the practical
          -- difference between a keybinding list and a control panel.
          local toggle = Snacks.toggle

          toggle.option("wrap", { name = "Wrap" }):map("<leader>uw")
          toggle.option("spell", { name = "Spelling" }):map("<leader>us")
          toggle.option("cursorcolumn", { name = "Cursor Column" }):map("<leader>uu")
          toggle.option("relativenumber", { name = "Relative Numbers" }):map("<leader>uL")
          toggle.line_number():map("<leader>ul")
          toggle
            .option("conceallevel", {
              name = "Conceal",
              off = 0,
              -- Restore to 2 (or whatever markdown set) rather than 1.
              on = vim.o.conceallevel > 0 and vim.o.conceallevel or 2,
            })
            :map("<leader>uc")
          toggle
            .option("background", {
              name = "Dark Background",
              off = "light",
              on = "dark",
            })
            :map("<leader>ub")

          toggle.diagnostics():map("<leader>uD")
          toggle.inlay_hints():map("<leader>uh")
          toggle.treesitter():map("<leader>uT")
          toggle.indent():map("<leader>ug")
          toggle.scroll():map("<leader>uS")
          toggle.dim():map("<leader>uA")

          -- Custom toggle: swap inline virtual_text diagnostics for the
          -- multi-line virtual_lines style. virtual_lines is far better for long
          -- Rust type errors; virtual_text is more compact for everything else.
          -- Having both on at once is redundant, so this flips between them.
          toggle
            .new({
              id = "diagnostic_virtual_lines",
              name = "Diagnostic Virtual Lines",
              get = function()
                return vim.diagnostic.config().virtual_lines ~= false
              end,
              set = function(state)
                if state then
                  vim.diagnostic.config({
                    virtual_lines = { current_line = true },
                    virtual_text = false,
                  })
                else
                  vim.diagnostic.config({
                    virtual_lines = false,
                    virtual_text = {
                      spacing = 4,
                      source = "if_many",
                      prefix = "●",
                      severity = { min = vim.diagnostic.severity.HINT },
                    },
                  })
                end
              end,
            })
            :map("<leader>ud")
        end,
      })

      -- ══ Icon / Nerd Font self-test ═══════════════════════════════════════
      -- `:CheckIcons` renders every glyph this config uses. If any show as a
      -- hollow box or a "?", your terminal font is not a patched Nerd Font — see
      -- the README's font section.
      vim.api.nvim_create_user_command("CheckIcons", function()
        local lines = {
          "# Nerd Font self-test",
          "",
          "Each line should show a GLYPH followed by its name.",
          "A box, a question mark or blank space means the font is not patched.",
          "",
        }
        for group, set in pairs(icons) do
          table.insert(lines, "## " .. group)
          for name, glyph in pairs(set) do
            table.insert(lines, string.format("  %s   %s", glyph, name))
          end
          table.insert(lines, "")
        end
        table.insert(lines, "Terminal font in use is set by WezTerm, not Neovim:")
        table.insert(lines, "  ~/.config/wezterm/wezterm.lua  ->  config.font")
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        vim.bo[buf].filetype = "markdown"
        vim.bo[buf].modifiable = false
        vim.api.nvim_open_win(buf, true, {
          relative = "editor",
          width = math.min(70, vim.o.columns - 4),
          height = math.min(#lines + 2, vim.o.lines - 6),
          row = 2,
          col = math.floor((vim.o.columns - 70) / 2),
          style = "minimal",
          border = P.border,
          title = " Icon check ",
          title_pos = "center",
        })
      end, { desc = "Render every icon used by this config, to test the font" })
    end,
  },
}
