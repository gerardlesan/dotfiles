--- ~/.config/nvim/lua/config/autocmds.lua
---
--- Behaviour that reacts to events rather than being set once. Each autocommand
--- lives in a named augroup with `clear = true`, which is what makes this file
--- re-sourceable: re-running it replaces the old handlers instead of stacking a
--- second copy on top (the classic "my autocmd fires three times" bug).
---
--- `:autocmd <Event>` lists everything currently registered for an event, and
--- `:verbose autocmd BufWritePre` says where each one came from — start there when
--- something happens on save that you did not ask for.

-- Helper: create (or reset) a namespaced augroup.
local function augroup(name)
  return vim.api.nvim_create_augroup("cfg_" .. name, { clear = true })
end

local autocmd = vim.api.nvim_create_autocmd

-- ═════════════════════════════════════════════════════════════════════════════
-- VISUAL FEEDBACK
-- ═════════════════════════════════════════════════════════════════════════════

-- Briefly highlight the text you just yanked. Tiny feature, disproportionately
-- useful: it confirms *exactly* what got copied, which catches an off-by-one
-- motion immediately rather than after you paste it somewhere.
autocmd("TextYankPost", {
  group = augroup("highlight_yank"),
  desc = "Flash the yanked region",
  callback = function()
    -- `on_visual = false` means a yank of a whole line does not flash the entire
    -- line width, only the text. `timeout` in ms.
    vim.hl.on_yank({ higroup = "IncSearch", timeout = 150, on_visual = true })
  end,
})

-- Show 'cursorline' only in the window that actually has focus. With four splits
-- open, four highlighted lines is noise — this makes the cursor's location
-- unambiguous at a glance.
local cursorline_group = augroup("cursorline_focus")
autocmd({ "WinEnter", "BufEnter" }, {
  group = cursorline_group,
  desc = "Enable cursorline in the focused window",
  callback = function()
    -- Do not fight with special buffers that manage their own highlighting.
    if vim.w.cursorline_disabled then
      return
    end
    vim.wo.cursorline = true
  end,
})
autocmd({ "WinLeave", "BufLeave" }, {
  group = cursorline_group,
  desc = "Disable cursorline in unfocused windows",
  callback = function()
    vim.wo.cursorline = false
  end,
})

-- Relative line numbers are only meaningful next to the cursor. Turning them off
-- in insert mode stops the whole gutter renumbering on every line you type, which
-- is visually distracting while writing.
local numbers_group = augroup("relative_numbers")
autocmd("InsertEnter", {
  group = numbers_group,
  desc = "Absolute numbers while typing",
  callback = function()
    if vim.wo.number and vim.bo.buftype == "" then
      vim.wo.relativenumber = false
    end
  end,
})
autocmd("InsertLeave", {
  group = numbers_group,
  desc = "Relative numbers when navigating",
  callback = function()
    if vim.wo.number and vim.bo.buftype == "" then
      vim.wo.relativenumber = true
    end
  end,
})

-- ═════════════════════════════════════════════════════════════════════════════
-- FILE HANDLING
-- ═════════════════════════════════════════════════════════════════════════════

-- Return to the position you were at when you last had this file open. Uses the
-- `"` mark, which Neovim maintains automatically via the shada file.
autocmd("BufReadPost", {
  group = augroup("last_location"),
  desc = "Restore last cursor position",
  callback = function(event)
    local exclude = { "gitcommit", "gitrebase", "svn", "hgcommit" }
    local buf = event.buf
    -- Do not do this for commit messages — you always want to start at line 1
    -- there, not wherever you were in the previous commit.
    if vim.tbl_contains(exclude, vim.bo[buf].filetype) or vim.b[buf].last_loc_done then
      return
    end
    vim.b[buf].last_loc_done = true
    local mark = vim.api.nvim_buf_get_mark(buf, '"')
    local line_count = vim.api.nvim_buf_line_count(buf)
    -- Guard against a stale mark pointing past the end of a file that shrank.
    if mark[1] > 0 and mark[1] <= line_count then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
      -- Open any folds the restored position is inside, and centre it.
      pcall(vim.cmd, "normal! zvzz")
    end
  end,
})

