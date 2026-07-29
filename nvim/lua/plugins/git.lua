--- ~/.config/nvim/lua/plugins/git.lua
---
--- GIT, in three layers that do genuinely different jobs:
---
---   gitsigns    IN the buffer — change markers in the gutter, stage/reset
---               individual hunks, inline blame, diff the current file
---   lazygit     the full client, in a float (<leader>gg). Staging, committing,
---               rebasing, cherry-picking, branch management, stashes. Configured
---               in lua/plugins/snacks.lua via Snacks.lazygit.
---   diffview    reviewing — a proper side-by-side diff of any two revisions, and
---               file history with the diff for each commit
---
--- Plus the git pickers (<leader>gl log, <leader>gs status, <leader>gB branches)
--- from snacks.picker, and <leader>go to open the current line on GitHub/GitLab.

local P = require("config.palette")
local icons = P.icons

return {
  -- ═════════════════════════════════════════════════════════════════════════
  -- GITSIGNS — hunks in the gutter, staging from the buffer
  -- ═════════════════════════════════════════════════════════════════════════
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      signs = {
        add = { text = "\u{2503}" }, -- ┃ heavy vertical
        change = { text = "\u{2503}" },
        delete = { text = "\u{2581}" }, -- ▁ low block, reads as "removed"
        topdelete = { text = "\u{2594}" }, -- ▔ high block
        changedelete = { text = "\u{223c}" }, -- ∼
        untracked = { text = "\u{2506}" }, -- ┆ dashed, distinct from tracked
      },
      -- Staged changes get a dimmer variant, so you can tell at a glance what is
      -- already staged versus still in the working tree.
      signs_staged = {
        add = { text = "\u{2502}" },
        change = { text = "\u{2502}" },
        delete = { text = "\u{2581}" },
        topdelete = { text = "\u{2594}" },
        changedelete = { text = "\u{223c}" },
      },
      signs_staged_enable = true,

      signcolumn = true,
      numhl = false, -- also tint the line number: redundant with signs
      linehl = false, -- tint the whole line: far too loud for normal editing
      word_diff = false,

      -- Inline blame at end of line. DISABLED.
      --
      -- It appends "author, 3 days ago • commit summary" as virtual text to
      -- whichever line the cursor is on, which means the right-hand side of the
      -- screen changes on every cursor move. Informative, and a constant
      -- distraction while actually writing code.
      --
      -- The information is still one keystroke away, and in better form:
      --   <leader>ghb   blame this line in a float, with the full commit message
      --   <leader>ghB   blame the whole file in a split
      --   <leader>gtb   turn this inline blame back on for the session
      --   <leader>gL    picker showing every commit that touched this line
      current_line_blame = false,
      current_line_blame_opts = {
        virt_text = true,
        virt_text_pos = "eol",
        -- 300ms is long enough that it does not flicker while you navigate.
        delay = 300,
        ignore_whitespace = true,
      },
      -- <author>, <relative time> · <summary>
      current_line_blame_formatter = "  \u{f007} <author>, <author_time:%R> \u{2022} <summary>",

      -- Watch .git/index so signs update when you commit or checkout in another
      -- terminal, without a manual refresh.
      watch_gitdir = { follow_files = true },
      attach_to_untracked = true,
      update_debounce = 100,
      max_file_length = 40000, -- skip enormous files; snacks.bigfile also guards

      preview_config = { border = P.border, style = "minimal" },

      on_attach = function(bufnr)
        local gs = require("gitsigns")

        local function map(mode, lhs, rhs, desc)
          vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = "Git: " .. desc })
        end

        -- ── Hunk navigation ────────────────────────────────────────────────
        -- `]h` / `[h` for hunks, matching the `]x` convention used throughout.
        -- Inside a diff these fall back to Vim's own `]c` / `[c`.
        map("n", "]h", function()
          if vim.wo.diff then
            vim.cmd.normal({ "]c", bang = true })
          else
            gs.nav_hunk("next")
          end
        end, "Next hunk")

        map("n", "[h", function()
          if vim.wo.diff then
            vim.cmd.normal({ "[c", bang = true })
          else
            gs.nav_hunk("prev")
          end
        end, "Previous hunk")

        map("n", "]H", function()
          gs.nav_hunk("last")
        end, "Last hunk")
        map("n", "[H", function()
          gs.nav_hunk("first")
        end, "First hunk")

        -- ── Staging individual hunks ───────────────────────────────────────
        -- This is what replaces `git add -p`: put the cursor on a change and
        -- stage exactly that. In visual mode it stages only the selected lines.
        map("n", "<leader>ghs", gs.stage_hunk, "Stage hunk")
        map("n", "<leader>ghr", gs.reset_hunk, "Reset hunk")
        map("v", "<leader>ghs", function()
          gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
        end, "Stage selected lines")
        map("v", "<leader>ghr", function()
          gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
        end, "Reset selected lines")

        map("n", "<leader>ghS", gs.stage_buffer, "Stage whole buffer")
        map("n", "<leader>ghR", gs.reset_buffer, "Reset whole buffer")
        -- Unstage: gitsigns' stage_hunk toggles on an already-staged hunk.
        map("n", "<leader>ghu", gs.undo_stage_hunk, "Undo stage hunk")

        -- ── Inspecting ─────────────────────────────────────────────────────
        map("n", "<leader>ghp", gs.preview_hunk_inline, "Preview hunk inline")
        map("n", "<leader>ghP", gs.preview_hunk, "Preview hunk in float")
        map("n", "<leader>ghb", function()
          gs.blame_line({ full = true })
        end, "Blame line (full)")
        map("n", "<leader>ghB", gs.blame, "Blame whole file")
        map("n", "<leader>ghd", gs.diffthis, "Diff against index")
        map("n", "<leader>ghD", function()
          gs.diffthis("~")
        end, "Diff against last commit")

        -- ── Toggles ────────────────────────────────────────────────────────
        map("n", "<leader>gtb", gs.toggle_current_line_blame, "Toggle inline blame")
        map("n", "<leader>gtd", gs.toggle_deleted, "Toggle deleted lines")
        map("n", "<leader>gtw", gs.toggle_word_diff, "Toggle word diff")

        -- ── Text object ────────────────────────────────────────────────────
        -- `ih` = "inner hunk". So `vih` selects the change under the cursor and
        -- `dih` reverts it.
        map({ "o", "x" }, "ih", gs.select_hunk, "Select hunk")
      end,
    },
  },

  -- ═════════════════════════════════════════════════════════════════════════
  -- DIFFVIEW — reviewing changes and history
  -- ═════════════════════════════════════════════════════════════════════════
  -- The thing gitsigns and lazygit are both bad at: a real side-by-side diff of
  -- an arbitrary range of commits, with a file panel, and per-commit history for
  -- a single file or a selection.
  {
    "sindrets/diffview.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory", "DiffviewToggleFiles" },
    keys = {
      { "<leader>gv", "<cmd>DiffviewOpen<cr>", desc = "Diffview: working tree" },
      { "<leader>gV", "<cmd>DiffviewClose<cr>", desc = "Diffview: close" },
      {
        -- Diff against the upstream branch — "what does my PR actually change".
        "<leader>gm",
        function()
          -- Try main, then master, then whatever HEAD tracks.
          local branches = { "origin/main", "origin/master", "main", "master" }
          for _, b in ipairs(branches) do
            local ok = vim.fn.systemlist({ "git", "rev-parse", "--verify", "--quiet", b })
            if vim.v.shell_error == 0 and #ok > 0 then
              vim.cmd("DiffviewOpen " .. b .. "...HEAD")
              return
            end
          end
          vim.notify("No main/master branch found", vim.log.levels.WARN)
        end,
        desc = "Diffview: vs main branch",
      },
      -- NOTE: these are `gr`/`gR` (r for "revisions"), deliberately NOT `gh`.
      -- gitsigns owns `<leader>gh` as a PREFIX for hunk operations (ghs, ghr,
      -- ghp...). Mapping `<leader>gh` directly as well would make Neovim wait out
      -- 'timeoutlen' on every hunk command and then sometimes fire the wrong one —
      -- a key that is both a complete mapping and a prefix is always ambiguous.
      { "<leader>gr", "<cmd>DiffviewFileHistory<cr>", desc = "Diffview: repo history" },
      { "<leader>gR", "<cmd>DiffviewFileHistory --follow %<cr>", desc = "Diffview: this file's history" },
      {
        "<leader>gr",
        "<Esc><cmd>'<,'>DiffviewFileHistory --follow<cr>",
        mode = "v",
        desc = "Diffview: history of selection",
      },
    },
    opts = {
      enhanced_diff_hl = true, -- richer highlighting than plain DiffAdd/DiffDelete
      view = {
        -- Only show a merge-tool layout when actually resolving conflicts.
        default = { layout = "diff2_horizontal", winbar_info = true },
        merge_tool = { layout = "diff3_mixed", disable_diagnostics = true },
        file_history = { layout = "diff2_horizontal", winbar_info = true },
      },
      file_panel = {
        listing_style = "tree",
        tree_options = { flatten_dirs = true, folder_statuses = "only_folded" },
        win_config = { position = "left", width = 34 },
      },
      hooks = {
        -- Diagnostics in a diff view are meaningless (the "file" is a historic
        -- revision the LSP knows nothing about) and clutter the gutter.
        diff_buf_read = function()
          vim.opt_local.wrap = false
          vim.opt_local.list = false
          vim.opt_local.relativenumber = false
        end,
      },
      keymaps = {
        view = {
          { "n", "q", "<cmd>DiffviewClose<cr>", { desc = "Close diffview" } },
          { "n", "<leader>gV", "<cmd>DiffviewClose<cr>", { desc = "Close diffview" } },
        },
        file_panel = {
          { "n", "q", "<cmd>DiffviewClose<cr>", { desc = "Close diffview" } },
        },
        file_history_panel = {
          { "n", "q", "<cmd>DiffviewClose<cr>", { desc = "Close diffview" } },
        },
      },
    },
  },
}
