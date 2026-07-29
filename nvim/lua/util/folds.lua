--- ~/.config/nvim/lua/util/folds.lua
---
--- PRETTIER FOLD TEXT.
---
--- Neovim's default closed fold looks like:
---     +--- 14 lines: fn greet(&self) -> String {------------------------
---
--- Setting `foldtext = ""` (Neovim 0.10+) improves that a lot — it shows the real
--- first line with its normal syntax highlighting — but loses the line count,
--- which is the one piece of information a closed fold most needs to convey.
---
--- This gives you both:
---     fn greet(&self) -> String {          ⋯ 14 lines
--- with the code portion highlighted by treesitter exactly as it would be if the
--- fold were open, and the annotation in the comment colour.
---
--- Enabled via `folds.custom_foldtext` in lua/plugins/treesitter.lua. Set that to
--- false to fall back to Neovim's built-in highlighted foldtext.

local M = {}

--- Longest line we will syntax-highlight character-by-character. Beyond this the
--- per-character capture lookups stop being free, and a minified or generated line
--- is not worth the effort — it falls back to a single plain chunk.
local MAX_HIGHLIGHT_WIDTH = 300

--- Build the fold's display text as a list of `{ text, highlight_group }` chunks.
--- Neovim renders such a list directly, which is what allows per-token colouring
--- inside a fold — a plain string could only have one highlight.
---@return table[]|string
function M.foldtext()
  local fold_start = vim.v.foldstart
  local fold_end = vim.v.foldend
  local line = vim.api.nvim_buf_get_lines(0, fold_start - 1, fold_start, false)[1] or ""
  local count = fold_end - fold_start + 1

  local chunks = {}

  if #line <= MAX_HIGHLIGHT_WIDTH then
    -- Ask treesitter what capture applies at each byte, then merge runs of
    -- identical captures into one chunk. `get_captures_at_pos` returns captures
    -- ordered least- to most-specific, so the LAST one is the winner — the same
    -- rule the real highlighter uses.
    --
    -- pcall because a buffer with no parser, or one mid-reparse, will throw; a
    -- fold must never be able to raise an error while drawing.
    local ok = pcall(function()
      local prev_hl, acc = nil, ""
      for i = 1, #line do
        local captures = vim.treesitter.get_captures_at_pos(0, fold_start - 1, i - 1)
        local hl = #captures > 0 and ("@" .. captures[#captures].capture) or "Folded"
        if hl ~= prev_hl then
          if #acc > 0 then
            chunks[#chunks + 1] = { acc, prev_hl }
          end
          acc, prev_hl = line:sub(i, i), hl
        else
          -- Multi-byte characters accumulate here intact: every byte of a given
          -- character resolves to the same capture, so a run is never split
          -- mid-character.
          acc = acc .. line:sub(i, i)
        end
      end
      if #acc > 0 then
        chunks[#chunks + 1] = { acc, prev_hl }
      end
    end)

    if not ok then
      chunks = {}
    end
  end

  -- Fallback: the whole line in the Folded highlight.
  if #chunks == 0 then
    chunks = { { line, "Folded" } }
  end

  -- The annotation. U+22EF (⋯) is ordinary Unicode, not a Nerd Font glyph, so
  -- this renders correctly even without a patched font.
  chunks[#chunks + 1] = { "  \u{22ef} ", "Folded" }
  chunks[#chunks + 1] = { ("%d lines"):format(count), "Comment" }

  return chunks
end

--- Install this as the global 'foldtext'.
function M.enable()
  -- 'foldtext' takes a vimscript expression, so route it through v:lua.
  vim.o.foldtext = "v:lua.require'util.folds'.foldtext()"
end

--- Revert to Neovim's built-in highlighted foldtext.
function M.disable()
  vim.o.foldtext = ""
end

return M
