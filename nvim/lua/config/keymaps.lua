--- ~/.config/nvim/lua/config/keymaps.lua
---
--- EDITOR-WIDE KEYMAPS ONLY.
---
--- Keymaps that belong to a single plugin live in that plugin's spec, under
--- `keys = { ... }`. That is not stylistic tidiness: lazy.nvim uses the `keys`
--- table to decide *when to load the plugin*, so a mapping defined here would
--- force the plugin to load at startup and defeat lazy loading. Rule of thumb —
--- if the mapping calls `require("someplugin")`, it goes in that plugin's file.
---
--- ── THE LEADER MAP ───────────────────────────────────────────────────────────
--- <leader> is Space. The group layout below intentionally matches LazyVim's,
--- because that is the most widely documented keymap set in the Neovim ecosystem:
--- when you search for "how do I X in Neovim", the answer's keybinding will
--- usually already be correct here.
---
---   <leader><space>  find files                <leader>b   Buffer
---   <leader>/        grep in project           <leader>c   Code  (LSP, format)
---   <leader>,        switch buffer             <leader>d   Debug (RESERVED, see
---   <leader>:        command history                        docs/ADDING-A-LANGUAGE)
---   <leader>?        keymaps for this buffer   <leader>f   File / Find
---   <leader>e        toggle file explorer      <leader>g   Git
---                                              <leader>i   Image
---                                              <leader>l   Lazy (plugin manager)
---                                              <leader>n   Notifications
---                                              <leader>o   Outline / symbols
---                                              <leader>q   Quit / Session
---                                              <leader>s   Search
---                                              <leader>t   Test
---                                              <leader>u   UI toggles
---                                              <leader>w   Window
---                                              <leader>x   Diagnostics / quickfix
---                                              <leader>z   Zen mode
---
--- Press <leader> and wait 300ms — which-key lists everything available. That is
--- the "accessible keybindings screen": it is not a separate document that can go
--- stale, it reads the live keymap table.
---
--- Group *names* are registered in lua/plugins/editor.lua (the which-key spec).
--- UI toggles under <leader>u are defined in lua/plugins/ui.lua using
--- Snacks.toggle, which gives each one a live on/off indicator in the popup.

local map = vim.keymap.set

-- ═════════════════════════════════════════════════════════════════════════════
-- MOTION: make the defaults behave sensibly
-- ═════════════════════════════════════════════════════════════════════════════

-- Move by *screen* line when a line is wrapped, but keep counts working: `5j`
-- still moves five real lines (which is what you mean when you type a count),
-- while a bare `j` on a wrapped markdown paragraph moves one visible row.
-- Without this, `j` in wrapped prose jumps over a whole paragraph.
map({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true, desc = "Down (screen line)" })
map({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true, desc = "Up (screen line)" })
map({ "n", "x" }, "<Down>", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true, desc = "Down (screen line)" })
map({ "n", "x" }, "<Up>", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true, desc = "Up (screen line)" })

-- Keep the cursor centred while paging, so you never lose your place. `zz`
-- recentres, `zv` opens just enough folds to see the cursor.
map("n", "<C-d>", "<C-d>zz", { desc = "Half page down (centred)" })
map("n", "<C-u>", "<C-u>zz", { desc = "Half page up (centred)" })

-- Search results land in the middle of the screen instead of at the bottom edge.
map("n", "n", "nzzzv", { desc = "Next search result (centred)" })
map("n", "N", "Nzzzv", { desc = "Previous search result (centred)" })

-- `Y` yanks to end of line, matching how `D` and `C` behave. Vim's default makes
-- `Y` a synonym for `yy`, which is redundant and inconsistent.
map("n", "Y", "y$", { desc = "Yank to end of line" })

-- Join lines without the cursor jumping to the join point. `mz` sets a mark,
-- `` `z `` returns to it.
map("n", "J", "mzJ`z", { desc = "Join lines (keep cursor)" })

-- ═════════════════════════════════════════════════════════════════════════════
-- EDITING
-- ═════════════════════════════════════════════════════════════════════════════

-- Stay in visual mode after shifting, so you can press > > > to indent repeatedly
-- instead of re-selecting each time.
map("x", "<", "<gv", { desc = "Shift left (keep selection)" })
map("x", ">", ">gv", { desc = "Shift right (keep selection)" })

-- Paste over a selection WITHOUT the replaced text clobbering your register.
-- The single most useful remap in this file: with 'clipboard=unnamedplus', a
-- normal visual paste destroys what you were pasting, so you can only do it once.
-- `"_d` deletes into the black hole register, then `P` pastes the still-intact one.
map("x", "p", '"_dP', { desc = "Paste (keep register)" })

-- Delete without touching any register, for when you just want text gone and are
-- holding something you still need to paste.
map({ "n", "x" }, "<leader>D", '"_d', { desc = "Delete to black hole" })

