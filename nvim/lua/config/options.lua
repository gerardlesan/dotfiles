--- ~/.config/nvim/lua/config/options.lua
---
--- ═════════════════════════════════════════════════════════════════════════════
--- EVERY VIM OPTION THAT MATTERS, CLASSIFIED
--- ═════════════════════════════════════════════════════════════════════════════
---
--- This file is deliberately exhaustive. Options are grouped by what they *do*,
--- and inside each group you will find two kinds of entry:
---
---   vim.opt.foo = bar     ← ACTIVE. Set by this config, with a note on why.
---   -- vim.opt.foo = bar  ← CLASSIFIED BUT NOT ENABLED. Documented so you know
---                           the knob exists, what it does, and why it is off.
---
--- So "why isn't my thing happening" and "what could I even turn on" are both
--- answerable by reading one file. Every commented-out line is a real option with
--- a real default — nothing here is invented.
---
--- Conventions used below:
---   (default: x)   the value Neovim ships with, so you can see what we changed
---   [global]       one value for the whole editor
---   [window]       per-window; set here as the default for new windows
---   [buffer]       per-buffer; set here as the default for new buffers
---
--- `:help 'optionname'` documents any of these in full. `:verbose set foo?` tells
--- you which file last changed one — the fastest way to debug a surprise.
---
--- ── TABLE OF CONTENTS ────────────────────────────────────────────────────────
---   01  Leader keys
---   02  Providers and built-in integrations
---   03  Gutter: line numbers, signs, fold column
---   04  Cursor and current-line emphasis
---   05  Colour and rendering
---   06  Statusline, tabline, command line
---   07  Popup menu and floating windows
---   08  Whitespace and special characters
---   09  Window splitting and sizing
---   10  Scrolling
---   11  Line wrapping
---   12  Indentation and tabs
---   13  Search
---   14  Substitution and replace
---   15  Insert-mode completion
---   16  Spell checking
---   17  Folding
---   18  Encoding, file formats and line endings
---   19  Backup, swap, undo and shada
---   20  Buffer and window behaviour
---   21  Clipboard and registers
---   22  Text formatting and comments
---   23  Word, filename and pair characters
---   24  Timing and responsiveness
---   25  Mouse
---   26  Diff
---   27  Grep and external tools
---   28  Shell (per operating system)
---   29  Performance and large files
---   30  Sessions and views
---   31  Terminal buffers
---   32  Command line and wildmenu
---   33  Messages and prompts
---   34  Security: exrc and secure
---   35  Diagnostics (vim.diagnostic, not an option — but it belongs here)
---   36  Filetype detection additions
---   37  Deliberately not set: legacy, Vim-only, and actively harmful options
--- ─────────────────────────────────────────────────────────────────────────────

local opt = vim.opt
local g = vim.g

-- Cache a couple of platform predicates. Used throughout, and in the shell
-- section in particular. `has("win32")` is true for 64-bit Windows too — there is
-- no separate "win64" feature.
local is_win = vim.fn.has("win32") == 1
local is_mac = vim.fn.has("mac") == 1
local is_wsl = vim.fn.has("wsl") == 1

-- ═════════════════════════════════════════════════════════════════════════════
-- 01  LEADER KEYS
-- ═════════════════════════════════════════════════════════════════════════════
-- MUST be set before any plugin spec is loaded. lazy.nvim resolves a spec's
-- `keys = { "<leader>x" }` when it reads the spec, so a leader defined later
-- would leave those plugins mapped to the *old* leader (backslash) — a classic
-- "my keybinding does nothing" bug.
--
-- Space is the near-universal choice: it is huge, reachable with either thumb,
-- and does nothing useful in normal mode (it is just "move right", which `l`
-- already covers).
g.mapleader = " "

-- The local leader prefixes *filetype-specific* mappings — e.g. "run this Rust
-- test", "render this markdown". Keeping them off the main leader means adding a
-- language cannot collide with a global binding.
g.maplocalleader = "\\"

-- NOTE: Space is deliberately NOT mapped to <Nop>.
--
-- Doing that is a very common idiom, intended to stop a bare Space from moving the
-- cursor right. It backfires: it makes <Space> simultaneously a COMPLETE mapping
-- and a PREFIX for all 170-odd leader mappings, so Neovim must wait out
-- 'timeoutlen' after every Space to find out which you meant, and pausing to think
-- fires the <Nop>. which-key already owns the leader prefix and shows its panel
-- instead of falling through to Space's default motion, so the <Nop> buys nothing
-- and costs responsiveness. The same "never make a key both a mapping and a
-- prefix" rule is applied to <leader>l, <leader>n and <leader>gh elsewhere.

-- ═════════════════════════════════════════════════════════════════════════════
-- 02  PROVIDERS AND BUILT-IN INTEGRATIONS
-- ═════════════════════════════════════════════════════════════════════════════
-- "Providers" are Neovim's bridges to external scripting runtimes, kept only for
-- legacy Vim plugins written in those languages. Every plugin in this config is
-- Lua, so all four are disabled. Each one you disable removes a subprocess probe
-- from startup and one more "provider not found" entry from :checkhealth.
--
-- If you ever install a plugin that genuinely needs one, set it back to 1 (or
-- just delete the line) and point the matching `*_host_prog` at the interpreter.
g.loaded_python3_provider = 0 -- pynvim. Note: this does NOT affect Python LSP,
                             -- formatting, or neotest-python — those run Python
                             -- as an ordinary subprocess, not as a provider.
g.loaded_ruby_provider = 0
g.loaded_perl_provider = 0
g.loaded_node_provider = 0    -- neovim npm package. Does NOT affect the
                              -- TypeScript language server.

-- ── Classified but not enabled ──────────────────────────────────────────────
-- Point a provider at a specific interpreter instead of letting Neovim search.
-- Useful when your default `python3` is a project venv and you want the provider
-- to use a stable one.
-- g.python3_host_prog = vim.fn.expand("~/.venvs/neovim/bin/python")
-- g.node_host_prog = "/usr/local/bin/neovim-node-host"
--
-- Disable Neovim's built-in .editorconfig support. Left ON (the default) because
-- it makes this config automatically respect a project's indent_size, charset and
-- trailing-whitespace rules — a lot of value for zero configuration.
-- g.editorconfig = false

-- ═════════════════════════════════════════════════════════════════════════════
-- 02b  PATH: make mason's tools findable from the very first line of config
-- ═════════════════════════════════════════════════════════════════════════════
-- mason.nvim installs language servers, formatters and linters into
-- stdpath("data")/mason/bin and adds that directory to Neovim's PATH — but only
-- once mason itself has loaded, which is lazily, when a file is first read.
--
-- That creates an order-of-loading trap: anything checking `executable("stylua")`
-- before mason loads sees 0 and concludes the tool is missing. conform.nvim and
-- nvim-lint both do exactly that check.
--
-- Prepending the directory here, at startup, makes it unconditional. The path is
-- stable and platform-correct via stdpath(), and a non-existent directory on PATH
-- is harmless, so this is safe even before mason has installed anything.
local mason_bin = vim.fn.stdpath("data") .. "/mason/bin"
if not (vim.env.PATH or ""):find(mason_bin, 1, true) then
  vim.env.PATH = mason_bin .. (is_win and ";" or ":") .. vim.env.PATH
end

-- ═════════════════════════════════════════════════════════════════════════════
-- 03  GUTTER: LINE NUMBERS, SIGNS, FOLD COLUMN
-- ═════════════════════════════════════════════════════════════════════════════

-- [window] Absolute number on every line. (default: false)
opt.number = true

-- [window] Relative numbers on all *other* lines, so `8k` / `3dd` are countable at
-- a glance. Combined with `number` above you get the hybrid gutter: absolute on
-- the cursor line, relative elsewhere. (default: false)
--
-- An autocmd in autocmds.lua switches this off in insert mode and in windows that
-- lose focus, because relative numbers are only useful where the cursor is.
opt.relativenumber = true

-- [window] Minimum gutter width. 2 fits three digits ("100") without the text
-- shifting sideways the moment you scroll past line 99. (default: 4)
opt.numberwidth = 2

-- [window] Always reserve the sign column. Without this, the whole buffer jumps
-- one column left/right every time a diagnostic or git sign appears — visually
-- exhausting during editing. "yes" = always one column.
-- (default: "auto")
opt.signcolumn = "yes"

-- [window] Fold indicator column. snacks.nvim's statuscolumn draws fold markers
-- here; see lua/plugins/ui.lua. (default: "0")
opt.foldcolumn = "1"

-- ── Classified but not enabled ──────────────────────────────────────────────
-- Reserve two sign columns so a git sign and a diagnostic can show side by side
-- instead of one hiding the other. Costs a column of width; snacks.statuscolumn
-- already merges them intelligently, so it is unnecessary here.
-- opt.signcolumn = "yes:2"
--
-- Fully custom gutter. Neovim 0.10+ lets one expression own numbers, signs and
-- folds. snacks.statuscolumn sets this for us, which is why it is not set here.
-- opt.statuscolumn = "%s%l %C"
--
-- Highlight the text width limit. Set per-language in after/ftplugin/ instead
-- (88 for Python to match ruff, 100 for Rust and TypeScript), because one global
-- number is wrong for every language at once.
-- opt.colorcolumn = "80,120"

-- ═════════════════════════════════════════════════════════════════════════════
-- 04  CURSOR AND CURRENT-LINE EMPHASIS
-- ═════════════════════════════════════════════════════════════════════════════

-- [window] Highlight the line the cursor is on. Cheap orientation cue.
-- (default: false)
opt.cursorline = true

-- [window] What `cursorline` actually highlights. "number,line" tints the whole
-- line *and* brightens the line number. Use just "number" if a full-width tint
-- feels heavy. (default: "both", which equals "number,line")
opt.cursorlineopt = "number,line"

-- [global] Cursor shape per mode, and blinking.
--   n-v-c    normal, visual, command  → block
--   i-ci-ve  insert and friends       → thin vertical bar, so you can see exactly
--                                       where the next character lands
--   r-cr     replace                  → underline, visually distinct from insert
--   o        operator-pending         → short horizontal bar
--   blinkwait700-blinkoff400-blinkon250 gives a calm blink rather than a strobe.
-- Terminals honour shape via DECSCUSR; a few ignore blink settings entirely.
-- (default: "n-v-c-sm:block,i-ci-ve:ver25,r-cr-o:hor20")
opt.guicursor = table.concat({
  "n-v-c:block",
  "i-ci-ve:ver25",
  "r-cr:hor20",
  "o:hor50",
  "a:blinkwait700-blinkoff400-blinkon250",
  "sm:block-blinkwait175-blinkoff150-blinkon175",
}, ",")