-- Create missing parent directories when you save. Lets you type
-- `:e src/deeply/nested/new_module.rs` and just save, instead of getting
-- "E212: Can't open file for writing" and having to mkdir by hand.
autocmd("BufWritePre", {
  group = augroup("auto_mkdir"),
  desc = "Create parent directories on save",
  callback = function(event)
    -- Skip URLs and other non-file buffers (oil://, fugitive://, scp://...).
    if event.match:match("^%w%w+://") then
      return
    end
    local file = vim.uv.fs_realpath(event.match) or event.match
    vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
  end,
})

-- Reload files that changed on disk. 'autoread' only takes effect when Neovim
-- gets around to checking, and it does not check on its own — this nudges it at
-- the moments a change is most likely: regaining focus, switching buffers, or
-- returning from a terminal command (a git checkout, a formatter run).
autocmd({ "FocusGained", "TermClose", "TermLeave", "BufEnter" }, {
  group = augroup("checktime"),
  desc = "Check for external file changes",
  callback = function()
    -- `:checktime` errors in command-line window; guard it.
    if vim.o.buftype ~= "nofile" then
      vim.cmd("checktime")
    end
  end,
})

-- Warn when a file changes underneath you, rather than silently swapping content.
autocmd("FileChangedShellPost", {
  group = augroup("file_changed_notify"),
  desc = "Notify when a file was reloaded from disk",
  callback = function()
    vim.notify("File changed on disk — buffer reloaded", vim.log.levels.WARN, { title = "Reloaded" })
  end,
})

-- ═════════════════════════════════════════════════════════════════════════════
-- SECRETS HYGIENE
-- ═════════════════════════════════════════════════════════════════════════════
-- Persistent undo (section 19 of options.lua) is excellent, and it means the full
-- edit history of every file you open is written to disk in plain text. For a
-- credentials file that is a real leak: the secret survives in
-- stdpath("state")/undo even after you delete it from the file.
--
-- This turns off undofile, swap and shada for anything that looks like a secret,
-- and disables the LSP so nothing gets shipped to a language server.
autocmd({ "BufReadPre", "BufNewFile" }, {
  group = augroup("secrets"),
  desc = "Disable persistence for credential files",
  pattern = {
    "*.env", ".env", ".env.*",
    "*.pem", "*.key", "*.p12", "*.pfx",
    "id_rsa", "id_ed25519", "*_rsa", "*_ed25519",
    "*.kdbx", "*.gpg", "*.asc",
    "*credentials*", "*secrets*",
  },
  callback = function(event)
    vim.bo[event.buf].undofile = false
    vim.bo[event.buf].swapfile = false
    vim.opt_local.shada = ""
    -- Stop this buffer being sent to any language server.
    vim.b[event.buf].lsp_disable = true
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(event.buf) then
        vim.diagnostic.enable(false, { bufnr = event.buf })
      end
    end)
  end,
})

-- ═════════════════════════════════════════════════════════════════════════════
-- WINDOW AND LAYOUT MANAGEMENT
-- ═════════════════════════════════════════════════════════════════════════════

-- Re-equalise splits when the terminal window is resized, and re-fit the tabline.
-- Without this, dragging the WezTerm window smaller leaves splits at their old
-- absolute sizes and one of them ends up two columns wide.
autocmd("VimResized", {
  group = augroup("resize_splits"),
  desc = "Equalise splits on terminal resize",
  callback = function()
    local current_tab = vim.fn.tabpagenr()
    vim.cmd("tabdo wincmd =")
    vim.cmd("tabnext " .. current_tab)
  end,
})

-- Let `q` close throwaway windows. These are all read-only informational buffers
-- where reaching for `:q` or `<C-w>c` is friction — help pages, the quickfix
-- list, `:checkhealth` output, git blame popups, lspinfo.
--
-- Also sets `buflisted = false` so these never show up in the bufferline or in
-- <S-h>/<S-l> buffer cycling.
autocmd("FileType", {
  group = augroup("close_with_q"),
  desc = "Close utility windows with q",
  pattern = {
    "help", "qf", "man", "checkhealth", "lspinfo", "startuptime",
    "notify", "query", "tsplayground", "neotest-output", "neotest-summary",
    "neotest-output-panel", "grug-far", "dbout", "gitsigns-blame",
    "fugitive", "git", "spectre_panel", "PlenaryTestPopup",
  },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.schedule(function()
      vim.keymap.set("n", "q", function()
        vim.cmd("close")
        -- Wipe the buffer so it does not linger in the buffer list.
        pcall(vim.api.nvim_buf_delete, event.buf, { force = true })
      end, { buffer = event.buf, silent = true, desc = "Close window" })
    end)
  end,
})

-- Open `:help` in a vertical split on wide terminals. A 200-column window showing
-- help stacked above your code wastes the width; side by side you can read the
-- docs and the code together.
autocmd("FileType", {
  group = augroup("help_vertical"),
  desc = "Vertical help split on wide screens",
  pattern = { "help", "man" },
  callback = function()
    if vim.o.columns > 180 then
      vim.cmd("wincmd L") -- move this window to the far right
      vim.cmd("vertical resize 88")
    end
  end,
})