-- `x` on a single character should not overwrite the clipboard either.
map("n", "x", '"_x', { desc = "Delete char (keep register)" })

-- Move the current line, or the whole selection, up and down. Auto-indents as it
-- goes. <A-j>/<A-k> — Alt is used because it is free in every mode.
map("n", "<A-j>", "<cmd>execute 'move .+' . v:count1<cr>==", { desc = "Move line down" })
map("n", "<A-k>", "<cmd>execute 'move .-' . (v:count1 + 1)<cr>==", { desc = "Move line up" })
map("i", "<A-j>", "<esc><cmd>move .+1<cr>==gi", { desc = "Move line down" })
map("i", "<A-k>", "<esc><cmd>move .-2<cr>==gi", { desc = "Move line up" })
map("x", "<A-j>", ":<C-u>execute \"'<,'>move '>+\" . v:count1<cr>gv=gv", { desc = "Move selection down" })
map("x", "<A-k>", ":<C-u>execute \"'<,'>move '<-\" . (v:count1 + 1)<cr>gv=gv", { desc = "Move selection up" })

-- Break the undo sequence at sentence boundaries while typing, so a long
-- paragraph is undone in readable chunks instead of vanishing in one `u`.
map("i", ",", ",<c-g>u")
map("i", ".", ".<c-g>u")
map("i", ";", ";<c-g>u")

-- Add a blank line above/below without leaving normal mode or entering insert.
map("n", "]<Space>", "<cmd>call append(line('.'),   repeat([''], v:count1))<cr>", { desc = "Blank line below" })
map("n", "[<Space>", "<cmd>call append(line('.')-1, repeat([''], v:count1))<cr>", { desc = "Blank line above" })

-- ═════════════════════════════════════════════════════════════════════════════
-- SEARCH HIGHLIGHT
-- ═════════════════════════════════════════════════════════════════════════════

-- <Esc> clears search highlighting. This is what makes 'hlsearch' pleasant to
-- live with: highlights stay while you are navigating matches and disappear the
-- instant you are done, with a key you already press reflexively.
-- Also stops any in-progress snippet session and closes floating windows.
map({ "i", "n", "s" }, "<Esc>", function()
  vim.cmd("noh")
  return "<esc>"
end, { expr = true, desc = "Escape and clear search highlight" })

-- ═════════════════════════════════════════════════════════════════════════════
-- WINDOWS  (<leader>w, plus <C-hjkl> for movement)
-- ═════════════════════════════════════════════════════════════════════════════

-- Move between splits with Ctrl + a direction key. No <leader> prefix, because
-- window switching is something you do dozens of times a minute.
map("n", "<C-h>", "<C-w>h", { desc = "Go to left window", remap = true })
map("n", "<C-j>", "<C-w>j", { desc = "Go to lower window", remap = true })
map("n", "<C-k>", "<C-w>k", { desc = "Go to upper window", remap = true })
map("n", "<C-l>", "<C-w>l", { desc = "Go to right window", remap = true })

-- Resize the current split with Ctrl + arrow keys.
map("n", "<C-Up>", "<cmd>resize +2<cr>", { desc = "Increase window height" })
map("n", "<C-Down>", "<cmd>resize -2<cr>", { desc = "Decrease window height" })
map("n", "<C-Left>", "<cmd>vertical resize -2<cr>", { desc = "Decrease window width" })
map("n", "<C-Right>", "<cmd>vertical resize +2<cr>", { desc = "Increase window width" })

map("n", "<leader>ws", "<C-w>s", { desc = "Split horizontal", remap = true })
map("n", "<leader>wv", "<C-w>v", { desc = "Split vertical", remap = true })
map("n", "<leader>wd", "<C-w>c", { desc = "Delete window", remap = true })
map("n", "<leader>ww", "<C-w>p", { desc = "Other window", remap = true })
map("n", "<leader>w=", "<C-w>=", { desc = "Equalise windows", remap = true })
map("n", "<leader>wm", "<C-w>|<C-w>_", { desc = "Maximise window", remap = true })
-- Mnemonic duplicates for splitting, matching the visual shape of the split.
map("n", "<leader>-", "<C-w>s", { desc = "Split window below", remap = true })
map("n", "<leader>|", "<C-w>v", { desc = "Split window right", remap = true })

-- ═════════════════════════════════════════════════════════════════════════════
-- BUFFERS  (<leader>b)
-- ═════════════════════════════════════════════════════════════════════════════

-- Shift+h / Shift+l to walk the buffer list — fast and needs no leader.
map("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Previous buffer" })
map("n", "<S-l>", "<cmd>bnext<cr>", { desc = "Next buffer" })
-- Bracket pairs for the same thing, matching the `]x`/`[x` convention used
-- throughout this config for "next/previous thing of type x".
map("n", "[b", "<cmd>bprevious<cr>", { desc = "Previous buffer" })
map("n", "]b", "<cmd>bnext<cr>", { desc = "Next buffer" })