-- ── Classified but not enabled ──────────────────────────────────────────────
-- Highlight the cursor's *column* too. Genuinely helpful for aligning columnar
-- data (and in Python, for spotting indentation drift), but it repaints every
-- line on every horizontal move and looks busy. Bound to a toggle instead:
-- <leader>uu in keymaps.lua.
-- opt.cursorcolumn = true
--
-- Highlight the screen column at a fixed offset. Superseded by colorcolumn.
-- opt.colorcolumn = "+1"  -- relative to 'textwidth'

-- ═════════════════════════════════════════════════════════════════════════════
-- 05  COLOUR AND RENDERING
-- ═════════════════════════════════════════════════════════════════════════════

-- [global] 24-bit RGB colour instead of the 256-colour palette. Required for any
-- modern theme to look like its screenshots. Neovim 0.10+ auto-detects support,
-- but setting it explicitly avoids a wrong guess over ssh or in tmux.
-- (default: auto-detected)
opt.termguicolors = true

-- [global] Tell plugins and themes we are on a dark background. Some themes pick
-- an entirely different palette based on this. (default: "dark")
opt.background = "dark"

-- [global] Default border for *every* floating window — LSP hover, signature
-- help, diagnostics popups, `:h` in a float. Neovim 0.11+ only. Before this
-- existed you had to pass a border to each plugin separately; now one line does
-- it and plugins that don't override inherit it.
-- (default: "" — no border)
opt.winborder = require("config.palette").border

-- ── Classified but not enabled ──────────────────────────────────────────────
-- Force a light theme. Flip with `:set background=light` if you ever want it.
-- opt.background = "light"
--
-- Ambiguous-width characters (some box-drawing, some CJK) rendered double-width.
-- Only correct if your terminal agrees; a mismatch misaligns everything.
-- opt.ambiwidth = "double"
--
-- Assume all emoji are double-width. Left at the default because Nerd Font
-- glyphs — which this config uses heavily — are single-width, and forcing double
-- breaks statusline alignment. (default: true)
-- opt.emoji = false
--
-- GUI font. Ignored by terminal Neovim entirely; the terminal owns the font. Only
-- read by GUI clients (Neovide, nvim-qt, FVim). Set here for the day you try one.
-- opt.guifont = "JetBrainsMono Nerd Font:h11"
--
-- Strip GUI chrome (menus, toolbars, scrollbars). GUI clients only.
-- opt.guioptions = ""

-- ═════════════════════════════════════════════════════════════════════════════
-- 06  STATUSLINE, TABLINE, COMMAND LINE
-- ═════════════════════════════════════════════════════════════════════════════

-- [global] 3 = ONE global statusline across the bottom of the whole editor,
-- instead of one per split. With four splits open, per-window statuslines waste
-- four rows repeating the same branch name. This is the single biggest layout
-- improvement in modern Neovim. (default: 2)
opt.laststatus = 3

-- [global] Always show the tabline. bufferline.nvim draws open buffers there, so
-- a permanently visible row means the layout never shifts. 2 = always.
-- (default: 1 — only when more than one tab page exists)
opt.showtabline = 2

-- [global] Height of the command line area. Kept at 1 deliberately.
--
-- noice.nvim moves the command line into a floating popup, which makes `= 0`
-- tempting — it reclaims one row. The catch: with cmdheight=0, any message longer
-- than the screen width triggers a "Press ENTER to continue" prompt, and a few
-- plugins that write directly to the message area cause visible flicker. One row
-- is a cheap price for that not happening. To try it: change this to 0.
-- (default: 1)
opt.cmdheight = 1

-- [global] Don't print "-- INSERT --" on the command line. The statusline already
-- shows the mode, in colour, more legibly. (default: true)
opt.showmode = false

-- [global] Don't show the cursor position at bottom-right either — statusline
-- again. Only has an effect when 'laststatus' is 0. (default: true)
opt.ruler = false

-- [global] Show the partially-typed command ("d2", "\"a3y") in the corner while
-- you type it. Small but genuinely useful for learning and for catching a
-- mistyped count before it executes. (default: true)
opt.showcmd = true

-- [global] Where 'showcmd' draws when the command line is hidden. "last" is the
-- command line; with cmdheight=0 you would want "statusline". (default: "last")
opt.showcmdloc = "last"

-- [global] Let Neovim set the terminal/window title to the current file. WezTerm
-- shows it in the tab, which is how you find the right window at a glance.
-- (default: false)
opt.title = true

-- [global] The title format.
--   %t  filename (tail only)
--   %m  "[+]" when modified
--   %{...} a vimscript expression — here, the cwd shortened to its last component
-- Result: "init.lua [+] — nvim (dotfiles)"
opt.titlestring = "%t%m — nvim (%{fnamemodify(getcwd(), ':t')})"

-- [global] Truncate the title if it exceeds this percentage of available width.
-- (default: 85)
opt.titlelen = 70

-- ── Classified but not enabled ──────────────────────────────────────────────
-- Reclaim the command-line row. See the long note on 'cmdheight' above.
-- opt.cmdheight = 0
--
-- One statusline per window. Revert to this if you dislike the global one.
-- opt.laststatus = 2
--
-- The statusline expression itself. lualine.nvim owns this — see
-- lua/plugins/ui.lua. Never set both; lualine will win and this would be dead.
-- opt.statusline = "%f %m %= %l:%c"
--
-- The tabline expression. bufferline.nvim owns this.
-- opt.tabline = "%!v:lua.require'bufferline'.tabline()"
--
-- Restore the original terminal title on exit rather than leaving Neovim's.
-- Most terminals, WezTerm included, handle this themselves. (default: true)
-- opt.titleold = "bash"
--
-- Height of the command-line *window* (the editable `q:` history buffer).
-- (default: 7)
-- opt.cmdwinheight = 10

-- ═════════════════════════════════════════════════════════════════════════════
-- 07  POPUP MENU AND FLOATING WINDOWS
-- ═════════════════════════════════════════════════════════════════════════════

-- [global] Maximum visible items in the completion popup. Unlimited (0) can cover
-- the whole screen on a big class; 12 is enough to scan without hiding context.
-- (default: 0 — as many as fit)
opt.pumheight = 12

-- [global] Minimum popup width, so short completions don't produce a sliver of a
-- menu that jitters in width as you type. (default: 15)
opt.pumwidth = 15

-- [global] Popup-menu transparency, 0-100. A slight blend hints at the code
-- underneath without hurting legibility. Above ~30 it becomes hard to read.
-- (default: 0)
opt.pumblend = 10

-- ── Classified but not enabled ──────────────────────────────────────────────
-- Transparency for *all* floating windows. Left at 0: hover documentation and
-- diagnostics are text you actually need to read, and blending them with the code
-- behind is the fastest way to make both unreadable. Set 5-10 if you want the
-- look and can live with it. (default: 0)
-- opt.winblend = 10
--
-- Minimum height/width a window shrinks to. See section 09.
-- opt.winminheight = 1

-- ═════════════════════════════════════════════════════════════════════════════
-- 08  WHITESPACE AND SPECIAL CHARACTERS
-- ═════════════════════════════════════════════════════════════════════════════

-- [window] Render otherwise-invisible characters listed in 'listchars'. Being
-- able to see a hard tab in a space-indented file, or a non-breaking space
-- pasted from a browser, saves a genuinely baffling class of bug.
-- (default: false)
opt.list = true

-- [window] Which invisibles to draw, and how.
--   tab       two-cell glyph: an arrow and a filler, so tab *width* is visible
--   trail     trailing whitespace — the thing that fails your linter
--   nbsp      non-breaking space, invisible until it breaks your parser
--   extends   line continues past the right edge (when 'wrap' is off)
--   precedes  line continues past the left edge
--   NOT set: `eol` and `space`, which mark every single line end and every space.
--            Technically informative, visually unbearable.
opt.listchars = { tab = "→ ", trail = "·", nbsp = "␣", extends = "❯", precedes = "❮" }

-- [window] Characters used for UI structure rather than buffer content.
--   eob        end-of-buffer filler. Space instead of "~", so short files don't
--              trail a column of tildes.
--   fold       padding after a closed fold's text
--   foldopen   marker for an open fold in the fold column
--   foldclose  marker for a closed fold
--   foldsep    vertical continuation of a multi-line fold
--   diff       filler for missing lines in a diff. "╱" reads as "nothing here"
--              much better than the default "-".
--   vert/horiz clean single-line window separators
opt.fillchars = {
  eob = " ",
  fold = " ",
  foldopen = "▾",
  foldclose = "▸",
  foldsep = "│",
  diff = "╱",
  vert = "│",
  horiz = "─",
  horizup = "┴",
  horizdown = "┬",
  vertleft = "┤",
  vertright = "├",
  verthoriz = "┼",
}

-- [window] Hide markup (markdown emphasis, JSON quotes, LaTeX math) when the
-- cursor is not on that line.
--   0 = never conceal, 1 = conceal to one char, 2 = conceal fully, 3 = also hide
--       chars with no replacement
-- Kept at 0 globally: concealing *code* means the buffer no longer shows what is
-- in the file, which is dangerous when editing. Raised to 2 only for markdown,
-- in after/ftplugin/markdown.lua, where it is the whole point.
-- (default: 0)
opt.conceallevel = 0

-- [window] Reveal concealed text on the cursor line in these modes, so you can
-- edit what you are looking at. Empty = always reveal on the cursor line.
-- (default: "")
opt.concealcursor = ""

-- ── Classified but not enabled ──────────────────────────────────────────────
-- Mark every end of line and every space. Available if you are hunting a
-- whitespace bug: `:set listchars+=eol:¬,space:·`.
-- opt.listchars:append({ eol = "¬", space = "·" })
--
-- Show "~" past the end of the buffer, as Vim always did.
-- opt.fillchars:append({ eob = "~" })

-- ═════════════════════════════════════════════════════════════════════════════
-- 09  WINDOW SPLITTING AND SIZING
-- ═════════════════════════════════════════════════════════════════════════════

-- [global] `:split` puts the new window BELOW the current one. Vim's default puts
-- it above, which means the file you just opened appears somewhere your eyes
-- aren't. (default: false)
opt.splitbelow = true

-- [global] `:vsplit` puts the new window to the RIGHT. Same reasoning, and it
-- matches how every other editor and every left-to-right reader works.
-- (default: false)
opt.splitright = true

-- [global] Keep the *text* visually still when a split opens or closes above the
-- current window. Without this, opening a terminal at the bottom scrolls your
-- code and you lose your place. "screen" is the least surprising setting in the
-- editor. (default: "cursor")
opt.splitkeep = "screen"

