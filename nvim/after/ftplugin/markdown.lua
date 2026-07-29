--- after/ftplugin/markdown.lua
---
--- Markdown is prose, so almost every "correct for code" setting from
--- lua/config/options.lua is wrong here. This is the one filetype where wrapping,
--- spell checking and concealment are all wanted.
---
--- Rendering (headings as coloured bars, tables, checkboxes) comes from
--- render-markdown.nvim; inline images from snacks.image. Both are configured in
--- lua/plugins/ui.lua and lua/plugins/snacks.lua.

-- ── Wrapping: on, and cursor motion follows the visual line ─────────────────
vim.wo.wrap = true
vim.wo.linebreak = true -- break at word boundaries, not mid-word
vim.wo.breakindent = true -- wrapped list items stay indented under their bullet

-- Hard-wrap at 80 as you type. Unlike code, prose genuinely wants this: it keeps
-- diffs line-oriented, so a one-word edit does not reflow the whole paragraph.
vim.bo.textwidth = 80
-- Re-add "t" (auto-wrap text), which the global 'formatoptions' removes and the
-- autocmd in lua/config/autocmds.lua deliberately leaves alone for markdown.
vim.opt_local.formatoptions:append("t")
-- "n" makes wrapped numbered-list items line up under the text, not the number.
vim.opt_local.formatoptions:append("n")
-- Do not auto-wrap a line that was already long before you touched it.
vim.opt_local.formatoptions:append("l")

vim.wo.colorcolumn = "" -- pointless with hard wrapping at 80

-- ── Spell check: on ────────────────────────────────────────────────────────
-- This is the filetype where spell checking earns its keep. `]s` / `[s` to move
-- between misspellings, `z=` for suggestions, `zg` to add a word.
vim.opt_local.spell = true
vim.opt_local.spelllang = { "en_us" }

-- ── Concealment: hide markup for readability ───────────────────────────────
-- 2 = hide `**bold**` markers, link URLs, etc. The global setting is 0 because
-- concealing *code* hides what is really in the file; in prose it is the point.
-- 'concealcursor' is empty (from options.lua) so the raw markup reappears on the
-- line you are editing.
vim.wo.conceallevel = 2

-- Indent by 2 for nested lists, matching prettier's markdown output.
vim.bo.expandtab = true
vim.bo.shiftwidth = 2
vim.bo.tabstop = 2
vim.bo.softtabstop = 2

-- ── Motion: j/k should move by screen line in wrapped prose ────────────────
-- The global mappings in keymaps.lua already do this via `v:count == 0 ? 'gj'`,
-- so nothing extra is needed here. Noted so you do not add a duplicate.

-- ── Filetype-local keymaps ─────────────────────────────────────────────────
local function map(mode, keys, rhs, desc)
  vim.keymap.set(mode, keys, rhs, { buffer = 0, desc = "Markdown: " .. desc })
end

-- Toggle a checkbox on the current line: `- [ ]` <-> `- [x]`. The single most
-- useful markdown binding if you keep task lists.
map("n", "<localleader>x", function()
  local line = vim.api.nvim_get_current_line()
  local new
  if line:match("^%s*[-*+]%s+%[ %]") then
    new = line:gsub("%[ %]", "[x]", 1)
  elseif line:match("^%s*[-*+]%s+%[[xX]%]") then
    new = line:gsub("%[[xX]%]", "[ ]", 1)
  else
    -- Not a checkbox yet: turn a plain list item into one.
    new = line:gsub("^(%s*[-*+]%s+)", "%1[ ] ", 1)
  end
  vim.api.nvim_set_current_line(new)
end, "Toggle checkbox")

-- Follow a markdown link under the cursor (relative file, or a URL in the browser).
map("n", "<localleader>o", function()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1
  -- Find a [text](target) span containing the cursor.
  local pos = 1
  while true do
    local s, e, target = line:find("%[[^%]]*%]%(([^)]+)%)", pos)
    if not s then
      break
    end
    if col >= s and col <= e then
      if target:match("^https?://") then
        vim.ui.open(target)
      else
        -- Resolve relative to the current file's directory.
        local path = vim.fn.expand("%:p:h") .. "/" .. target:gsub("#.*$", "")
        vim.cmd.edit(vim.fn.fnamemodify(path, ":p"))
      end
      return
    end
    pos = e + 1
  end
  vim.notify("No markdown link under cursor", vim.log.levels.WARN)
end, "Open link under cursor")

-- Wrap the visual selection in bold / italic / code.
map("x", "<localleader>b", 'c**<C-r>"**<Esc>', "Bold selection")
map("x", "<localleader>i", 'c*<C-r>"*<Esc>', "Italic selection")
map("x", "<localleader>c", 'c`<C-r>"`<Esc>', "Code selection")

-- Reflow the current paragraph to 'textwidth'. `gqip` also works; this is shorter.
map("n", "<localleader>q", "gqip", "Reflow paragraph")