-- Jump to the previously edited buffer. Superb for ping-ponging between an
-- implementation and its test.
map("n", "<leader>bb", "<cmd>e #<cr>", { desc = "Alternate buffer" })
map("n", "<leader>`", "<cmd>e #<cr>", { desc = "Alternate buffer" })

-- Buffer deletion is provided by snacks.bufdelete in lua/plugins/ui.lua, because
-- plain `:bdelete` also closes the window and wrecks your layout.

-- ═════════════════════════════════════════════════════════════════════════════
-- TABS  (real tab pages, used here as workspaces)
-- ═════════════════════════════════════════════════════════════════════════════
-- Note: bufferline shows *buffers* along the top, not tabs. Tab pages are a
-- separate, coarser layer — think "one tab per task", each with its own splits.
map("n", "<leader><tab><tab>", "<cmd>tabnew<cr>", { desc = "New tab" })
map("n", "<leader><tab>d", "<cmd>tabclose<cr>", { desc = "Close tab" })
map("n", "<leader><tab>]", "<cmd>tabnext<cr>", { desc = "Next tab" })
map("n", "<leader><tab>[", "<cmd>tabprevious<cr>", { desc = "Previous tab" })
map("n", "<leader><tab>f", "<cmd>tabfirst<cr>", { desc = "First tab" })
map("n", "<leader><tab>l", "<cmd>tablast<cr>", { desc = "Last tab" })

-- ═════════════════════════════════════════════════════════════════════════════
-- FILES  (<leader>f) — the picker-based ones live in lua/plugins/picker.lua
-- ═════════════════════════════════════════════════════════════════════════════

-- Save. <C-s> works from insert mode too, which is where you usually realise you
-- want to save. Saves only if modified, to avoid pointless writes triggering
-- file watchers and format-on-save.
map({ "i", "x", "n", "s" }, "<C-s>", "<cmd>silent! update<cr><esc>", { desc = "Save file" })
map("n", "<leader>fs", "<cmd>silent! update<cr>", { desc = "Save file" })

-- Save every modified buffer at once.
map("n", "<leader>fS", "<cmd>silent! wall<cr>", { desc = "Save all files" })

map("n", "<leader>fn", "<cmd>enew<cr>", { desc = "New file" })

-- Copy the current file's path to the clipboard — constantly needed when talking
-- to someone about code, or pasting into a terminal command.
map("n", "<leader>fp", function()
  local path = vim.fn.expand("%:p")
  vim.fn.setreg("+", path)
  vim.notify(path, vim.log.levels.INFO, { title = "Copied absolute path" })
end, { desc = "Copy absolute path" })

map("n", "<leader>fP", function()
  local path = vim.fn.expand("%:.") -- relative to cwd
  vim.fn.setreg("+", path)
  vim.notify(path, vim.log.levels.INFO, { title = "Copied relative path" })
end, { desc = "Copy relative path" })

-- Open the *config* directory quickly, regardless of which machine you are on.
map("n", "<leader>fc", function()
  vim.cmd.edit(vim.fn.stdpath("config") .. "/init.lua")
end, { desc = "Edit Neovim config" })

-- ═════════════════════════════════════════════════════════════════════════════
-- DIAGNOSTICS AND QUICKFIX  (]d [d ]e [e, <leader>x)
-- ═════════════════════════════════════════════════════════════════════════════

-- vim.diagnostic.jump() is the Neovim 0.11+ API. The older
-- vim.diagnostic.goto_next/goto_prev are deprecated — if you copy a snippet from
-- an older blog post using them, this is the modern replacement.
local function diagnostic_jump(count, severity)
  return function()
    vim.diagnostic.jump({
      count = count,
      float = true, -- pop the message up on arrival, so you can read it without
      -- a second keystroke
      severity = severity and vim.diagnostic.severity[severity] or nil,
    })
  end
end

map("n", "]d", diagnostic_jump(1), { desc = "Next diagnostic" })
map("n", "[d", diagnostic_jump(-1), { desc = "Previous diagnostic" })
map("n", "]e", diagnostic_jump(1, "ERROR"), { desc = "Next error" })
map("n", "[e", diagnostic_jump(-1, "ERROR"), { desc = "Previous error" })
map("n", "]w", diagnostic_jump(1, "WARN"), { desc = "Next warning" })
map("n", "[w", diagnostic_jump(-1, "WARN"), { desc = "Previous warning" })

-- Show the full diagnostic for the current line in a float. Useful when the
-- virtual text is truncated — which it always is for Rust trait errors.
map("n", "<leader>cd", vim.diagnostic.open_float, { desc = "Line diagnostics" })