-- [global] Don't automatically equalise all window sizes when one is closed. With
-- this on, closing a small utility split reflows every other window. Off means
-- the remaining layout stays where you put it. (default: true)
opt.equalalways = false

-- [global] Narrowest a non-current window will shrink to. 5 keeps a sliver
-- visible and clickable rather than collapsing it to nothing. (default: 1)
opt.winminwidth = 5

-- ── Classified but not enabled ──────────────────────────────────────────────
-- Shortest a non-current window shrinks to. (default: 1)
-- opt.winminheight = 1
--
-- Preferred height/width for the current window; Neovim grows it toward this
-- whenever you switch. A "focus follows cursor" layout: pleasant with two splits,
-- disorienting with five, because every jump reflows the screen.
-- opt.winheight = 20
-- opt.winwidth = 100
--
-- Which axis `equalalways` balances. Irrelevant while equalalways is off.
-- opt.eadirection = "hor"
--
-- Height of `:help` and `:preview` windows. Left at defaults (20 / 12).
-- opt.helpheight = 20
-- opt.previewheight = 12

-- ═════════════════════════════════════════════════════════════════════════════
-- 10  SCROLLING
-- ═════════════════════════════════════════════════════════════════════════════

-- [window] Keep 8 lines of context above and below the cursor. The cursor stops
-- drifting to the very edge of the screen, so you always see what you are
-- scrolling toward. Set 999 to pin the cursor to the vertical centre.
-- (default: 0)
opt.scrolloff = 8

-- [window] Same idea horizontally, when 'wrap' is off. (default: 0)
opt.sidescrolloff = 8

-- [window] Scroll horizontally one column at a time instead of jumping half a
-- screen. (default: 0 — meaning half a screen)
opt.sidescroll = 1

-- [window] Scroll by screen *line* rather than by buffer line, so a single
-- wrapped long line no longer jumps the view a whole paragraph at a time.
-- Matters most in markdown and prose. (default: false)
opt.smoothscroll = true

-- [global] How far a mouse wheel notch scrolls: 3 lines vertically, 6 columns
-- horizontally. (default: "ver:3,hor:6")
opt.mousescroll = "ver:3,hor:6"

-- ── Classified but not enabled ──────────────────────────────────────────────
-- Lines scrolled by CTRL-U / CTRL-D. 0 means half a window, which correctly
-- follows window resizes. (default: 0)
-- opt.scroll = 10
--
-- Scroll all windows together — for side-by-side diffs. 'diffopt' already
-- enables it inside a diff, which is the only place it is wanted.
-- opt.scrollbind = true
-- opt.cursorbind = true
--
-- Fine-tune scrollbind. (default: "ver,jump")
-- opt.scrollopt = "ver,hor,jump"

-- ═════════════════════════════════════════════════════════════════════════════
-- 11  LINE WRAPPING
-- ═════════════════════════════════════════════════════════════════════════════

-- [window] Do NOT wrap long lines; let them run off-screen. For code this is
-- correct — wrapping destroys the vertical alignment that makes indentation
-- readable, and makes `j`/`k` behave unpredictably. Turned ON for markdown and
-- text in after/ftplugin/. Toggle any time with <leader>uw. (default: true)
opt.wrap = false

-- [window] IF a line does wrap, break at a word boundary, not mid-word.
-- Costs nothing while 'wrap' is off, and means the ftplugin override just works.
-- (default: false)
opt.linebreak = true

-- [window] Wrapped continuation lines inherit the indent of the line they
-- continue, so a wrapped bullet stays visually inside its bullet. (default: false)
opt.breakindent = true

-- [window] Fine-tune that indent. `shift:2` pushes continuations two extra
-- columns in, which distinguishes "this is a continuation" from "this is a new
-- line at the same level". (default: "")
opt.breakindentopt = "shift:2"

-- [window] Marker at the start of a wrapped continuation line. (default: "")
opt.showbreak = "↪ "

-- ── Classified but not enabled ──────────────────────────────────────────────
-- Characters where a wrapped line may break. (default: " ^I!@*-+;:,./?")
-- opt.breakat = " ^I!@*-+;:,./?"
--
-- Hard-wrap while typing at this column. See 'textwidth' in section 22 — this is
-- the same knob, and it is off for code and on for prose.
-- opt.wrapmargin = 5  -- legacy: like textwidth but measured from the right edge.
--                        Ignored entirely when textwidth is non-zero. Prefer
--                        textwidth; this exists only for Vim compatibility.

-- ═════════════════════════════════════════════════════════════════════════════
-- 12  INDENTATION AND TABS
-- ═════════════════════════════════════════════════════════════════════════════
-- The global values here are the *fallback*. Real per-language widths live in
-- after/ftplugin/ (Python and Rust use 4, Lua and TypeScript use 2), and a
-- project's .editorconfig overrides both — Neovim reads it natively.

-- [buffer] Pressing <Tab> inserts spaces, never a hard tab character. The right
-- default in 2026: every language in this config has a formatter that emits
-- spaces, and mixed tabs/spaces is a diff-noise generator. Makefiles and Go need
-- real tabs; both are handled in after/ftplugin/. (default: false)
opt.expandtab = true

-- [buffer] How many columns a hard tab character *displays* as. Only affects
-- rendering of tabs already in the file. (default: 8)
opt.tabstop = 2

-- [buffer] How many columns <Tab> and <BS> move in insert mode. Kept equal to
-- 'tabstop' so there is exactly one number to reason about. (default: 0)
opt.softtabstop = 2

-- [buffer] How many columns `>>`, `<<` and auto-indent shift by. (default: 8)
opt.shiftwidth = 2

-- [buffer] Round `>>` to a multiple of 'shiftwidth' instead of adding a fixed
-- amount, so indentation self-corrects when a line is already misaligned.
-- (default: false)
opt.shiftround = true

-- [global] Make <Tab> at the start of a line insert 'shiftwidth' worth of
-- indent, while a <Tab> elsewhere still inserts 'tabstop'. (default: true)
opt.smarttab = true

-- [buffer] Copy the previous line's indent when starting a new line. The baseline
-- indent behaviour; treesitter's 'indentexpr' overrides it wherever a parser is
-- available, and this is the graceful fallback where one isn't. (default: true)
opt.autoindent = true

-- [buffer] 'smartindent' is deliberately OFF.
--
-- It is a crude C-flavoured heuristic: indent after `{`, outdent on `}`, and —
-- the notorious part — force any line starting with `#` to column zero, because it
-- assumes `#` is a C preprocessor directive. In Python that de-indents every
-- comment you type inside a function. Treesitter's 'indentexpr' is strictly
-- better and language-aware, and 'indentexpr' takes precedence over both
-- 'smartindent' and 'cindent' anyway. Leaving it off avoids the fallback case
-- being actively wrong. (default: false)
opt.smartindent = false

-- ── Classified but not enabled ──────────────────────────────────────────────
-- Per-language indent expression. Set per-buffer by nvim-treesitter — see
-- lua/plugins/treesitter.lua. Never set globally.
-- opt.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
--
-- C-specific indenting and its ~50 tuning flags. Superseded by treesitter for
-- every language in this config.
-- opt.cindent = true
-- opt.cinoptions = "l1,g0,N-s,t0,(0,W4"
-- opt.cinwords = "if,else,while,do,for,switch"
-- opt.cinkeys = "0{,0},0),0],:,0#,!^F,o,O,e"
-- opt.cinscopedecls = "public,protected,private"
--
-- Preserve the existing mix of tabs and spaces when re-indenting a line, rather
-- than normalising it. Only useful in a codebase you are not allowed to reformat.
-- opt.preserveindent = true
-- opt.copyindent = true
--
-- Which keys <BS> may delete over. The default "indent,eol,start" is already the
-- sane modern behaviour (backspace works everywhere); Vim's original default made
-- it refuse to delete past the insert point. Do not change this.
-- opt.backspace = "indent,eol,start"
--
-- Lisp-specific indenting. Only relevant if you edit Lisp/Scheme/Clojure.
-- opt.lisp = true
-- opt.lispwords = "defun,define,defmacro"

-- ═════════════════════════════════════════════════════════════════════════════
-- 13  SEARCH
-- ═════════════════════════════════════════════════════════════════════════════

-- [global] Case-insensitive search by default. (default: false)
opt.ignorecase = true

-- [global] ...but case-SENSITIVE the moment your pattern contains a capital.
-- So `/error` finds Error and ERROR, while `/Error` finds only Error. This pair
-- is the single best search configuration in Vim and there is no good reason to
-- run 'ignorecase' without it. (default: false)
opt.smartcase = true

-- [global] Keep matches highlighted after the search completes. Paired with a
-- `<Esc>` mapping in keymaps.lua that clears the highlight, so it is informative
-- while you want it and gone the instant you don't. (default: true)
opt.hlsearch = true

-- [global] Jump to and highlight matches as you type the pattern, before you
-- press <CR>. (default: true)
opt.incsearch = true

-- [global] Wrap around the end of the file when searching. (default: true)
opt.wrapscan = true

-- ── Classified but not enabled ──────────────────────────────────────────────
-- Make `\v` "very magic" regex the default so you write `(a|b)+` instead of
-- `\(a\|b\)\+`. Tempting, but it silently changes the meaning of every pattern in
-- every plugin, macro and snippet you copy from the internet. Type `\v` at the
-- start of a pattern instead — same benefit, no global blast radius.
-- (default: true, and leave it)
-- opt.magic = false
--
-- Case sensitivity for tag lookups specifically. (default: "followic")
-- opt.tagcase = "smart"
--
-- Where to search for tags files. ctags is largely replaced by LSP here.
-- opt.tags = "./tags;,tags"

-- ═════════════════════════════════════════════════════════════════════════════
-- 14  SUBSTITUTION AND REPLACE
-- ═════════════════════════════════════════════════════════════════════════════

-- [global] Live-preview `:substitute` results *in the buffer itself* as you type
-- the command. "nosplit" previews inline; "split" additionally opens a scratch
-- window listing every affected line. Inline is less disruptive and enough 95% of
-- the time. This turns `:%s/.../.../` from a leap of faith into a WYSIWYG edit.
-- (default: "nosplit")
opt.inccommand = "nosplit"

-- ── Classified but not enabled ──────────────────────────────────────────────
-- Show the full list of changes in a split during :substitute preview.
-- opt.inccommand = "split"
--
-- Make :substitute global by default, inverting the meaning of the /g flag. A
-- classic footgun: every substitute you copy from documentation now does the
-- opposite of what it says. Type the /g.
-- opt.gdefault = true
--
-- Project-wide find-and-replace is handled by grug-far.nvim (<leader>sr), which
-- is a far better interface than any option here — see lua/plugins/editor.lua.

