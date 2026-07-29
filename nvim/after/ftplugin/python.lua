--- after/ftplugin/python.lua
---
--- PEP 8 defaults, aligned with what ruff and black actually enforce, so the
--- editor and the formatter agree and saving never reflows what you just typed.

-- 4 spaces. Non-negotiable in Python: PEP 8 mandates it and every formatter
-- assumes it.
vim.bo.expandtab = true
vim.bo.shiftwidth = 4
vim.bo.tabstop = 4
vim.bo.softtabstop = 4

-- 88 columns, matching black and the `lineLength` in after/ftplugin's sibling
-- after/lsp/ruff.lua. The guide is at 89 so the marker sits just past the limit
-- rather than on the last legal column.
vim.wo.colorcolumn = "89"

-- Do NOT hard-wrap code at 88 — the formatter decides where to break lines, and
-- 'textwidth' would insert newlines mid-expression as you type. Length is
-- enforced by the guide above and by ruff, not by the editor.
vim.bo.textwidth = 0

-- Python's treesitter indent queries handle `if`/`def` bodies well but get
-- continuation lines and hanging indents wrong more often than the bundled
-- vim indent script. lua/plugins/treesitter.lua deliberately skips setting
-- 'indentexpr' for python; this documents why you see different behaviour here.
--   :verbose set indentexpr?   to confirm which is in effect

-- `gf` on an import should find the module.
vim.bo.suffixesadd = ".py"

-- Treat a leading `#` as a comment leader that continues, but never let
-- 'formatoptions' auto-wrap code.
vim.opt_local.formatoptions:remove("t")

-- ── Filetype-local keymaps, under <localleader> (backslash) ─────────────────
local function map(keys, rhs, desc)
  vim.keymap.set("n", keys, rhs, { buffer = 0, desc = "Python: " .. desc })
end

-- Run the current file. Uses the project's venv interpreter if venv-selector or
-- the fallback resolver in lua/plugins/lang/python.lua found one, since that
-- exports $VIRTUAL_ENV.
map("<localleader>r", function()
  local venv = os.getenv("VIRTUAL_ENV")
  local python = "python"
  if venv then
    for _, rel in ipairs({ "/bin/python", "/Scripts/python.exe" }) do
      if vim.fn.executable(venv .. rel) == 1 then
        python = venv .. rel
        break
      end
    end
  end
  -- Save first, then run in a floating terminal so output does not disturb the
  -- window layout.
  vim.cmd("silent! update")
  Snacks.terminal({ python, vim.fn.expand("%:p") }, { interactive = true })
end, "Run this file")

-- Open a REPL with the project interpreter.
map("<localleader>i", function()
  local venv = os.getenv("VIRTUAL_ENV")
  local python = "python"
  if venv then
    for _, rel in ipairs({ "/bin/python", "/Scripts/python.exe" }) do
      if vim.fn.executable(venv .. rel) == 1 then
        python = venv .. rel
        break
      end
    end
  end
  Snacks.terminal({ python }, { interactive = true })
end, "Open a Python REPL")

-- Insert a breakpoint on the line above. `breakpoint()` is the 3.7+ builtin and
-- respects $PYTHONBREAKPOINT, so it works with pdb, ipdb or a debugger.
map("<localleader>b", function()
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local indent = vim.fn.indent(line)
  vim.api.nvim_buf_set_lines(0, line - 1, line - 1, false, {
    string.rep(" ", indent) .. "breakpoint()",
  })
end, "Insert breakpoint() above")