-- Quickfix and location list navigation. The quickfix list is what `:grep`,
-- `:make` and "find all references" populate.
map("n", "]q", "<cmd>cnext<cr>zz", { desc = "Next quickfix item" })
map("n", "[q", "<cmd>cprevious<cr>zz", { desc = "Previous quickfix item" })
map("n", "]Q", "<cmd>clast<cr>zz", { desc = "Last quickfix item" })
map("n", "[Q", "<cmd>cfirst<cr>zz", { desc = "First quickfix item" })
map("n", "]l", "<cmd>lnext<cr>zz", { desc = "Next location item" })
map("n", "[l", "<cmd>lprevious<cr>zz", { desc = "Previous location item" })

-- ═════════════════════════════════════════════════════════════════════════════
-- QUIT AND SESSIONS  (<leader>q)
-- ═════════════════════════════════════════════════════════════════════════════
-- Session restore keymaps (<leader>qs, <leader>ql, <leader>qd) are defined in the
-- persistence.nvim spec, so the plugin stays lazy until you use one.
map("n", "<leader>qq", "<cmd>qa<cr>", { desc = "Quit all" })
map("n", "<leader>qQ", "<cmd>qa!<cr>", { desc = "Quit all (discard changes)" })

-- ═════════════════════════════════════════════════════════════════════════════
-- PLUGIN MANAGER  (<leader>l)
-- ═════════════════════════════════════════════════════════════════════════════
-- NOTE: `<leader>ll`, not `<leader>l`. A key that is both a complete mapping and
-- a prefix for other mappings is always ambiguous — Neovim has to wait out
-- 'timeoutlen' to find out which you meant, so every `<leader>lm` would feel
-- laggy. Prefixes stay prefixes here; see the same note in lua/plugins/git.lua.
map("n", "<leader>ll", "<cmd>Lazy<cr>", { desc = "Lazy (plugin manager)" })
map("n", "<leader>lm", "<cmd>Mason<cr>", { desc = "Mason (LSP/tool installer)" })
map("n", "<leader>lu", "<cmd>Lazy update<cr>", { desc = "Update plugins" })
map("n", "<leader>lc", "<cmd>Lazy check<cr>", { desc = "Check for updates" })
map("n", "<leader>lp", "<cmd>Lazy profile<cr>", { desc = "Profile startup time" })

-- ═════════════════════════════════════════════════════════════════════════════
-- TERMINAL MODE
-- ═════════════════════════════════════════════════════════════════════════════
-- Escape from terminal insert mode back to normal mode, so you can scroll and
-- copy from the terminal buffer. <Esc><Esc> rather than a single <Esc>, because a
-- single one belongs to the shell (and to any TUI running inside it, like lazygit).
map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- Move out of a terminal split with the same <C-hjkl> as everywhere else, without
-- needing to leave terminal mode first.
map("t", "<C-h>", "<cmd>wincmd h<cr>", { desc = "Go to left window" })
map("t", "<C-j>", "<cmd>wincmd j<cr>", { desc = "Go to lower window" })
map("t", "<C-k>", "<cmd>wincmd k<cr>", { desc = "Go to upper window" })
map("t", "<C-l>", "<cmd>wincmd l<cr>", { desc = "Go to right window" })

-- ═════════════════════════════════════════════════════════════════════════════
-- INSPECTION AND DEBUGGING THE CONFIG ITSELF
-- ═════════════════════════════════════════════════════════════════════════════

-- Show every highlight group and treesitter capture under the cursor. This is THE
-- tool for theming: it tells you the exact group name to override in
-- lua/plugins/colorscheme.lua to recolour whatever you are looking at.
map("n", "<leader>ui", vim.show_pos, { desc = "Inspect position (highlight groups)" })

-- Open the live treesitter parse tree for the current buffer, side by side with
-- the code. Indispensable when writing a fold/indent query or debugging why
-- highlighting is wrong.
map("n", "<leader>uI", "<cmd>InspectTree<cr>", { desc = "Inspect treesitter tree" })

-- Interactive treesitter query playground.
map("n", "<leader>uq", "<cmd>EditQuery<cr>", { desc = "Edit treesitter query" })

-- ═════════════════════════════════════════════════════════════════════════════
-- MISC
-- ═════════════════════════════════════════════════════════════════════════════

-- Make `&` (repeat last substitute) keep the flags, which is almost always what
-- you want. Vim's default drops them.
map({ "n", "x" }, "&", ":&&<cr>", { desc = "Repeat substitute (keep flags)" })

-- Execute the current line, or selection, as Lua. Fast way to try an API call
-- against the live editor while writing this config.
map("n", "<leader>ux", "<cmd>.lua<cr>", { desc = "Execute line as Lua" })
map("x", "<leader>ux", ":lua<cr>", { desc = "Execute selection as Lua" })