-- ═════════════════════════════════════════════════════════════════════════════
-- 15  INSERT-MODE COMPLETION
-- ═════════════════════════════════════════════════════════════════════════════
-- blink.cmp owns the completion *experience* (see lua/plugins/completion.lua).
-- These options still matter: they govern built-in `i_CTRL-X` completion, and
-- blink reads some of them.

-- [global] How the completion menu behaves.
--   menu      show a popup menu
--   menuone   show it even for a single match — so you can always see what you
--             are about to accept instead of it silently inserting
--   noselect  do not preselect anything; typing keeps filtering and <CR> stays a
--             newline until you deliberately pick with <Tab>/<C-n>. Prevents the
--             single most annoying completion failure mode: pressing Enter for a
--             newline and getting a random symbol.
--   fuzzy     allow fuzzy matching in the built-in menu (Neovim 0.11+)
--   popup     show extra info in a floating window rather than a preview split
-- (default: "menu,preview")
opt.completeopt = { "menu", "menuone", "noselect", "fuzzy", "popup" }

-- [buffer] Which sources built-in CTRL-N scans.
--   . current buffer   w other windows' buffers   b loaded buffers
--   u unloaded buffers   t tags
-- Dropped from the default: `i`, which follows every #include / import
-- recursively and can hang for seconds on a large C or Python tree.
-- (default: ".,w,b,u,t,i")
opt.complete = { ".", "w", "b", "u" }

-- [global] Adjust case of a completion to match what you typed, so `foo<C-n>`
-- can complete to `FooBar`. (default: false)
opt.infercase = true

-- ── Classified but not enabled ──────────────────────────────────────────────
-- Neovim 0.11+ can drive completion entirely from the LSP with no plugin at all:
--   vim.lsp.completion.enable(true, client_id, bufnr, { autotrigger = true })
-- Genuinely viable now, and worth knowing about if you ever want a zero-plugin
-- setup. blink.cmp is still ahead on snippets, multiple sources, ranking and
-- signature help, which is why it is used here.
--
-- Custom completion functions. LSP provides both via blink.
-- opt.completefunc = "v:lua.require'mymodule'.complete"
-- opt.omnifunc = "v:lua.vim.lsp.omnifunc"
--
-- Word list files for CTRL-X CTRL-K. Enabled in markdown's ftplugin if you want
-- English word completion while writing prose.
-- opt.dictionary = "/usr/share/dict/words"
-- opt.thesaurus = vim.fn.stdpath("config") .. "/spell/thesaurus.txt"
--
-- Limit how far the `i`/`d` include-completion scan follows. Irrelevant here
-- since `i` was removed from 'complete' above.
-- opt.include = "^\\s*#\\s*include"
-- opt.define = "^\\s*#\\s*define"

-- ═════════════════════════════════════════════════════════════════════════════
-- 16  SPELL CHECKING
-- ═════════════════════════════════════════════════════════════════════════════

-- [window] Spell check OFF globally. In code it flags every identifier and
-- abbreviation, which trains you to ignore the highlight entirely. Enabled only
-- for markdown, text and gitcommit in after/ftplugin/, where it earns its keep.
-- Toggle with <leader>us. (default: false)
opt.spell = false

-- [buffer] Languages to check. Add "es" here if you want Spanish checked too —
-- Neovim will offer to download the dictionary on first use.
-- (default: "en")
opt.spelllang = { "en_us" }

-- [buffer] How words are split for checking.
--   camel         treat camelCase as separate words, so "getUserName" checks as
--                 three words rather than one giant unknown one
--   noplainbuffer do not spell check buffers without syntax highlighting — stops
--                 terminal output and log files getting carpeted in red
-- (default: "")
opt.spelloptions = "camel,noplainbuffer"

-- ── Classified but not enabled ──────────────────────────────────────────────
-- Where `zg` (add word) writes. Defaults into stdpath("data"). Point it at a file
-- inside this repo to version-control your personal dictionary across machines:
-- opt.spellfile = vim.fn.stdpath("config") .. "/spell/en.utf-8.add"
--
-- Suggestion strategy and how many to offer. (default: "best")
-- opt.spellsuggest = "best,9"
--
-- Pattern marking the end of a sentence for capitalisation checks.
-- opt.spellcapcheck = "[.?!]\\_[\\])'\"\\t ]\\+"

-- ═════════════════════════════════════════════════════════════════════════════
-- 17  FOLDING
-- ═════════════════════════════════════════════════════════════════════════════
-- Folding here is treesitter-driven, so folds follow real syntax (functions,
-- classes, blocks) rather than indentation guesswork.

-- [window] Folding enabled. (default: true)
opt.foldenable = true

-- [window] Fold by expression. (default: "manual")
opt.foldmethod = "expr"

-- [window] The expression: Neovim's built-in treesitter fold provider. It uses
-- the parser's `@fold` captures, and — importantly — degrades gracefully to no
-- folds in a buffer with no parser, rather than erroring.
opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"

-- [window] Empty string = let Neovim render the folded line with its normal
-- syntax highlighting, instead of the old monochrome "+--  12 lines: ---".
-- Neovim 0.10+. Much nicer, and free. (default: "foldtext()")
opt.foldtext = ""

-- [window] Open all folds when a file loads. 99 effectively means "never fold on
-- open". Folds that snap shut the moment you open a file are the reason most
-- people disable folding entirely; this keeps folding available on demand (`za`)
-- without it ambushing you. (default: 0)
opt.foldlevel = 99
opt.foldlevelstart = 99

-- [window] Deepest fold level that can be created. Prevents pathological nesting
-- in deeply indented code. (default: 20)
opt.foldnestmax = 4

-- [window] Don't fold anything shorter than this many lines — a two-line fold
-- saves nothing and just adds a click. (default: 1)
opt.foldminlines = 2

-- ── Classified but not enabled ──────────────────────────────────────────────
-- Other fold methods:
--   "indent"  fold by indentation. Fast, no parser needed, surprisingly usable
--             in Python. A reasonable fallback if treesitter folding annoys you.
--   "syntax"  fold by legacy vim syntax regions. Slow; superseded by treesitter.
--   "marker"  fold on literal {{{ }}} comments. Explicit and stable — this file
--             would fold nicely with it. Requires polluting the source.
--   "manual"  zf creates folds by hand; lost on close unless 'viewoptions' saves.
--   "diff"    fold unchanged lines in a diff. Set automatically by 'diff'.
-- opt.foldmethod = "indent"
--
-- Which commands automatically open a closed fold when they move into it.
-- The default already covers search, jumps and insert. Add "all" to make every
-- motion open folds — convenient, but you lose the fold structure as you navigate.
-- opt.foldopen = "block,hor,mark,percent,quickfix,search,tag,undo"
-- opt.foldclose = "all"  -- auto-close folds when you leave them. Disorienting.
--
-- Markers for foldmethod=marker. (default: "{{{,}}}")
-- opt.foldmarker = "{{{,}}}"
--
-- Lines starting with this are ignored when computing indent folds. (default: "#")
-- opt.foldignore = "#"
--
-- Columns of extra indent per fold level in the fold column.
-- opt.foldcolumn = "auto:3"

-- ═════════════════════════════════════════════════════════════════════════════
-- 18  ENCODING, FILE FORMATS AND LINE ENDINGS
-- ═════════════════════════════════════════════════════════════════════════════
-- This section is where cross-platform configs usually go wrong. The goal: LF
-- everywhere, UTF-8 everywhere, and never silently rewrite a file's existing
-- line endings.

-- [global] Encoding used for files written by Neovim. UTF-8, always.
-- Note: 'encoding' (the *internal* encoding) is locked to UTF-8 in Neovim and
-- cannot be changed — that is a deliberate simplification over Vim.
-- (default: "utf-8")
opt.fileencoding = "utf-8"

-- [global] Encodings to try, in order, when *reading* a file. `ucs-bom` first so a
-- byte-order mark is detected rather than shown as garbage; `latin1` last as the
-- catch-all that never fails, so a legacy file opens as mojibake rather than
-- refusing to open. (default: "ucs-bom,utf-8,default,latin1")
opt.fileencodings = { "ucs-bom", "utf-8", "utf-16le", "cp1252", "latin1" }

-- [buffer] Line ending for NEW files: Unix LF, even on Windows. Since this config
-- and its files travel to Linux, CRLF would show up as `^M` there and pollute
-- every diff. (default: "unix" on Unix, "dos" on Windows)
opt.fileformat = "unix"

-- [global] Formats to detect when *opening* an existing file, in priority order.
-- With "unix" first, a file that is already CRLF is still recognised as dos and
-- written back as dos — Neovim preserves what it found. This is the important
-- part: we default new files to LF without mangling existing CRLF files.
-- (default: "unix,dos")
opt.fileformats = { "unix", "dos" }

-- [buffer] Do not write a UTF-8 byte-order mark. BOMs break shell scripts,
-- confuse some compilers, and show up as a stray character in diffs. (default: false)
opt.bomb = false

-- [buffer] Ensure a trailing newline at end of file, POSIX-style. Stops the
-- "\ No newline at end of file" line in every git diff. (default: true)
opt.fixendofline = true

-- ── Classified but not enabled ──────────────────────────────────────────────
-- Whether the last line has an EOL. Set automatically from the file; changing it
-- by hand is how you deliberately strip a trailing newline. (default: true)
-- opt.endofline = false
--
-- Read modelines — configuration comments embedded in a file, like
-- `# vim: ts=4 sw=4`. Left ON (the default) because it is genuinely useful for
-- one-off files. Be aware it is a mild code-execution surface: a hostile file can
-- set options when you open it. Neovim sandboxes this far better than old Vim did,
-- but if you routinely open untrusted files, turn it off:
-- opt.modeline = false
-- opt.modelines = 5  -- how many lines at each end to scan (default: 5)
--
-- Directories searched by `gf`, `:find` and friends. Appending "**" enables
-- recursive `:find`, which is convenient but scans the entire tree on every
-- completion — slow in a large repo. The fuzzy picker (<leader>ff) is faster and
-- better, so this stays at its default.
-- opt.path:append("**")
--
-- Extensions `gf` tries when the filename has none. Set per-language instead —
-- e.g. after/ftplugin for JS adds ".js,.jsx,.ts".
-- opt.suffixesadd = ".lua,.py,.rs,.ts"
--
-- Deprioritise these extensions when several files match. (default: ".bak,~,.o,...")
-- opt.suffixes = ".bak,~,.o,.info,.swp,.obj"

-- ═════════════════════════════════════════════════════════════════════════════
-- 19  BACKUP, SWAP, UNDO AND SHADA
-- ═════════════════════════════════════════════════════════════════════════════
-- Position: persistent undo is the real safety net; backups and swap files are
-- 1990s answers to problems git and undo-tree already solve.

