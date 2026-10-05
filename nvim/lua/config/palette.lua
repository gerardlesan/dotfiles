--- ~/.config/nvim/lua/config/palette.lua
---
--- SINGLE SOURCE OF TRUTH FOR COLOR.
---
--- The theme is "Adrian": the greens of the Adrian render in this repo
--- (adrian_upscayl_2x_ultramix-balanced-4x.png) — the same greens the fastfetch
--- logo, the starship prompt and Ghostty use — on Tokyonight's engine. Three
--- design rules keep it readable rather than just green:
---
---   1. Green owns STRUCTURE — keywords, the cursor line number, matched
---      brackets, the active indent scope, search. That is what makes the
---      editor feel green at a glance.
---   2. Code is TOKENISED FOR CONTRAST, not themed. Every kind of word gets
---      its own hue (M.syntax), chosen so the kinds that sit next to each other
---      are the furthest apart — see the measurements there. Green is kept
---      for keywords only, which is enough to make the editor feel green.
---   3. Chrome is QUIET, like Zed: borders, separators and the statusline sit a
---      step or two above the background and carry no accent. Colour is spent on
---      code, not on the frame around it.
---
--- Every foreground was checked for WCAG contrast against `bg` (#0e0f0d),
--- computed, not eyeballed: code tokens 7.7–15.5:1, comments 5.9:1, line numbers
--- ~2.6:1 (decoration, deliberately below text).
---
--- `error` is the Petrova red the fastfetch art uses, far from every syntax hue,
--- so a diagnostic never reads as code.
---
--- Ghostty mirrors these hex values in ~/.config/ghostty/config (no extension —
--- Ghostty ignores any other filename). Ghostty cannot `require` from Neovim's
--- runtimepath, so that file repeats the numbers with a pointer back here. If you
--- retune the palette, change both.
---
--- Everything downstream (statusline, borders, syntax, git signs) derives from
--- this table.

local M = {}

---@class Palette
M.colors = {
  -- ── Backgrounds, darkest to lightest ───────────────────────────────────────
  -- Luminance-matched (WCAG relative luminance, computed) to the warm-violet set
  -- this config started from, with the hue moved to a faint green. Was, in
  -- order: #15131a #1a1820 #1f1c27 #2b2333 #2f2739 #3a2b42.
  -- 2026-10: taken darker twice (#161a15 -> #131612 -> #0e0f0d) and the green
  -- tint halved (OKLab chroma 0.92 -> 0.44): with every token coloured, a green
  -- ground made the lime keywords read green-on-green. Now a near-black with a
  -- trace of green; the surfaces keep their steps above it.
  bg_dark = "#0a0b09", -- statusline, sidebars, picker, tab bar
  bg = "#0e0f0d", -- the normal editing background
  bg_alt = "#151714", -- raised surfaces: floats, popup menu, sticky context
  bg_hl = "#181b17", -- CursorLine: a whisper, not a stripe
  bg_sel = "#20251e", -- popup-menu selection, other uses of the symbol
  bg_visual = "#283322", -- Visual mode selection: the one clearly green fill

  -- ── Foregrounds ────────────────────────────────────────────────────────────
  -- Neutral green-greys, the fastfetch values colour (201;214;196) nudged up.
  fg = "#e3e9dc", -- normal text and variables, 14.7:1
  fg_dark = "#a5b29c", -- statusline text, punctuation, 7.9:1
  fg_gutter = "#4a5945", -- line numbers, 2.6:1 — present, never competing
  comment = "#7f9578", -- comments, 5.6:1; italic, so prose reads as prose
  border = "#272d24", -- window separators, float borders: there, but quiet
  docstring = "#9cb093", -- doc-strings: prose, between comment and code
  -- Inlay hints (Rust's inferred types): a COOL grey, so a hint is never read
  -- as code (all saturated) or as a comment (green-grey, italic). 5.5:1.
  inlay = "#7e8ea6",
  indent = "#1b1f19", -- plain indent guides: barely there

  -- ── The green accent family — Adrian's greens ──────────────────────────────
  accent = "#8fd404", -- lime: keywords, mode, cursor line number, matches
  accent_soft = "#c4ef3a", -- acid: the brightest green, for the current match
  accent_dim = "#6fa83a", -- leaf: operators, inactive emphasis
  accent_deep = "#3f6b1c", -- deep: active indent scope, scrollbar thumb

  -- ── Tokyonight's hue slots ─────────────────────────────────────────────────
  -- For PLUGIN surfaces (devicons, statusline segments, markdown headings).
  -- Code tokens come from M.syntax below; these just reuse its values so the
  -- two never drift. Tokyonight's names describe its own roles, not the hue:
  -- `green` is its strings slot, which is why it holds the string colour.
  orange = "#ff9a3c",
  yellow = "#ffd166",
  green = "#efd28c",
  teal = "#3fd8c2",
  cyan = "#9ceee4",
  blue = "#6fb0ff",
  magenta = "#d98cf5",
  purple = "#b8a8ff",

  -- ── Diagnostics ────────────────────────────────────────────────────────────
  error = "#ff5f52", -- Petrova red
  warn = "#e3d23a", -- the fastfetch "60–90%" yellow
  info = "#7cc7e0",
  hint = "#9fc87a",
  ok = "#8fd404",

  -- ── Git ────────────────────────────────────────────────────────────────────
  git_add = "#6fae2a",
  git_change = "#d9b44a",
  git_delete = "#e05a4f",

  -- ── Tints: a severity colour at ~12% over `bg`, for the inline message ────
  tint_error = "#261613",
  tint_warn = "#222113",
  tint_info = "#121e25",
  tint_hint = "#172114",

  -- ── Terminal ANSI 0-15, for :terminal buffers ──────────────────────────────
  -- Mirrors the Ghostty palette (`palette = 0..15` in ~/.config/ghostty/config)
  -- so a shell inside Neovim looks like a shell outside it. Only black/white
  -- follow the Adrian tint; the hues stay recognisable ANSI hues, because
  -- programs (git, ls, compilers) mean something specific by "red".
  terminal = {
    black = "#242d22",
    bright_black = "#3e4b3b",
    red = "#f7768e",
    bright_red = "#ff8fa3",
    green = "#9ece6a",
    bright_green = "#b9f27c",
    yellow = "#e0af68",
    bright_yellow = "#ffc777",
    blue = "#7aa2f7",
    bright_blue = "#95b6ff",
    magenta = "#bb9af7",
    bright_magenta = "#cdaaff",
    cyan = "#7dcfff",
    bright_cyan = "#a4dcff",
    white = "#e3e9dc", -- = fg
    bright_white = "#f4f7f0",
  },
}

--- ═══════════════════════════════════════════════════════════════════════════
--- TYPOGRAPHY
--- ═══════════════════════════════════════════════════════════════════════════
M.style = {
  --- Italics are used for PROSE ONLY — comments and doc comments.
  ---
  --- Code tokens (types, builtins, parameters, `self`) are deliberately never
  --- italic. Two reasons: a slanted monospace face loses the vertical stems that
  --- keep `l`, `1` and `|` apart at terminal sizes, and an italic *type* reads as
  --- "somehow provisional" when the whole point is that it is a concrete, named
  --- thing. Types are distinguished by HUE and WEIGHT here instead — see M.syntax.
  ---
  --- Set to false to remove italics from the config entirely.
  italic_comments = true,
}

--- ═══════════════════════════════════════════════════════════════════════════
--- SYNTAX — one hue per kind of word, tuned for "tokenised" reading
--- ═══════════════════════════════════════════════════════════════════════════
--- The goal: you can tell what every word IS without reading it. Two numbers
--- were optimised, both computed (not eyeballed) against `bg` #0e0f0d:
---
---   CONTRAST  WCAG ratio of each token on the background — all ≥ 7.3:1, most
---             ≥ 9 (the old set had functions at 7.7 and fields barely apart
---             from plain text).
---   DISTANCE  perceptual distance (OKLab ΔE×100) between kinds that sit NEXT
---             TO EACH OTHER in real code. Measured pairs, worst first:
---               field/number 12   string/number 13   string/variant 11 (rare)
---               param/variable 12  namespace/type 13  keyword/string 14
---               type/function 16  keyword/type 16  self/field 25
---               variable/field 25  keyword/function 30  macro/string 26
---             The old set had number=variant (ΔE 0) and field≈variable.
---
--- The hues go round the wheel so neighbours in code are far apart on it:
---
---   lime     keyword            `fn` `let` `match` `self`      (the green)
---   azure    function / method  `parse_line` `.next()`
---   orchid   macro              `println!` `format!`
---   teal     type               `Reading` `String` `f64`
---   aqua     enum               `Source` `Option`
---   lemon    enum variant       `Sensor` `Some` `None`
---   lavender trait / interface  `Summary` `Display`
---   gold     generic, lifetime  `T` `'a`
---   orange   number / constant  `42.5` `true` `LIMIT`
---   sand     string             `"store"`
---   coral    field / property   `self.label`
---   pink     parameter          `fn f(line: &str)` and its uses
---   white    variable           plain locals
---   grey     namespace          `std::fmt::` recedes so the type pops
---
--- WEIGHT and UNDERLINE carry the rest (see colorscheme.lua): bold marks a
--- declaration and the keywords; underline marks a `mut` binding and a type
--- alias; `unsafe` gets an undercurl.
M.syntax = {
  variable = "#e3e9dc", -- 14.7:1
  keyword = "#a6e03a", -- 11.6:1
  func = "#6fb0ff", -- 8.1:1
  macro = "#d98cf5", -- 7.8:1
  type = "#3fd8c2", -- 10.3:1
  enum = "#9ceee4", -- 13.7:1
  variant = "#fff45c", -- 15.3:1
  trait = "#b8a8ff", -- 8.8:1
  generic = "#ffd166", -- 12.7:1
  lifetime = "#c9a86a", -- 8.1:1, quieter than a type: an annotation
  number = "#ff9a3c", -- 8.6:1; also booleans and named constants
  string = "#efd28c", -- 13.1:1
  escape = "#c4ef3a", -- `\n`, `{}` inside strings: acid, against the sand
  field = "#ff7a85", -- 7.3:1
  param = "#f0bbda", -- 11.1:1
  namespace = "#9fac9f", -- 7.7:1
  operator = "#93bdb0", -- 8.8:1: visible, but not a word
  punctuation = "#a9b5a2", -- 8.5:1: `,` `;` `.`
  attribute = "#8ea39e", -- 6.9:1: `#[derive]`, `@decorator` — scaffolding
}

--- Nesting colours for rainbow-delimiters, OUTERMOST FIRST.
---
--- MUTED on purpose (chroma roughly halved, contrast ~6–7:1). Brackets touch
--- every other token; at full saturation a lime `{` read as a keyword and an
--- azure `(` as part of the function name. These say "depth" without
--- competing with the words. Seven levels, then it wraps.
---
--- The `name` is the suffix of the highlight group (RainbowDelimiterSage, ...);
--- lua/plugins/treesitter.lua builds rainbow-delimiters' `highlight` list from
--- this table in order, so the names are free — keep them honest to the hue.
M.rainbow = {
  { name = "Sage", color = "#a3bf86" },
  { name = "Wheat", color = "#cdb88a" },
  { name = "Clay", color = "#c99a86" },
  { name = "Sea", color = "#86bdb2" },
  { name = "Steel", color = "#8fa9c9" },
  { name = "Heather", color = "#ad9fcb" },
  { name = "Rose", color = "#c69ab4" },
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
    Warn = "\u{f071} ", -- nf-fa-exclamation_triangle
    Info = "\u{f05a} ", -- nf-fa-info_circle
    Hint = "\u{f0eb} ", -- nf-fa-lightbulb_o
  },

  git = {
    added = "\u{f067} ", -- nf-fa-plus
    modified = "\u{f040} ", -- nf-fa-pencil
    removed = "\u{f068} ", -- nf-fa-minus
  },

  -- Used by the statusline's file-state segment.
  file = {
    modified = "\u{25cf}", -- ● U+25CF BLACK CIRCLE — ordinary Unicode, works in
    -- any font, so "unsaved" is never invisible even
    -- without a Nerd Font.
    readonly = "\u{f023} ", -- nf-fa-lock
    unnamed = "[No Name]",
    newfile = "\u{f016} ", -- nf-fa-file_o
  },

  -- Used by which-key, the picker, the dashboard and the statusline.
  ui = {
    search = "\u{f002} ", -- nf-fa-search
    folder = "\u{f07b} ", -- nf-fa-folder
    branch = "\u{e725} ", -- nf-dev-git_branch
    lsp = "\u{f013} ", -- nf-fa-gear
    test = "\u{f0c3} ", -- nf-fa-flask
    debug = "\u{f188} ", -- nf-fa-bug
    terminal = "\u{f120} ", -- nf-fa-terminal
    package = "\u{f1b2} ", -- nf-fa-cube
    chevron = "\u{f054} ", -- nf-fa-chevron_right
    dot = "\u{f111} ", -- nf-fa-circle
    lightning = "\u{f0e7} ", -- nf-fa-bolt
  },
}

return M
