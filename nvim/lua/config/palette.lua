--- ~/.config/nvim/lua/config/palette.lua
---
--- SINGLE SOURCE OF TRUTH FOR COLOR.
---
--- The theme is Tokyonight "night", warm-shifted and re-accented around a gentle
--- red. Two design rules keep it readable rather than just red:
---
---   1. Red owns the *chrome and control flow* — borders, cursor, mode indicator,
---      keywords, operators. That is what makes the editor feel red at a glance.
---   2. Red does NOT own *data* — strings stay green, numbers stay orange. A
---      config where everything is one hue is pretty in a screenshot and
---      miserable to read code in.
---
--- `error` is deliberately a different, more saturated red than `accent` so a
--- diagnostic never reads as a keyword.
---
--- WezTerm mirrors these hex values in ~/.config/wezterm/wezterm.lua. WezTerm
--- cannot `require` from Neovim's runtimepath, so that file repeats the numbers
--- with a pointer back here. If you retune the palette, change both.
---
--- To dial the red up or down, edit `accent` / `accent_deep` and re-open Neovim.
--- Everything downstream (statusline, borders, syntax, git signs) derives from
--- this table.

local M = {}

---@class Palette
M.colors = {
  -- ── Backgrounds, darkest to lightest ───────────────────────────────────────
  -- Tokyonight's stock background is #1a1b26, which has a distinct blue cast.
  -- These are the same luminance with the blue pulled out and a whisper of red
  -- pushed in, so the red accent sits on a warm ground instead of fighting it.
  bg_dark   = "#15131a", -- sidebars, floating windows, inactive statusline
  bg        = "#1a1820", -- the normal editing background
  bg_alt    = "#1f1c27", -- slightly raised surfaces (popup menu, tabline fill)
  bg_hl     = "#2b2333", -- CursorLine, current-item highlight
  bg_sel    = "#2f2739", -- popup-menu selection
  bg_visual = "#3a2b42", -- Visual mode selection (warm, not blue)

  -- ── Foregrounds ────────────────────────────────────────────────────────────
  fg        = "#cbc6d9", -- normal text (warm-shifted from Tokyonight's #c0caf5)
  fg_dark   = "#a8a2bb", -- statusline / less important text
  fg_gutter = "#3b3548", -- line numbers, indent guides, fold column
  comment   = "#6d6484", -- comments; brighter than stock so they stay legible

  -- ── The red accent family — the "gentle red" lean ──────────────────────────
  accent      = "#f7768e", -- primary accent: keywords, mode, cursor, matchparen
  accent_soft = "#ffa0ae", -- hover/selected text on an accent background
  accent_dim  = "#d4687d", -- de-emphasised accent (inactive tab, blame text)
  accent_deep = "#c53b53", -- window borders, separators, underlines

  -- ── Remaining syntax hues ──────────────────────────────────────────────────
  -- Kept from Tokyonight so that data-carrying tokens stay distinguishable.
  orange  = "#ff9e64", -- numbers, booleans, constants
  yellow  = "#e0af68", -- functions, warnings
  green   = "#9ece6a", -- strings
  teal    = "#5ec8b0", -- regex, escapes
  cyan    = "#7dcfff", -- types, parameters
  blue    = "#7aa2f7", -- links, identifiers (used sparingly now)
  magenta = "#bb9af7", -- special/builtin
  purple  = "#9d7cd8", -- rare emphasis

  -- ── Diagnostics ────────────────────────────────────────────────────────────
  -- `error` is intentionally NOT `accent`. Same family, different saturation and
  -- lightness, so red-as-error and red-as-keyword never get confused.
  error = "#db4b4b",
  warn  = "#e0af68",
  info  = "#0db9d7",
  hint  = "#10b981",
  ok    = "#9ece6a",

  -- ── Git ────────────────────────────────────────────────────────────────────
  git_add    = "#5faf5f",
  git_change = "#d7a65f",
  git_delete = "#c75c6a",

  -- ── Terminal ANSI 0-15, for :terminal buffers ──────────────────────────────
  -- Mirrors the WezTerm palette so a shell inside Neovim looks like a shell
  -- outside it.
  terminal = {
    black   = "#2f2739", bright_black   = "#4b4360",
    red     = "#f7768e", bright_red     = "#ff8fa3",
    green   = "#9ece6a", bright_green   = "#b9f27c",
    yellow  = "#e0af68", bright_yellow  = "#ffc777",
    blue    = "#7aa2f7", bright_blue    = "#95b6ff",
    magenta = "#bb9af7", bright_magenta = "#cdaaff",
    cyan    = "#7dcfff", bright_cyan    = "#a4dcff",
    white   = "#cbc6d9", bright_white   = "#e8e4f0",
  },
}

--- Border style used by every floating window in this config.
--- Kept here so there is exactly one place to change round -> single -> none.
--- Valid: "none" | "single" | "double" | "rounded" | "solid" | "shadow"
M.border = "rounded"

--- Icons shared across the statusline, diagnostics, git signs and pickers.
---
--- WRITTEN AS `\u{...}` LUA ESCAPES ON PURPOSE.
--- These are Nerd Font glyphs living in Unicode's Private Use Area. Pasting them
--- literally makes this file's encoding fragile — editors, git filters, terminal
--- copy-paste and CI pipelines all silently eat PUA characters, and you end up
--- with an empty string that fails at runtime with a baffling error. The escape
--- form is plain ASCII on disk, decodes to the identical glyph at load time, and
--- has the bonus of documenting exactly which codepoint is meant, so you can look
--- it up on nerdfonts.com/cheat-sheet.
---
--- Every codepoint below is from the Font Awesome range, which every Nerd Font
--- patch includes — so these work with JetBrains Mono, Hack, Iosevka, Meslo, etc.
--- If you see boxes (􏿽), your terminal font is not patched. Run `:CheckIcons`
--- (defined in lua/plugins/ui.lua) to render them all and see for yourself.
M.icons = {
  diagnostics = {
    Error = "\u{f057} ", -- nf-fa-times_circle
    Warn  = "\u{f071} ", -- nf-fa-exclamation_triangle
    Info  = "\u{f05a} ", -- nf-fa-info_circle
    Hint  = "\u{f0eb} ", -- nf-fa-lightbulb_o
  },

  git = {
    added    = "\u{f067} ", -- nf-fa-plus
    modified = "\u{f040} ", -- nf-fa-pencil
    removed  = "\u{f068} ", -- nf-fa-minus
  },

  -- Used by the statusline's file-state segment.
  file = {
    modified = "\u{25cf}",  -- ● U+25CF BLACK CIRCLE — ordinary Unicode, works in
                            -- any font, so "unsaved" is never invisible even
                            -- without a Nerd Font.
    readonly = "\u{f023} ", -- nf-fa-lock
    unnamed  = "[No Name]",
    newfile  = "\u{f016} ", -- nf-fa-file_o
  },

  -- Used by which-key, the picker, the dashboard and the statusline.
  ui = {
    search   = "\u{f002} ", -- nf-fa-search
    folder   = "\u{f07b} ", -- nf-fa-folder
    branch   = "\u{e725} ", -- nf-dev-git_branch
    lsp      = "\u{f013} ", -- nf-fa-gear
    test     = "\u{f0c3} ", -- nf-fa-flask
    debug    = "\u{f188} ", -- nf-fa-bug
    terminal = "\u{f120} ", -- nf-fa-terminal
    package  = "\u{f1b2} ", -- nf-fa-cube
    chevron  = "\u{f054} ", -- nf-fa-chevron_right
    dot      = "\u{f111} ", -- nf-fa-circle
    lightning = "\u{f0e7} ", -- nf-fa-bolt
  },
}

return M