-- [global] No backup copy of the previous version. That is what git is for, and
-- stray `file~` siblings clutter directories and occasionally get committed.
-- (default: false)
opt.backup = false

-- [global] No backup *during* the write either. Neovim writes to a temp file and
-- renames, so this is about crash-mid-write paranoia only.
--
-- Caveat worth knowing: some file watchers (older webpack, and a few
-- containerised dev servers) miss changes unless the file is written in place.
-- If a watcher stops noticing your edits, `opt.backupcopy = "yes"` is the fix.
-- (default: true)
opt.writebackup = false

-- [global] No swap files. Swap exists to recover unsaved work after a crash, and
-- it costs you the "ATTENTION: found a swap file" dialog every time a session
-- ends badly or a file is open twice. With persistent undo below plus autosave-ish
-- behaviour in autocmds.lua, the trade is worth it. (default: true)
opt.swapfile = false

-- [global] Persistent undo: the full undo tree survives closing the file, and
-- Neovim itself. You can reopen a file tomorrow and press `u` back through
-- yesterday's edits. This is the single most valuable option in this section and
-- the reason the two above can safely be off. (default: false)
opt.undofile = true

-- [global] Where undo history is stored. stdpath("state") is the correct
-- XDG-aware location on both platforms: ~/.local/state/nvim on Linux,
-- ~/AppData/Local/nvim-data on Windows. Never hardcode a path here — that is the
-- most common way a config breaks when it crosses machines.
opt.undodir = vim.fn.stdpath("state") .. "/undo"

-- [buffer] How many undo steps to remember. 10000 is effectively "all of them";
-- the history is a few KB per file. (default: 1000)
opt.undolevels = 10000

-- [global] Save undo history for a buffer reloaded from disk if it is under this
-- many lines, so `:e!` does not throw away your undo tree. (default: 10000)
opt.undoreload = 10000

-- [global] What persists across sessions in the ShaDa ("shared data") file.
--   '500   marks for the last 500 files
--   <50    at most 50 lines per register — stops a giant yank bloating the file
--   s10    skip any register item larger than 10 KB
--   h      do not restore hlsearch on startup (no mystery highlight at launch)
--   /100   100 search-history entries
--   :100   100 command-history entries
-- (default: "!,'100,<50,s10,h")
opt.shada = { "'500", "<50", "s10", "h", "/100", ":100" }

-- ── Classified but not enabled ──────────────────────────────────────────────
-- Turn backups on and keep them out of your working tree. The trailing "//" makes
-- Neovim encode the full path into the backup's filename, so two files with the
-- same basename in different directories don't overwrite each other's backup.
-- opt.backup = true
-- opt.backupdir = vim.fn.stdpath("state") .. "/backup//"
-- opt.backupcopy = "yes"     -- write in place; fixes file-watcher problems
-- opt.backupskip = "/tmp/*,*.gpg"  -- never back these up
-- opt.backupext = ".bak"
--
-- Swap file location and flush interval, if you re-enable swapfile.
-- opt.directory = vim.fn.stdpath("state") .. "/swap//"
-- opt.updatecount = 200  -- write swap after this many typed characters
--
-- Also persist uppercase (global) marks and the buffer list across sessions.
-- The "!" saves global variables too. persistence.nvim handles sessions properly
-- here, so this stays minimal.
-- opt.shada:append("%")   -- restore the buffer list
-- opt.shada:prepend("!")  -- restore global variables
--
-- fsync after every write. Real durability against power loss, real latency cost
-- on every :w. (default: false)
-- opt.fsync = true

-- ═════════════════════════════════════════════════════════════════════════════
-- 20  BUFFER AND WINDOW BEHAVIOUR
-- ═════════════════════════════════════════════════════════════════════════════

-- [global] Let a modified buffer be hidden instead of forcing a write or a
-- discard when you switch away. Effectively mandatory for any multi-file
-- workflow. Neovim already defaults this on, unlike Vim. (default: true)
opt.hidden = true

-- [global] Ask "save changes?" instead of failing with "E37: No write since last
-- change" when you `:q` a modified buffer. Turns an error you must decode into a
-- prompt you can answer. (default: false)
opt.confirm = true

-- [global] Reload a file that changed on disk, if it has no unsaved changes here.
-- Essential when git changes branches under you, or a formatter rewrites the file.
-- Needs a nudge to actually fire — see the CursorHold `:checktime` autocmd in
-- autocmds.lua. (default: true)
opt.autoread = true

-- [global] Where `:sbuffer`, quickfix jumps and LSP "go to definition" prefer to
-- open a buffer.
--   uselast  reuse the last-focused normal window rather than splitting
--   usetab   if the buffer is already open in another tab, jump there
-- Stops quickfix navigation from shredding your layout into ten splits.
-- (default: "uselast")
opt.switchbuf = { "usetab", "uselast" }

-- [global] Jump-list behaviour.
--   stack  make CTRL-O / CTRL-I behave like a browser's back/forward, discarding
--          the forward branch when you jump somewhere new. Vim's default keeps a
--          confusing linear history instead.
--   view   restore the scroll position, not just the cursor line, when you jump
--          back — so returning somewhere actually looks like where you left.
-- (default: "clean")
opt.jumpoptions = "stack,view"

-- ── Classified but not enabled ──────────────────────────────────────────────
-- Write the current buffer automatically before :next, :make, etc.
-- opt.autowrite = true
-- opt.autowriteall = true  -- also on :quit, :edit and friends. Aggressive: it
--                             writes files you may have opened only to look at.
--
-- Change the working directory to the current file's directory automatically.
-- Actively harmful with project-scoped tooling: it silently reroots your fuzzy
-- finder, LSP and grep to whichever file you last touched. Use the LSP's root
-- detection instead (it is what `vim.lsp.config` already does).
-- opt.autochdir = true
--
-- Behaviour of the message/report threshold. `report = 0` (set in section 33)
-- makes Neovim always tell you how many lines changed.

-- ═════════════════════════════════════════════════════════════════════════════
-- 21  CLIPBOARD AND REGISTERS
-- ═════════════════════════════════════════════════════════════════════════════

-- [global] Make `y` and `p` use the SYSTEM clipboard by default, so copy-paste
-- works between Neovim and the rest of the machine with no extra keystrokes.
--
-- "unnamedplus" targets the "+" register (the normal Ctrl-C clipboard on Linux).
-- "unnamed" targets "*" (the X11 middle-click primary selection). On Windows and
-- macOS both are the same clipboard, so unnamedplus is correct everywhere.
--
-- PLATFORM REQUIREMENTS — this is the #1 thing that breaks on a fresh Linux box:
--   Wayland → install `wl-clipboard`
--   X11     → install `xclip` or `xsel`
--   WSL     → works via win32yank, usually already present
--   ssh     → no tool needed; Neovim 0.10+ falls back to OSC 52, which asks the
--             *terminal* to set the clipboard. WezTerm supports this, so yanking
--             over ssh lands in your local clipboard. Nothing to configure.
-- `:checkhealth provider` names the missing tool if it isn't working.
--
-- The trade-off: every delete and change also overwrites your system clipboard.
-- keymaps.lua adds `<leader>p` (paste without overwriting) and `<leader>d`
-- (delete to the black hole register) to work around that.
-- (default: "")
opt.clipboard = "unnamedplus"

-- ── Classified but not enabled ──────────────────────────────────────────────
-- Keep Neovim's registers fully separate from the system clipboard, and use the
-- explicit "+ prefix ("+y, "+p) when you want to cross the boundary. Purist and
-- avoids the overwrite problem entirely, at the cost of two extra keys every time.
-- opt.clipboard = ""
--
-- Force a specific clipboard tool. Only needed if auto-detection picks wrong —
-- for instance on a machine with both xclip and wl-clipboard where you are
-- actually on Wayland.
-- g.clipboard = {
--   name = "wl-clipboard",
--   copy = { ["+"] = { "wl-copy" }, ["*"] = { "wl-copy", "--primary" } },
--   paste = { ["+"] = { "wl-paste", "--no-newline" }, ["*"] = { "wl-paste", "--no-newline", "--primary" } },
--   cache_enabled = true,
-- }
--
-- Force OSC 52 even when a local clipboard tool exists — useful inside a
-- container or a remote tmux where the "local" tool talks to the wrong display.
-- g.clipboard = "osc52"

-- ═════════════════════════════════════════════════════════════════════════════
-- 22  TEXT FORMATTING AND COMMENTS
-- ═════════════════════════════════════════════════════════════════════════════

-- [buffer] Hard-wrap column. 0 = never auto-wrap while typing, which is what you
-- want in code (the formatter owns line length, not the editor). Set to 80 for
-- markdown and gitcommit in after/ftplugin/. (default: 0)
opt.textwidth = 0

-- [buffer] Automatic formatting behaviour. This option is a set of single-letter
-- flags and is worth understanding, because it controls the two things people
-- most often find mysterious: comment continuation, and lines wrapping by
-- themselves.
--   j  when joining lines with J, remove a redundant comment leader
--   c  auto-wrap comments at 'textwidth'
--   r  continue the comment leader when you press <CR> in insert mode  ← wanted
--   o  continue it after `o`/`O` too. Kept, but note it means opening a line
--      below a comment gives you another comment — press <C-u> to clear it.
--   q  allow `gq` to format comments
--   l  do not auto-wrap a line that was already too long before you touched it
--   n  recognise numbered lists and indent their continuations correctly
--   t  auto-wrap ordinary text at 'textwidth'  ← deliberately ABSENT, so code is
--      never reflowed behind your back. markdown's ftplugin adds it back.
-- (default: "tcqj")
opt.formatoptions = "jcroqlnt"

-- [buffer] Two spaces after a period when joining sentences with J: no. This is
-- a typewriter convention that survived into Vim's defaults. (default: false)
opt.joinspaces = false

-- [buffer] What CTRL-A / CTRL-X treat as a number.
--   bin, hex  understand 0b1010 and 0xff
--   unsigned  never treat a leading "-" as part of the number, so CTRL-X on
--             "foo-1" gives "foo-0" rather than "foo-2"
-- Deliberately WITHOUT "octal": otherwise incrementing "007" gives "010", which
-- is correct octal and almost never what you meant.
-- (default: "bin,hex")
opt.nrformats = { "bin", "hex", "unsigned" }