-- ═════════════════════════════════════════════════════════════════════════════
-- TERMINAL BUFFERS
-- ═════════════════════════════════════════════════════════════════════════════

-- A terminal is not a text file: line numbers, the sign column and the fold
-- column are all noise that also break the alignment of TUI programs drawing
-- inside it (lazygit in particular).
autocmd("TermOpen", {
  group = augroup("terminal_settings"),
  desc = "Clean up terminal buffer appearance",
  callback = function()
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.signcolumn = "no"
    vim.opt_local.foldcolumn = "0"
    vim.opt_local.spell = false
    vim.opt_local.list = false
    vim.opt_local.cursorline = false
    vim.w.cursorline_disabled = true
    -- Scrolloff must be 0 in a terminal or the shell prompt cannot reach the
    -- bottom of the window and the output looks permanently scrolled.
    vim.opt_local.scrolloff = 0
    -- Start in insert mode so you can type immediately.
    vim.cmd("startinsert")
  end,
})

-- ═════════════════════════════════════════════════════════════════════════════
-- SAFETY RAILS
-- ═════════════════════════════════════════════════════════════════════════════

-- Make read-only files obvious rather than letting you type into them and only
-- discover it at `:w`.
autocmd("BufReadPost", {
  group = augroup("readonly_warning"),
  desc = "Warn when opening a read-only file",
  callback = function(event)
    if vim.bo[event.buf].readonly and vim.bo[event.buf].buftype == "" then
      vim.notify("This file is read-only", vim.log.levels.WARN, { title = "Read-only" })
    end
  end,
})

-- Strip the "continue the comment leader" flag when a filetype's own ftplugin
-- re-adds it in a way that fights the config. Runs *after* every ftplugin, which
-- is the only reliable way to win that argument.
--
-- Kept minimal on purpose: 'o' is left ON globally (see 'formatoptions' in
-- options.lua) because continuing a comment with `o` is usually wanted. This hook
-- exists as the documented place to intervene if a specific language annoys you:
--   vim.opt_local.formatoptions:remove("o")
autocmd("FileType", {
  group = augroup("formatoptions"),
  desc = "Normalise formatoptions after ftplugins run",
  callback = function()
    -- Never auto-wrap code, whatever the ftplugin thinks. markdown and gitcommit
    -- opt back in explicitly in their own ftplugin files.
    if not vim.tbl_contains({ "markdown", "text", "gitcommit", "rst" }, vim.bo.filetype) then
      vim.opt_local.formatoptions:remove("t")
    end
  end,
})

-- ═════════════════════════════════════════════════════════════════════════════
-- CLASSIFIED BUT NOT ENABLED
-- ═════════════════════════════════════════════════════════════════════════════
-- Common autocommands deliberately left out, and why.
--
-- ── Trim trailing whitespace on save ────────────────────────────────────────
-- Tempting, and wrong in a shared repo: it rewrites lines you did not touch,
-- producing diffs full of unrelated whitespace changes that hide your actual
-- edit. conform.nvim runs the language's real formatter instead (<leader>cf),
-- which fixes whitespace as a side effect of correct formatting. If you still
-- want it for personal projects:
--
-- autocmd("BufWritePre", {
--   group = augroup("trim_whitespace"),
--   callback = function()
--     local save = vim.fn.winsaveview()
--     vim.cmd([[keeppatterns %s/\s\+$//e]])
--     vim.fn.winrestview(save)
--   end,
-- })
--
-- ── Auto-save on focus loss ─────────────────────────────────────────────────
-- Writes files without you asking, which triggers format-on-save and file
-- watchers at unpredictable moments, and defeats "close without saving" as an
-- escape hatch. <C-s> is one keystroke.
--
-- autocmd({ "FocusLost", "BufLeave" }, {
--   group = augroup("autosave"),
--   callback = function() vim.cmd("silent! wall") end,
-- })
--
-- ── Auto-format on save ─────────────────────────────────────────────────────
-- Enabled, but owned by conform.nvim rather than a raw autocmd here — see
-- lua/plugins/format.lua, which also gives you a per-buffer and global toggle
-- (<leader>uf) for the times a repo's formatter disagrees with the project.
--
-- ── Restore the terminal cursor shape on exit ───────────────────────────────
-- Neovim 0.10+ does this itself. The `VimLeave: set guicursor=a:ver25` autocmd
-- you will find in older configs is obsolete and can leave the *wrong* cursor.
--
-- ── Open a dashboard when the last buffer closes ────────────────────────────
-- snacks.dashboard handles the startup case. Re-opening it mid-session is
-- fiddly and rarely what you want.