-- ── Classified but not enabled ──────────────────────────────────────────────
-- External program used by `gq`. conform.nvim (<leader>cf) handles formatting
-- properly, per language, so this is unnecessary.
-- opt.formatprg = "prettier --stdin-filepath %"
--
-- Expression used by `gq`. Set per-buffer by the LSP to use range formatting:
-- opt.formatexpr = "v:lua.require'conform'.formatexpr()"
--
-- What counts as a comment leader, per filetype. Set by ftplugins; overriding it
-- globally breaks comment continuation in every language at once.
-- opt.comments = "s1:/*,mb:*,ex:*/,://,b:#,:%,:XCOMM,n:>,fb:-"
--
-- Template for the comment `gcc` inserts. Neovim 0.10+ has built-in `gc`
-- commenting, and ts-comments.nvim keeps this correct inside embedded languages
-- (JS inside HTML, for example). Set per-buffer, never globally.
-- opt.commentstring = "-- %s"
--
-- Where paragraphs and sections begin, for `{`, `}`, `[[`, `]]` motions.
-- Meaningful mostly for roff/LaTeX.
-- opt.paragraphs = "IPLPPPQPP TPHPLIPpLpItpplpipbp"
-- opt.sections = "SHNHH HUnhsh"

-- ═════════════════════════════════════════════════════════════════════════════
-- 23  WORD, FILENAME AND PAIR CHARACTERS
-- ═════════════════════════════════════════════════════════════════════════════

-- [global] Characters that `%` jumps between. Adding <:> helps in HTML/JSX and
-- Rust generics. (default: "(:),{:},[:]")
opt.matchpairs = "(:),{:},[:],<:>"

-- [global] Let the cursor sit one column past end-of-line, but only in visual
-- BLOCK mode — which makes rectangular selection over ragged lines actually work.
-- "all" would allow it everywhere and makes normal editing feel unmoored.
-- (default: "")
opt.virtualedit = "block"

-- [global] Which motions may wrap to the previous/next line at a line boundary.
--   b  <BS>      s  <Space>      h,l  in normal/visual      <,>  arrow keys
--   ~  the ~ command      [,]  arrow keys in insert mode
-- Without this, pressing `l` at end of line just stops, which is technically
-- pure and practically irritating. (default: "b,s")
opt.whichwrap = "b,s,h,l,<,>,[,]"

-- [global] Don't jump the cursor to the first non-blank character on commands
-- like CTRL-D or `G`; keep the column. Preserves your horizontal place while
-- scrolling. (default: true)
opt.startofline = false

-- [global] Report every change, however small ("1 line less"). The default of 2
-- hides one- and two-line changes, which is exactly when a silent no-op is most
-- confusing. (default: 2)
opt.report = 0

-- ── Classified but not enabled ──────────────────────────────────────────────
-- What counts as part of a "word" for w, *, and CTRL-N. This is per-language and
-- belongs in after/ftplugin/ — CSS wants "-" included so `background-color` is
-- one word; Lisp wants "-" too; C does not. Setting it globally makes `dw`
-- behave differently than you expect in half your files.
-- opt.iskeyword:append("-")
--
-- Characters valid in a filename for `gf`. The default already handles most
-- cases; on Windows the "\\" handling here is why paths with backslashes work.
-- opt.isfname:append("@-@")
--
-- Printable characters. Almost never needs touching in a UTF-8 world.
-- opt.isprint = "@,161-255"
--
-- How `$` behaves in visual mode, and whether selections include the last char.
-- "inclusive" changes the meaning of every visual operator — do not.
-- (default: "inclusive")
-- opt.selection = "exclusive"
--
-- Make shifted arrow keys start a *select* mode selection (Windows-style,
-- typing replaces the selection) instead of visual mode. This is the
-- "behave mswin" path. It makes Neovim feel like Notepad and breaks muscle
-- memory for every Vim tutorial you will ever read.
-- opt.selectmode = "mouse,key"
-- opt.keymodel = "startsel,stopsel"

-- ═════════════════════════════════════════════════════════════════════════════
-- 24  TIMING AND RESPONSIVENESS
-- ═════════════════════════════════════════════════════════════════════════════

-- [global] Idle milliseconds before CursorHold fires and the swap file would be
-- written. This is the knob behind "how fast does LSP highlight the symbol under
-- my cursor" and "how fast does gitsigns blame appear". 200ms feels instant
-- without hammering the LSP on every cursor twitch. (default: 4000)
opt.updatetime = 200

-- [global] Milliseconds to wait for a mapped sequence to complete. This is how
-- long which-key waits before showing its popup, and how long you have to finish
-- a multi-key mapping. 300 is the sweet spot: long enough to type `<leader>ff`
-- deliberately, short enough that the which-key panel feels responsive rather
-- than laggy. (default: 1000)
opt.timeoutlen = 300

-- [global] Wait for a mapped sequence at all. (default: true)
opt.timeout = true

-- [global] Milliseconds to wait for a *key code* (as opposed to a mapping) —
-- notably the escape sequences that arrow keys and <Esc> itself send. Keep this
-- low and separate from 'timeoutlen': it is why pressing <Esc> exits insert mode
-- instantly instead of pausing to check whether you meant <Esc>OA. 10ms is enough
-- for any local terminal. Raise to ~50 over a very laggy ssh link.
-- (default: 50, and ttimeout defaults to true)
opt.ttimeout = true
opt.ttimeoutlen = 10

-- ── Classified but not enabled ──────────────────────────────────────────────
-- Never time out a partially typed mapping — it waits forever for the next key.
-- opt.timeout = false
--
-- Delay before redrawing during macro playback. Legacy; Neovim's renderer makes
-- 'lazyredraw' unnecessary and it can leave the screen stale. See section 37.

-- ═════════════════════════════════════════════════════════════════════════════
-- 25  MOUSE
-- ═════════════════════════════════════════════════════════════════════════════

-- [global] Mouse enabled in all modes. Not a betrayal of the Vim way — it is
-- genuinely the fastest way to resize a split, click a diagnostic in a float, or
-- drag-select in a picker. "a" = all modes. (default: "nvi")
opt.mouse = "a"

-- [global] Right-click EXTENDS the selection (classic X11 behaviour) instead of
-- opening a popup menu. Faster, and avoids a context menu appearing when you
-- meant to adjust a selection. Use "popup_setpos" if you want a menu.
-- (default: "popup_setpos")
opt.mousemodel = "extend"

-- ── Classified but not enabled ──────────────────────────────────────────────
-- Disable the mouse entirely, so a stray trackpad brush cannot move the cursor.
-- opt.mouse = ""
--
-- Right-click context menu, positioned at the click. Requires a 'menu' to be
-- defined or you get an empty box.
-- opt.mousemodel = "popup_setpos"
--
-- Hide the mouse pointer while typing. GUI clients only.
-- opt.mousehide = true
--
-- Milliseconds between clicks to count as a double-click. (default: 500)
-- opt.mousetime = 300

-- ═════════════════════════════════════════════════════════════════════════════
-- 26  DIFF
-- ═════════════════════════════════════════════════════════════════════════════

-- [global] How `:diffthis`, `:diffsplit` and diffview.nvim compute and show diffs.
--   internal              use Neovim's built-in diff library, not external diff(1)
--   filler                show filler lines where the other side has content
--   closeoff              turn off diff mode automatically when one window closes
--   algorithm:histogram   the best of the four algorithms for real source code;
--                         it handles moved blocks far better than the default
--                         "myers", at negligible cost
--   linematch:60          THE quality-of-life flag. Within a changed hunk of up
--                         to 60 lines, re-align the two sides line by line so you
--                         see "this word changed" instead of "these 8 lines were
--                         replaced by these 8 lines". Transforms diff readability.
--   indent-heuristic      shift hunk boundaries to land on sensible indentation,
--                         so a diff starts at `def foo` rather than mid-body
--   vertical              side-by-side rather than stacked
-- (default: "internal,filler,closeoff")
opt.diffopt = {
  "internal",
  "filler",
  "closeoff",
  "algorithm:histogram",
  "linematch:60",
  "indent-heuristic",
  "vertical",
}

-- ── Classified but not enabled ──────────────────────────────────────────────
-- Ignore whitespace-only changes. Useful for reviewing a reindent, dangerous as a
-- default in Python where whitespace is syntax.
-- opt.diffopt:append("iwhite")         -- ignore amount of whitespace
-- opt.diffopt:append("iblank")         -- ignore blank-line changes
-- opt.diffopt:append("icase")          -- ignore case
-- opt.diffopt:append("context:5")      -- lines of unchanged context (default 6)
-- opt.diffopt:append("hiddenoff")      -- stop diffing a hidden buffer
-- opt.diffopt:append("followwrap")     -- keep each window's own 'wrap'
--
-- Use an external diff program instead of the internal library.
-- opt.diffexpr = "MyDiff()"
--
-- Character-level highlighting inside a changed line is controlled by the
-- DiffText highlight group, not an option. See lua/plugins/colorscheme.lua.

-- ═════════════════════════════════════════════════════════════════════════════
-- 27  GREP AND EXTERNAL TOOLS
-- ═════════════════════════════════════════════════════════════════════════════

-- [global] Replace grep(1) with ripgrep for `:grep`. Orders of magnitude faster,
-- respects .gitignore, and works identically on Windows and Linux — which plain
-- grep does not, since Windows has no grep at all.
--   --vimgrep    output file:line:col:text, the format Neovim parses
--   --smart-case same behaviour as 'ignorecase' + 'smartcase' above
--   --hidden     search dotfiles (this repo is one)
--   --glob=!.git do not search inside .git, which is all noise
-- The fuzzy picker (<leader>sg) uses ripgrep too; this makes the built-in
-- `:grep` and quickfix workflow just as good.
if vim.fn.executable("rg") == 1 then
  opt.grepprg = "rg --vimgrep --smart-case --hidden --glob=!.git"
  opt.grepformat = "%f:%l:%c:%m"
else
  -- Fallback so :grep still works on a machine without ripgrep. On Windows
  -- without rg there is no usable grep, hence the warning in :checkhealth.
  opt.grepprg = "grep -nH --exclude-dir=.git -r $* ."
  opt.grepformat = "%f:%l:%m"
end

-- ── Classified but not enabled ──────────────────────────────────────────────
-- Build command for `:make`, and how to parse its output. Per-project, so it
-- belongs in after/ftplugin/ or a project-local .nvim.lua (see section 34) rather
-- than here. Examples:
-- opt.makeprg = "cargo build --message-format=short"
-- opt.errorformat = "%f:%l:%c: %t%*[^:]: %m"
--
-- Keyword-lookup program for `K`. The LSP replaces this with hover documentation
-- (see the LspAttach keymaps), which is strictly better where an LSP exists.
-- opt.keywordprg = ":Man"
--
-- Where `:!` output and temp files go. Defaults are correct on both platforms.
-- opt.shelltemp = true

-- ═════════════════════════════════════════════════════════════════════════════
-- 28  SHELL (PER OPERATING SYSTEM)
-- ═════════════════════════════════════════════════════════════════════════════
-- This block is the single most important piece of Windows-specific
-- configuration in the whole config, and the reason `:terminal`, lazygit and
-- `:!` behave sanely on both platforms.
--
-- On Windows, Neovim defaults 'shell' to cmd.exe, which cannot handle the quoting
-- that plugins generate, produces CRLF in captured output, and has no useful
-- utilities. Pointing it at PowerShell fixes all three but requires the four
-- quoting options below to be cleared, because PowerShell's escaping rules are
-- nothing like sh's.
if is_win then
  -- Prefer PowerShell 7 (`pwsh`, cross-platform, actively developed) and fall
  -- back to the Windows-bundled PowerShell 5.1 (`powershell`) if it is absent.
  local shell = vim.fn.executable("pwsh") == 1 and "pwsh" or "powershell"
  opt.shell = shell

  -- Flags used when Neovim runs a *command* through the shell — system(), `:!`,
  -- `:grep`, `:make`. Note this does NOT apply to a bare `:terminal`, which
  -- launches the shell interactively with no flags; that is why an interactive
  -- PowerShell still works despite -NonInteractive here.
  --   -NoLogo          skip the copyright banner
  --   -NoProfile       do not source the user's PowerShell profile. Makes shell
  --                    calls fast and, more importantly, reproducible — a profile
  --                    that prints anything would corrupt captured output.
  --   -NonInteractive  never prompt; fail instead of hanging invisibly
  --   -ExecutionPolicy RemoteSigned  the standard permissive-but-not-reckless
  --                    policy, so plugin helper scripts can run
  --   The trailing -Command forces UTF-8 on both streams. Without it, any tool
  --   output containing a non-ASCII character (every Nerd Font glyph, every
  --   ripgrep box-drawing character) arrives as mojibake.
  opt.shellcmdflag = table.concat({
    "-NoLogo",
    "-NoProfile",
    "-NonInteractive",
    "-ExecutionPolicy",
    "RemoteSigned",
    "-Command",
    "[Console]::InputEncoding=[Console]::OutputEncoding=[System.Text.Encoding]::UTF8;",
    "$PSDefaultParameterValues['Out-File:Encoding']='utf8';",
  }, " ")

  -- How Neovim redirects a command's output into a temp file. `%s` is substituted
  -- with the filename. `2>&1` merges stderr so error messages reach the quickfix
  -- list instead of vanishing, and `exit $LastExitCode` propagates the real exit
  -- status — without it every failed command looks successful to Neovim.
  --
  -- Keep exactly ONE `%` in each of these two strings. Neovim validates them and
  -- rejects anything with a second percent sign (E1577) — which rules out the
  -- common PowerShell idiom `| %{ "$_" }` (where `%` is an alias for ForEach-Object).
  -- Out-File and Tee-Object already stringify their input, so it is not needed.
  opt.shellredir = "2>&1 | Out-File -Encoding UTF8 %s; exit $LastExitCode"

  -- Same, but also echoes to the screen (used by `:make`).
  opt.shellpipe = "2>&1 | Tee-Object -FilePath %s -Encoding utf8; exit $LastExitCode"

  -- These two MUST be empty for PowerShell. Neovim would otherwise wrap the whole
  -- command in sh-style quotes, which PowerShell passes through as literal
  -- characters — producing the classic "the term '"git status"' is not
  -- recognized" error. Clearing them is not optional.
  opt.shellquote = ""
  opt.shellxquote = ""

  -- 'shellslash' stays OFF (the default) on Windows. Turning it on makes Neovim
  -- emit forward slashes in paths, which PowerShell tolerates but several
  -- plugins' path comparisons do not — it is a known source of subtle
  -- mason/lazy breakage. Leave it alone.
  -- opt.shellslash = true
end

-- On Linux and macOS the defaults are already correct: 'shell' comes from $SHELL,
-- and sh-compatible quoting is what Neovim assumes. Nothing to do. Explicitly
-- setting shell = "/bin/bash" here would actually be a downgrade, because it
-- ignores the user's actual login shell.
--
-- ── Classified but not enabled ──────────────────────────────────────────────
-- Force a specific POSIX shell, e.g. if $SHELL is fish (whose syntax breaks
-- plugins that generate sh commands). This is the one good reason to set it:
-- if is_mac or vim.fn.has("unix") == 1 then
--   opt.shell = "/bin/sh"   -- or "/usr/bin/env bash"
-- end

-- ═════════════════════════════════════════════════════════════════════════════
-- 29  PERFORMANCE AND LARGE FILES
-- ═════════════════════════════════════════════════════════════════════════════

-- [buffer] Stop applying syntax highlighting past column 300. A minified JS
-- bundle or a base64 blob on one 200,000-character line will otherwise pin a CPU
-- core. Anything past column 300 is not being read by a human anyway.
-- (default: 3000)
opt.synmaxcol = 300

-- [global] Milliseconds allowed for a redraw or a syntax match before Neovim
-- gives up and leaves the screen partly unhighlighted rather than freezing.
-- (default: 2000)
opt.redrawtime = 1500

-- [global] Kilobytes of memory one regex match may use before erroring out.
-- Raised because treesitter-adjacent patterns and some linters legitimately need
-- more, and the failure mode (E363) is a confusing error rather than slowness.
-- (default: 1000)
opt.maxmempattern = 5000

-- ── Classified but not enabled ──────────────────────────────────────────────
-- Force a regex engine: 0 = auto, 1 = old backtracking NFA, 2 = new automaton.
-- Occasionally 1 fixes a pathologically slow syntax file. Auto is right.
-- opt.regexpengine = 1
--
-- Skip redraws during macros and scripts. Legacy Vim optimisation; in Neovim it
-- mainly causes stale screens and is being phased out. See section 37.
-- opt.lazyredraw = true
--
-- Large-file handling is done properly by snacks.nvim's `bigfile` module, which
-- disables treesitter, LSP, folding and syntax for files over ~1.5 MB. See
-- lua/plugins/ui.lua. That is strictly better than any option here.

-- ═════════════════════════════════════════════════════════════════════════════
-- 30  SESSIONS AND VIEWS
-- ═════════════════════════════════════════════════════════════════════════════

-- [global] What `:mksession` stores. persistence.nvim drives sessions
-- (<leader>qs to restore), and this controls what gets captured.
--   buffers, curdir, tabpages, winsize, winpos, terminal  → the useful set
-- Deliberately excluded:
--   options  — restoring options from a session means a stale session silently
--              overrides changes you made in this file. This is the classic
--              "why is my new config not taking effect" trap.
--   folds    — treesitter recomputes folds correctly on load; saved folds go stale
--   blank    — no point saving empty windows
-- (default: "blank,buffers,curdir,folds,help,tabpages,winsize,terminal")
opt.sessionoptions = { "buffers", "curdir", "tabpages", "winsize", "help", "terminal" }

-- ── Classified but not enabled ──────────────────────────────────────────────
-- What `:mkview` saves per file — used to restore cursor position and manual
-- folds. autocmds.lua restores the cursor position with a small autocmd instead,
-- which avoids the stale-view problems that come with saved options.
-- opt.viewoptions = { "cursor", "folds" }
-- opt.viewdir = vim.fn.stdpath("state") .. "/view"

-- ═════════════════════════════════════════════════════════════════════════════
-- 31  TERMINAL BUFFERS
-- ═════════════════════════════════════════════════════════════════════════════

-- [global] Lines of scrollback kept in a `:terminal` buffer. Enough to scroll
-- back through a long test run or build log. Costs memory per terminal.
-- (default: 10000)
opt.scrollback = 10000

-- ── Classified but not enabled ──────────────────────────────────────────────
-- Terminal-buffer-local settings (no numbers, no sign column, insert on enter)
-- are applied by an autocmd in autocmds.lua, because they must be per-buffer.
--
-- Colours inside :terminal come from g.terminal_color_0 .. 15, set from the
-- palette in lua/plugins/colorscheme.lua so a shell inside Neovim matches WezTerm.

-- ═════════════════════════════════════════════════════════════════════════════
-- 32  COMMAND LINE AND WILDMENU
-- ═════════════════════════════════════════════════════════════════════════════

-- [global] Show a menu of completions when you press <Tab> on the command line.
-- (default: true)
opt.wildmenu = true

-- [global] How <Tab> completion progresses.
--   longest:full  first <Tab> completes the longest unambiguous prefix and opens
--                 the menu; you keep typing to narrow it
--   full          subsequent <Tab>s cycle through candidates
-- This ordering means <Tab> never jumps to an arbitrary first match.
-- (default: "full")
opt.wildmode = "longest:full,full"

-- [global] Command-line completion presentation.
--   pum    use the same floating popup menu as insert-mode completion, instead
--          of the flat single-line list
--   fuzzy  fuzzy-match, so `:e cfgopt<Tab>` can find `config/options.lua`
-- (default: "pum,tagfile")
opt.wildoptions = "pum,fuzzy"

-- [global] Ignore case when completing filenames on the command line — correct on
-- Windows and macOS, where the filesystem is case-insensitive anyway.
-- (default: false)
opt.wildignorecase = true

-- [global] Never offer these in file completion. Keeps build output and vendored
-- dependencies out of `:e` and `:find`.
opt.wildignore = {
  "*.o", "*.obj", "*.dll", "*.exe", "*.so", "*.dylib", "*.pyc", "*.pyo",
  "*/node_modules/*", "*/target/*", "*/__pycache__/*", "*/.git/*",
  "*/.venv/*", "*/venv/*", "*/dist/*", "*/build/*", "*/.mypy_cache/*",
  "*/.pytest_cache/*", "*/.ruff_cache/*",
}

-- [global] Characters that separate items when completing a `:set foo=` value.
-- Fixes completion of comma-separated option values. (default: " \t\r\n")
opt.wildcharm = vim.fn.char2nr("\t")

-- [global] Command and search history length. (default: 10000 in Neovim)
opt.history = 10000

-- ── Classified but not enabled ──────────────────────────────────────────────
-- Cycle candidates without the intermediate longest-prefix step.
-- opt.wildmode = "full"
--
-- List candidates without a menu, old-Vim style.
-- opt.wildmenu = false

-- ═════════════════════════════════════════════════════════════════════════════
-- 33  MESSAGES AND PROMPTS
-- ═════════════════════════════════════════════════════════════════════════════

-- [global] 'shortmess' suppresses categories of message. Each flag removes one
-- kind of noise. Appending rather than assigning keeps Neovim's sensible
-- defaults ("filnxtToOF") and adds to them.
--   W  "written" after every :w — you know, you just pressed it
--   I  the intro/splash screen (the dashboard replaces it anyway)
--   c  "match 1 of 3" completion messages, which fight with the popup menu
--   C  messages while scanning for completions
--   s  "search hit BOTTOM, continuing at TOP"
--   S  the "[1/17]" search count — lualine shows this more legibly
opt.shortmess:append("WIcCsS")

-- [global] Where and how long messages appear. Neovim 0.11+.
--   hit-enter  keep the traditional "Press ENTER" behaviour for long messages
--   history:500  keep 500 messages in `:messages`
-- noice.nvim intercepts most messages anyway; this governs what it does not.
-- (default: "hit-enter,history:500")
opt.messagesopt = "hit-enter,history:500"

-- ── Classified but not enabled ──────────────────────────────────────────────
-- Suppress "written" but keep everything else: opt.shortmess = "filnxtToOFW"
--
-- The nuclear option — suppress every optional message. You will lose useful
-- warnings along with the noise.
-- opt.shortmess = "aoOtTWIcCsSF"
--
-- Route messages to a floating window with a timeout instead of the command line.
-- Neovim 0.11+. noice.nvim already does this, better.
-- opt.messagesopt = "wait:1500,history:500"
--
-- Visual bell instead of an audible beep. Neovim is silent by default; this
-- exists to make it *flash* instead, which most people find worse.
-- opt.visualbell = true
-- opt.errorbells = false
-- opt.belloff = "all"   -- (default: "all" in Neovim — already silent)

-- ═════════════════════════════════════════════════════════════════════════════
-- 34  SECURITY: EXRC AND SECURE
-- ═════════════════════════════════════════════════════════════════════════════

-- [global] 'exrc' lets a project directory contain its own `.nvim.lua`,
-- `.nvimrc` or `.exrc` that Neovim sources on startup. Extremely useful — a Rust
-- project can set its own `makeprg`, a monorepo can pin an LSP root — and it is
-- ARBITRARY CODE EXECUTION triggered by `cd`ing into a directory.
--
-- Left OFF. Neovim 0.9+ does mitigate this: it shows the file's contents and asks
-- for explicit approval, remembering the decision by file hash. That makes it
-- defensible if you only ever open your own repositories. It is still off here
-- because "clone a repo, open Neovim, get prompted to run its code" is a
-- meaningful supply-chain surface for very little gain.
--
-- To enable, uncomment both lines. 'secure' additionally forbids the riskiest
-- commands (`:!`, shell escapes, writes) in such files.
-- (default: false)
-- opt.exrc = true
-- opt.secure = true

-- ═════════════════════════════════════════════════════════════════════════════
-- 35  DIAGNOSTICS
-- ═════════════════════════════════════════════════════════════════════════════
-- Not options, but this is where a reader looks for "how do the squiggles work",
-- so it lives with them. Configured via vim.diagnostic.config().
local palette = require("config.palette")

vim.diagnostic.config({
  -- Inline virtual text at end of line. Set to `false` if you find it noisy and
  -- prefer the virtual_lines block below, or hovering with <leader>cd.
  virtual_text = {
    spacing = 4,
    source = "if_many", -- name the source only when two linters disagree
    prefix = "●",
    -- Only show hints and above inline; keep the line readable.
    severity = { min = vim.diagnostic.severity.HINT },
  },

  -- Neovim 0.11+ can render a diagnostic as a multi-line block *below* the code,
  -- with an arrow pointing at the exact column. Far better than virtual_text for
  -- long Rust type errors. Off by default because having both at once is
  -- redundant; <leader>ud toggles between them (see keymaps.lua).
  virtual_lines = false,

  -- Sign-column glyphs and their colours, per severity.
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = palette.icons.diagnostics.Error,
      [vim.diagnostic.severity.WARN] = palette.icons.diagnostics.Warn,
      [vim.diagnostic.severity.INFO] = palette.icons.diagnostics.Info,
      [vim.diagnostic.severity.HINT] = palette.icons.diagnostics.Hint,
    },
  },

  -- Underline the offending range.
  underline = true,

  -- Do NOT re-render diagnostics on every keystroke in insert mode. Squiggles
  -- appearing under a half-typed identifier are pure noise; they arrive the
  -- moment you leave insert mode.
  update_in_insert = false,

  -- Show the highest severity first in the sign column when several overlap.
  severity_sort = true,

  -- The float shown by <leader>cd / CursorHold.
  float = {
    border = palette.border,
    source = "if_many",
    header = "",
    prefix = "",
  },
})

-- ═════════════════════════════════════════════════════════════════════════════
-- 36  FILETYPE DETECTION ADDITIONS
-- ═════════════════════════════════════════════════════════════════════════════
-- Neovim's built-in detection is good but does not know about every convention.
-- Adding a filetype here is what makes treesitter, the LSP and the ftplugin all
-- kick in for a file Neovim would otherwise treat as plain text.
vim.filetype.add({
  extension = {
    -- Common config formats Neovim maps to a generic type by default.
    mdx = "markdown.mdx",
    -- Environment files, so a plugin or ftplugin can special-case them.
    env = "sh",
  },
  filename = {
    [".env"] = "sh",
    ["Dockerfile.dev"] = "dockerfile",
    ["requirements.in"] = "requirements",
    [".prettierrc"] = "json",
    [".babelrc"] = "json",
  },
  pattern = {
    -- .env.local, .env.production, ...
    ["%.env%.[%w_.-]+"] = "sh",
    -- requirements-dev.txt and friends
    ["requirements.*%.txt"] = "requirements",
    -- Any dotfile ending in rc that looks like JSON
    [".*%.tsbuildinfo"] = "json",
  },
})

-- ═════════════════════════════════════════════════════════════════════════════
-- 37  DELIBERATELY NOT SET: LEGACY, VIM-ONLY, AND HARMFUL OPTIONS
-- ═════════════════════════════════════════════════════════════════════════════
-- Completing the classification. Everything below is a real option name you will
-- see in old vimrc files, blog posts and Stack Overflow answers. None of it
-- belongs in a modern Neovim config, and knowing *why* saves you from copying it
-- in later.
--
-- ── Removed from Neovim entirely; setting these is an error ──────────────────
--   'compatible'   Vi-compatibility mode. Neovim is always 'nocompatible'.
--                  `set nocompatible` at the top of a vimrc is pure cargo cult.
--   'ttyfast'      always on.
--   'esckeys'      always on.
--   'cryptmethod'  file encryption was removed. Use age/gpg outside the editor.
--   'key'          ditto.
--   'antialias', 'macatsui', 'bioskey', 'conskey', 'restorescreen',
--   'shelltype', 'swapsync', 'textauto', 'textmode', 'toolbar', 'ttybuiltin',
--   'ttyscroll', 'ttymouse', 'weirdinvert', 'highlight', 'opendevice',
--   'osfiletype', 'printdevice' and the rest of the 'print*' family,
--   'gtl'/'gtt', 'maxcombine', 'imactivatekey'
--                  all gone. Mentioned so you recognise them as dead when you
--                  find them in a 2012 dotfiles repo.
--
-- ── Still exist, but actively harmful ───────────────────────────────────────
--   'paste'        the classic "fix my paste" option. It disables mappings,
--                  abbreviations and autoindent wholesale, which breaks plugins
--                  in confusing ways, and it is COMPLETELY UNNECESSARY: Neovim
--                  supports bracketed paste natively, so a terminal paste already
--                  arrives verbatim. Never set this. Its existence is the reason
--                  so many old configs have a `set pastetoggle` line.
--   'pastetoggle'  removed in Neovim for the same reason.
--   'lazyredraw'   skips redraws during macros. In Neovim this mostly produces a
--                  stale screen and is deprecated in practice.
--   'insertmode'   makes Neovim start in insert mode and behave like a modeless
--                  editor. Breaks essentially everything.
--   'revins'       reverse insert. Types backwards. Almost certainly not what
--                  you want.
--   'edcompatible' ed-compatible :substitute flag toggling. A trap.
--   'remap'        disabling recursive mappings globally breaks any plugin that
--                  relies on them. Use `noremap` per mapping instead — which is
--                  what `vim.keymap.set` does by default.
--   'more'         pager for long output. Left at its default; noice handles it.
--
-- ── Exist and are fine, but irrelevant to this setup ────────────────────────
--   'langmap', 'keymap', 'langremap', 'langmenu'
--                  for typing in a non-Latin keyboard layout while keeping Vim
--                  commands on their Latin positions. Relevant if you use a
--                  Cyrillic or Greek layout; not configured here.
--   'rightleft', 'rightleftcmd', 'aleph', 'hkmap', 'hkmapp', 'delcombine',
--   'arabic', 'arabicshape', 'termbidi'
--                  right-to-left and bidirectional text support (Hebrew, Arabic).
--   'imdisable', 'iminsert', 'imsearch', 'imcmdline', 'imstatusfunc',
--   'imactivatefunc'
--                  input-method integration for CJK composition.
--   'balloonexpr', 'balloondelay', 'ballooneval', 'balloonevalterm'
--                  hover tooltips. Superseded by LSP hover (K) and floats.
--   'guitablabel', 'guitabtooltip', 'guiheadroom', 'guipty', 'guiligatures'
--                  GUI-client-only. bufferline.nvim owns the tabline here.
--   'winaltkeys', 'termencoding', 'printfont' and the 'print*' family
--                  Windows-GUI and hardcopy printing. Print a file from the
--                  terminal instead.
--   'debug', 'verbose', 'verbosefile'
--                  diagnostics for Neovim itself. Set temporarily when hunting a
--                  bug: `:set verbose=9 verbosefile=/tmp/nvim.log`, or start with
--                  `nvim -V9/tmp/nvim.log`. Not something to leave on.
--   'cpoptions'    a bag of ~40 single-letter Vi-compatibility quirks. Neovim's
--                  default ("aABceFs") is correct. Changing individual flags is a
--                  reliable way to break plugins that assume the default.
--   'opfunc', 'operatorfunc'
--                  set transiently by plugins implementing custom operators.
--   'eventignore'  suppress autocommands globally. Occasionally needed around a
--                  bulk operation; scope it with `vim.o.eventignore` in a
--                  pcall-protected block rather than setting it here.
--                  Neovim 0.11+ adds 'eventignorewin' for a per-window version.
--   'tabclose'     what to focus after `:tabclose`. Default is fine.
--
-- ═════════════════════════════════════════════════════════════════════════════
-- END. `:verbose set <option>?` tells you which file last set any of these —
-- start there when something behaves unexpectedly.
-- ═════════════════════════════════════════════════════════════════════════════

-- Silence an unused-variable warning for the platform predicates that are only
-- read inside the `is_win` branch. They are kept in scope because local.lua and
-- future sections routinely need them.
local _ = { is_mac, is_wsl }
