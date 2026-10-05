--- ~/.config/nvim/lua/plugins/colorscheme.lua
---
--- "Adrian": Tokyonight's engine, the Adrian greens' palette. See the design
--- rules at the top of lua/config/palette.lua — green owns structure, warm
--- earth owns data, chrome stays quiet.
---
--- Two overrides do the work:
---   on_colors     — swaps Tokyonight's *palette entries* for the ones in
---                   lua/config/palette.lua. Everything the theme derives from
---                   those entries (hundreds of plugin groups) follows. Every
---                   blue-family slot is remapped too, so no stray Tokyonight
---                   blue survives in a plugin we never styled by hand.
---   on_highlights — reassigns specific *roles*: which token gets which hue, and
---                   the quiet, Zed-like chrome.
---
--- To retune: edit lua/config/palette.lua, not this file. To find the highlight
--- group behind any character on screen, put the cursor on it and press
--- <leader>ui — that prints the exact group name plus the treesitter capture.

local P = require("config.palette")
local c = P.colors
local s = P.syntax -- one hue per kind of word; see the long note in palette.lua

return {
  {
    "folke/tokyonight.nvim",
    -- `lazy = false` + high priority: the colorscheme must be applied before any
    -- other plugin draws anything, otherwise you get a visible flash of the
    -- default theme on startup.
    lazy = false,
    priority = 1000,

    opts = {
      -- "night" is the darkest of the four Tokyonight variants; every colour it
      -- defines is replaced below anyway.
      style = "night",

      -- Solid background. Ghostty's background is already this exact colour
      -- (`background = #0e0f0d` in ~/.config/ghostty/config, mirrored from
      -- palette.lua), so transparency would gain nothing.
      transparent = false,

      -- Set g:terminal_color_0..15 so a `:terminal` inside Neovim uses the same
      -- ANSI palette as Ghostty (pinned exactly in `config` below).
      terminal_colors = true,

      styles = {
        -- Italics are confined to prose. Toggle the whole policy in
        -- lua/config/palette.lua (M.style.italic_comments).
        comments = { italic = P.style.italic_comments },
        -- Keywords bold rather than italic: they are the green structural
        -- anchors of the file, and bold reinforces that better than a slant.
        keywords = { bold = true, italic = false },
        functions = { italic = false },
        variables = { italic = false },
        -- Sidebars sit on the darker ground (chrome vs content). Floats are
        -- set by hand in on_highlights: a raised surface, like Zed's popovers.
        sidebars = "dark",
        floats = "dark",
      },

      -- Windows treated as "sidebar" and given the darker background.
      sidebars = {
        "qf",
        "help",
        "neo-tree",
        "aerial",
        "neotest-summary",
        "trouble",
        "lazy",
        "mason",
        "notify",
        "spectre_panel",
      },

      -- Off: with a global statusline and cursorline-follows-focus (see
      -- autocmds.lua) you already know where you are, and dimming makes the
      -- reference code in the other split harder to read.
      dim_inactive = false,

      lualine_bold = true,

      --- Swap Tokyonight's palette for ours.
      --- @param colors table the theme's full colour table, mutated in place
      on_colors = function(colors)
        -- Backgrounds
        colors.bg = c.bg
        colors.bg_dark = c.bg_dark
        colors.bg_dark1 = c.bg_dark
        colors.bg_float = c.bg_alt
        colors.bg_popup = c.bg_alt
        colors.bg_sidebar = c.bg_dark
        colors.bg_statusline = c.bg_dark
        colors.bg_highlight = c.bg_hl
        colors.bg_visual = c.bg_visual
        colors.bg_search = c.bg_visual
        colors.black = c.bg_dark

        -- Foregrounds
        colors.fg = c.fg
        colors.fg_dark = c.fg_dark
        colors.fg_float = c.fg
        colors.fg_sidebar = c.fg_dark
        colors.fg_gutter = c.fg_gutter
        colors.comment = c.comment
        colors.dark3 = c.fg_gutter -- inactive / ignored text in plugins
        colors.dark5 = c.comment

        -- Chrome. `border` is every floating window's edge.
        colors.border = c.border
        colors.border_highlight = c.accent_dim

        -- Diagnostics
        colors.error = c.error
        colors.warning = c.warn
        colors.info = c.info
        colors.hint = c.hint

        -- Syntax hues. Tokyonight's `red` is its keyword/emphasis colour, so it
        -- becomes the green accent; `red1` is its error red.
        colors.red = c.accent
        colors.red1 = c.error
        colors.orange = c.orange
        colors.yellow = c.yellow
        colors.green = c.green
        colors.green1 = c.purple -- Tokyonight's member/property colour
        colors.green2 = c.accent_dim
        colors.teal = c.teal
        colors.cyan = c.cyan
        colors.blue = c.blue
        colors.magenta = c.magenta
        colors.magenta2 = c.accent_soft
        colors.purple = c.purple

        -- The blue family: Tokyonight's UI is built on these (search, borders,
        -- which-key, picker, diff, bufferline). Mapped onto greens and the cool
        -- sky so plugin surfaces nobody styled by hand still fit.
        colors.blue0 = c.accent_deep -- selection / search ground
        colors.blue1 = c.accent -- highlighted borders, titles
        colors.blue2 = c.info
        colors.blue5 = c.teal -- operators in Tokyonight; overridden below
        colors.blue6 = c.accent_soft
        colors.blue7 = c.bg_sel

        -- Git
        colors.git = { add = c.git_add, change = c.git_change, delete = c.git_delete, ignore = c.fg_gutter }
        colors.gitSigns = { add = c.git_add, change = c.git_change, delete = c.git_delete }

        colors.terminal_black = c.terminal.bright_black
      end,

      --- Reassign roles.
      --- @param hl table highlight groups, mutated in place
      on_highlights = function(hl)
        -- ── Keywords: the one green in the code ──────────────────────────────
        local kw = { fg = s.keyword, bold = true }
        hl.Statement = kw
        hl.Conditional = kw
        hl.Repeat = kw
        hl.Keyword = kw
        hl.Exception = kw
        hl.Label = kw
        hl["@keyword"] = kw
        hl["@keyword.function"] = kw
        hl["@keyword.return"] = kw
        hl["@keyword.conditional"] = kw
        hl["@keyword.repeat"] = kw
        hl["@keyword.exception"] = kw
        hl["@keyword.operator"] = kw
        hl["@keyword.coroutine"] = kw
        -- Imports are not bold: structurally important, but read once and then
        -- ignored for the rest of the session.
        hl["@keyword.import"] = { fg = s.keyword }
        hl["@keyword.directive"] = { fg = s.keyword }
        hl["@keyword.modifier"] = { fg = s.keyword }
        hl["@keyword.type"] = kw

        -- Operators and punctuation: visible (8.5:1+) but desaturated, so they
        -- separate words without being mistaken for one. Brackets get the
        -- muted rainbow.
        hl.Operator = { fg = s.operator }
        hl["@operator"] = { fg = s.operator }
        hl["@punctuation.bracket"] = { fg = s.punctuation }
        hl["@punctuation.delimiter"] = { fg = s.punctuation }
        hl["@punctuation.special"] = { fg = s.operator }
        hl.Delimiter = { fg = s.punctuation }
        hl.Special = { fg = s.escape }
        hl.PreProc = { fg = s.keyword }
        hl.Include = { fg = s.keyword }

        -- ── Values ───────────────────────────────────────────────────────────
        hl.String = { fg = s.string }
        hl["@string"] = { fg = s.string }
        hl["@character"] = { fg = s.string }
        -- A doc-string is prose, so it follows the comment italics policy and
        -- sits between comment and code in brightness.
        hl["@string.documentation"] = { fg = c.docstring, italic = P.style.italic_comments }
        hl["@string.escape"] = { fg = s.escape, bold = true }
        hl["@string.regexp"] = { fg = s.escape }
        hl["@string.special"] = { fg = s.escape }
        hl["@string.special.url"] = { fg = s.func, underline = true }

        hl.Number = { fg = s.number }
        hl.Float = { fg = s.number }
        hl.Boolean = { fg = s.number, bold = true }
        hl.Constant = { fg = s.number }
        hl["@number"] = { fg = s.number }
        hl["@number.float"] = { fg = s.number }
        hl["@boolean"] = { fg = s.number, bold = true }
        hl["@constant"] = { fg = s.number }
        hl["@constant.builtin"] = { fg = s.number, bold = true }
        hl["@constant.macro"] = { fg = s.number }

        -- Functions in azure: the farthest hue from the lime `fn` before them.
        hl.Function = { fg = s.func }
        hl["@function"] = { fg = s.func }
        hl["@function.call"] = { fg = s.func }
        hl["@function.method"] = { fg = s.func }
        hl["@function.method.call"] = { fg = s.func }
        -- Bold, not italic: a builtin is still a real function.
        hl["@function.builtin"] = { fg = s.func, bold = true, italic = false }
        hl["@function.macro"] = { fg = s.macro, bold = true }
        hl["@constructor"] = { fg = s.type, bold = true }

        -- Types: teal. These are the TREESITTER fallbacks; where a
        -- language server provides semantic tokens (Rust, TypeScript, Python via
        -- basedpyright) the `@lsp.*` groups below split "type" further.
        hl.Type = { fg = s.type }
        hl["@type"] = { fg = s.type }
        hl["@type.builtin"] = { fg = s.type, bold = true, italic = false }
        hl["@type.definition"] = { fg = s.type, bold = true }
        hl["@type.qualifier"] = { fg = s.keyword, bold = true }
        hl["@module"] = { fg = s.namespace }
        hl["@module.builtin"] = { fg = s.namespace }
        hl["@namespace"] = { fg = s.namespace }

        hl["@variable"] = { fg = s.variable }
        -- `self` / `this`: lime like the keywords it nearly is, not bold; the
        -- coral field after its dot is ΔE 25 away.
        hl["@variable.builtin"] = { fg = s.keyword, italic = false }
        hl["@variable.parameter"] = { fg = s.param, italic = false }
        hl["@variable.parameter.builtin"] = { fg = s.param, italic = false }
        hl["@variable.member"] = { fg = s.field }
        hl["@property"] = { fg = s.field }
        hl["@attribute"] = { fg = s.attribute }
        hl["@attribute.builtin"] = { fg = s.attribute }
        hl["@label"] = { fg = s.lifetime }
        hl["@tag"] = { fg = s.keyword }
        hl["@tag.attribute"] = { fg = s.field }
        hl["@tag.delimiter"] = { fg = s.punctuation }

        hl.Comment = { fg = c.comment, italic = P.style.italic_comments }
        hl["@comment"] = { fg = c.comment, italic = P.style.italic_comments }
        hl["@comment.documentation"] = { fg = c.comment, italic = P.style.italic_comments }
        hl.SpecialComment = { fg = c.comment, italic = P.style.italic_comments }
        -- TODO/FIXME/NOTE inside comments: a tinted word, not a filled badge.
        hl["@comment.todo"] = { fg = s.escape, bold = true }
        hl["@comment.note"] = { fg = c.info, bold = true }
        hl["@comment.warning"] = { fg = c.warn, bold = true }
        hl["@comment.error"] = { fg = c.error, bold = true }

        -- ══════════════════════════════════════════════════════════════════
        -- LSP SEMANTIC TOKENS — "marked types", VS Code style
        -- ══════════════════════════════════════════════════════════════════
        -- Treesitter parses the *text*; a language server understands the
        -- *program*. Only the server knows that `Foo` is a trait rather than a
        -- struct, or that this `x` is the declaration and that one is a use. It
        -- reports that as semantic tokens, which Neovim paints as three layers of
        -- highlight group, in ascending priority:
        --
        --   @lsp.type.<kind>            struct, enum, interface, typeAlias, ...
        --   @lsp.mod.<modifier>         declaration, unsafe, async, constant, ...
        --   @lsp.typemod.<kind>.<mod>   the specific combination
        --
        -- Because they are separate extmarks they MERGE: a group that sets only
        -- `bold` keeps the colour from the layer beneath. That is what makes the
        -- modifier rules below work without having to restate every colour.
        --
        -- The kinds mapped here were obtained by dumping the extmarks
        -- rust-analyzer actually produces for a representative Rust file — 47
        -- distinct groups, of which 26 were unstyled by default. Anything not
        -- emitted in practice is omitted rather than guessed at.
        --
        -- These are keyed by ROLE, not by language, so `gopls`, `clangd` and
        -- `vtsls` inherit the same scheme for the kinds they report.

        -- ── Type kinds: the whole point of this section ───────────────────
        hl["@lsp.type.struct"] = { fg = s.type }
        hl["@lsp.type.class"] = { fg = s.type } -- TS/Python/Java equivalent
        hl["@lsp.type.enum"] = { fg = s.enum }
        hl["@lsp.type.interface"] = { fg = s.trait } -- a Rust trait
        hl["@lsp.type.typeAlias"] = { fg = s.type, underline = true }
        hl["@lsp.type.typeParameter"] = { fg = s.generic, bold = true }
        hl["@lsp.type.union"] = { fg = s.number, bold = true, underline = true }
        hl["@lsp.type.builtinType"] = { fg = s.type, bold = true }
        hl["@lsp.type.generic"] = { fg = s.generic }

        -- ── Values ───────────────────────────────────────────────────────
        -- Variants in lemon, against the aqua of the enum before `::`.
        hl["@lsp.type.enumMember"] = { fg = s.variant }
        hl["@lsp.type.const"] = { fg = s.number, bold = true }
        hl["@lsp.type.static"] = { fg = s.number, bold = true }
        hl["@lsp.type.variable"] = { fg = s.variable }
        hl["@lsp.type.parameter"] = { fg = s.param }
        hl["@lsp.type.property"] = { fg = s.field }
        hl["@lsp.type.field"] = { fg = s.field }
        -- basedpyright's own kinds (verified against what it emits for
        -- fastfetch/art.py): `self`/`cls`, modules, None/True/False.
        hl["@lsp.type.selfParameter"] = { fg = s.keyword }
        hl["@lsp.type.clsParameter"] = { fg = s.keyword }
        hl["@lsp.type.module"] = { fg = s.namespace }
        hl["@lsp.type.builtinConstant"] = { fg = s.number, bold = true }

        -- ── Callables ────────────────────────────────────────────────────
        hl["@lsp.type.function"] = { fg = s.func }
        hl["@lsp.type.method"] = { fg = s.func }
        -- Macros get their own orchid, bold, because they generate code — and
        -- `println!("…")` puts one right against a string.
        hl["@lsp.type.macro"] = { fg = s.macro, bold = true }
        hl["@lsp.type.decorator"] = { fg = s.attribute }

        -- ── Keywords ─────────────────────────────────────────────────────
        hl["@lsp.type.keyword"] = { fg = s.keyword, bold = true }
        -- `self` / `Self`. Was italic by default; a keyword is not provisional.
        hl["@lsp.type.selfKeyword"] = { fg = s.keyword, bold = true, italic = false }
        hl["@lsp.type.selfTypeKeyword"] = { fg = s.type, bold = true }

        -- ── Quiet scaffolding ────────────────────────────────────────────
        -- Module paths recede so the type at the end of them stands out:
        -- in `std::collections::HashMap`, only `HashMap` should draw the eye.
        hl["@lsp.type.namespace"] = { fg = s.namespace }
        -- `'a`. An annotation, not a type — muted ochre, quiet.
        hl["@lsp.type.lifetime"] = { fg = s.lifetime, italic = false }
        -- The `#[` and `]` of an attribute, and the attribute body.
        hl["@lsp.type.attributeBracket"] = { fg = s.attribute }
        hl["@lsp.mod.attribute"] = { fg = s.attribute }
        hl["@lsp.typemod.namespace.attribute"] = { fg = s.attribute }
        hl["@lsp.typemod.generic.attribute"] = { fg = s.attribute }
        hl["@lsp.typemod.attributeBracket.attribute"] = { fg = s.attribute }

        -- ── Modifiers: colour-free, so they COMBINE with the kind above ──

        -- THE headline VS Code behaviour: a declaration is bold, a use is not. So
        -- `fn greet` and `struct Person` are visually the definition, while every
        -- later mention of them is plain. Sets no `fg`, so each kind keeps its hue.
        hl["@lsp.mod.declaration"] = { bold = true }
        hl["@lsp.mod.definition"] = { bold = true }

        -- Safety. `unsafe` blocks, unsafe fns and union field reads get an
        -- undercurl in the error colour — the same visual language as a
        -- diagnostic, because that is exactly the weight it deserves in Rust.
        hl["@lsp.mod.unsafe"] = { sp = c.error, undercurl = true }
        hl["@lsp.typemod.keyword.unsafe"] = { fg = c.error, bold = true }
        hl["@lsp.typemod.function.unsafe"] = { sp = c.error, undercurl = true }
        hl["@lsp.typemod.operator.unsafe"] = { sp = c.error, undercurl = true }

        -- Control flow gets the accent even where the server calls it a keyword,
        -- so `match`, `return`, `break`, `?` all read as structure.
        hl["@lsp.typemod.keyword.controlFlow"] = { fg = s.keyword, bold = true }
        hl["@lsp.mod.controlFlow"] = { fg = s.keyword, bold = true }

        -- `async` / `await`: structure, and worth spotting at a glance.
        hl["@lsp.mod.async"] = { fg = s.keyword, bold = true }
        hl["@lsp.typemod.keyword.async"] = { fg = s.keyword, bold = true }
        hl["@lsp.typemod.function.async"] = { fg = s.func, bold = true }

        -- Anything the server considers constant reads as a constant.
        hl["@lsp.mod.constant"] = { fg = s.number }
        hl["@lsp.typemod.keyword.constant"] = { fg = s.keyword, bold = true }
        hl["@lsp.typemod.variable.constant"] = { fg = s.number, bold = true }
        -- basedpyright has no `constant` modifier; it marks module-level
        -- UPPER_CASE names `readonly` (verified on fastfetch/art.py: TAU,
        -- GREENS, ACID). Same role, same colour.
        hl["@lsp.typemod.variable.readonly.python"] = { fg = s.number }

        -- A `mut` binding is underlined. Mutability is the single most
        -- consequential property of a Rust binding and is otherwise invisible
        -- after the declaration line.
        hl["@lsp.typemod.variable.mutable"] = { underline = true }
        hl["@lsp.typemod.selfKeyword.mutable"] = { underline = true }
        -- Only BINDINGS. The bare modifier also lands on every `&mut self`
        -- method call (`.next()`, `.push()`) and on `+=`; screenshotted, half
        -- of a parser function was underlined. Set to {} rather than deleted
        -- so it overrides Tokyonight's default.
        hl["@lsp.mod.mutable"] = {}

        -- Deprecated APIs get struck through, which is the one place a text
        -- decoration is genuinely worth more than a colour.
        hl["@lsp.mod.deprecated"] = { strikethrough = true }

        -- Declared-but-unused, where the server reports it.
        hl["@lsp.mod.unused"] = { fg = c.comment }

        -- Library vs first-party code. Kept deliberately UNSET (empty table) so
        -- standard-library types look identical to your own — distinguishing them
        -- sounds useful and in practice just makes `Vec` and `MyVec` inconsistent.
        -- Uncomment to dim third-party symbols instead:
        -- hl["@lsp.mod.library"] = { fg = s.punctuation }
        hl["@lsp.mod.defaultLibrary"] = {}

        -- Inlay hints are the LSP's inferred types shown inline (on in Rust,
        -- off elsewhere; <leader>uh). Not italic: these are type names, and type names are
        -- never slanted here. No background box either — a box per hint made
        -- every annotated line read as a row of buttons; the dim colour alone
        -- separates them from real code.
        hl.LspInlayHint = { fg = c.inlay, italic = false }

        -- ══════════════════════════════════════════════════════════════════
        -- RAINBOW DELIMITERS
        -- ══════════════════════════════════════════════════════════════════
        -- Nesting depth by colour. Genuinely useful in Rust, where a single line
        -- can hold `Result<Vec<HashMap<String, Box<dyn Error>>>, io::Error>`.
        -- Configured in lua/plugins/treesitter.lua; palette in palette.lua.
        for _, level in ipairs(P.rainbow) do
          hl["RainbowDelimiter" .. level.name] = { fg = level.color }
        end

        -- ══════════════════════════════════════════════════════════════════
        -- CHROME — quiet, Zed-like
        -- ══════════════════════════════════════════════════════════════════
        -- The frame never carries the accent: separators and borders are one
        -- step above the background, the cursor line a half step. The only
        -- green in the chrome is the current line number and the mode label.
        hl.CursorLineNr = { fg = c.accent, bold = true }
        hl.LineNr = { fg = c.fg_gutter }
        hl.LineNrAbove = { fg = c.fg_gutter }
        hl.LineNrBelow = { fg = c.fg_gutter }
        hl.CursorLine = { bg = c.bg_hl }
        hl.CursorColumn = { bg = c.bg_hl }
        -- Kept for the one filetype that still sets 'colorcolumn' (gitcommit's
        -- 50/72 rule); a half step, so it reads as a guide, not a wall.
        hl.ColorColumn = { bg = c.bg_hl }
        hl.Visual = { bg = c.bg_visual }
        hl.VisualNOS = { bg = c.bg_visual }
        hl.MatchParen = { fg = c.accent_soft, bg = c.bg_sel, bold = true }

        -- Search: three distinct states, which most themes conflate.
        --   Search    = every other match: a green wash, text stays readable
        --   CurSearch = the one you are on: solid lime, so `n` is trackable
        --   IncSearch = live preview while typing: solid acid
        hl.Search = { fg = c.fg, bg = c.accent_deep }
        hl.CurSearch = { fg = c.bg, bg = c.accent, bold = true }
        hl.IncSearch = { fg = c.bg, bg = c.accent_soft, bold = true }
        hl.Substitute = { fg = c.bg, bg = c.orange, bold = true }

        -- Floats are a RAISED surface (lighter than the editor), like Zed's
        -- popovers, edged with the quiet border. Titles carry the accent.
        hl.NormalFloat = { fg = c.fg, bg = c.bg_alt }
        hl.FloatBorder = { fg = c.border, bg = c.bg_alt }
        hl.FloatTitle = { fg = c.accent, bg = c.bg_alt, bold = true }
        hl.FloatFooter = { fg = c.comment, bg = c.bg_alt }
        -- The split line: a hairline in `border`, never bold, so a resized
        -- layout never leaves a loud bar standing in the middle of the screen.
        hl.WinSeparator = { fg = c.border, bg = c.bg }
        hl.VertSplit = { fg = c.border, bg = c.bg }

        -- Statusline ground; lualine paints over it, this is what shows before
        -- lualine loads and under `laststatus=3`'s inactive state.
        hl.StatusLine = { fg = c.fg_dark, bg = c.bg_dark }
        hl.StatusLineNC = { fg = c.comment, bg = c.bg_dark }
        hl.TabLine = { fg = c.comment, bg = c.bg_dark }
        hl.TabLineFill = { bg = c.bg_dark }
        hl.TabLineSel = { fg = c.fg, bg = c.bg, bold = true }
        hl.MsgArea = { fg = c.fg_dark, bg = c.bg }
        hl.ModeMsg = { fg = c.accent, bold = true }
        hl.MoreMsg = { fg = c.accent }
        hl.Question = { fg = c.accent }

        -- Completion popup
        hl.Pmenu = { fg = c.fg, bg = c.bg_alt }
        hl.PmenuSel = { fg = c.accent_soft, bg = c.bg_sel, bold = true }
        hl.PmenuSbar = { bg = c.bg_alt }
        hl.PmenuThumb = { bg = c.border }
        hl.PmenuKind = { fg = c.teal, bg = c.bg_alt }
        hl.PmenuExtra = { fg = c.comment, bg = c.bg_alt }
        hl.PmenuMatch = { fg = c.accent, bg = c.bg_alt, bold = true }
        hl.PmenuMatchSel = { fg = c.accent_soft, bg = c.bg_sel, bold = true }

        hl.QuickFixLine = { bg = c.bg_sel, bold = true }
        hl.Directory = { fg = c.accent }
        hl.Title = { fg = c.accent, bold = true }
        hl.NonText = { fg = c.fg_gutter }
        hl.SpecialKey = { fg = c.fg_gutter }
        hl.Whitespace = { fg = c.border }
        hl.EndOfBuffer = { fg = c.bg }
        hl.Folded = { fg = c.fg_dark, bg = c.bg_alt }
        hl.FoldColumn = { fg = c.fg_gutter, bg = c.bg }
        hl.SignColumn = { bg = c.bg }
        hl.WinBar = { fg = c.fg_dark, bg = c.bg }
        hl.WinBarNC = { fg = c.comment, bg = c.bg }
        hl.Conceal = { fg = c.comment }

        -- ── Diagnostics: tinted underlines and quiet virtual text ──────────
        -- Undercurl in the severity colour; the inline message (current line
        -- only, see options.lua §35) on a faint tint of its own colour.
        hl.DiagnosticUnderlineError = { sp = c.error, undercurl = true }
        hl.DiagnosticUnderlineWarn = { sp = c.warn, undercurl = true }
        hl.DiagnosticUnderlineInfo = { sp = c.info, undercurl = true }
        hl.DiagnosticUnderlineHint = { sp = c.hint, undercurl = true }
        hl.DiagnosticVirtualTextError = { fg = c.error, bg = c.tint_error }
        hl.DiagnosticVirtualTextWarn = { fg = c.warn, bg = c.tint_warn }
        hl.DiagnosticVirtualTextInfo = { fg = c.info, bg = c.tint_info }
        hl.DiagnosticVirtualTextHint = { fg = c.hint, bg = c.tint_hint }
        -- Code the server says is unreachable or unused: faded, not struck.
        hl.DiagnosticUnnecessary = { fg = c.comment }

        -- ── Diff, tuned for the linematch:60 option in options.lua ─────────
        -- Backgrounds are deliberately desaturated so DiffText (the *changed
        -- words* inside a changed line) stands out against DiffChange.
        hl.DiffAdd = { bg = "#1f2c19" }
        hl.DiffChange = { bg = "#232619" }
        hl.DiffDelete = { fg = c.git_delete, bg = "#2a1a18" }
        hl.DiffText = { bg = "#3d4220", bold = true }

        -- LSP document highlight — the three states of "other uses of this symbol".
        hl.LspReferenceText = { bg = c.bg_sel }
        hl.LspReferenceRead = { bg = c.bg_sel }
        hl.LspReferenceWrite = { bg = c.bg_sel, underline = true }
        hl.LspSignatureActiveParameter = { fg = c.accent, bold = true }
        -- Codelens ("3 references"): annotation-quiet, below comments.
        hl.LspCodeLens = { fg = c.fg_gutter }
        hl.LspCodeLensSeparator = { fg = c.border }

        -- ── Plugin surfaces ────────────────────────────────────────────────
        -- snacks.indent: plain guides barely there; the *active scope* guide in
        -- deep green. You see the block you are in, not fifty vertical lines.
        hl.SnacksIndent = { fg = c.indent }
        hl.SnacksIndentScope = { fg = c.accent_deep }

        -- Picker: same raised surface as every other float.
        hl.SnacksPicker = { fg = c.fg, bg = c.bg_alt }
        hl.SnacksPickerBorder = { fg = c.border, bg = c.bg_alt }
        hl.SnacksPickerMatch = { fg = c.accent, bold = true }
        hl.SnacksPickerTitle = { fg = c.accent, bg = c.bg_alt, bold = true }
        hl.SnacksPickerDir = { fg = c.comment }
        hl.SnacksPickerPrompt = { fg = c.accent }
        hl.SnacksPickerListCursorLine = { bg = c.bg_sel }
        hl.SnacksPickerInputBorder = { fg = c.border, bg = c.bg_alt }

        -- Notifications, coloured by level: a tinted title and border on the
        -- shared raised surface.
        for _, lv in ipairs({ { "Info", c.info }, { "Warn", c.warn }, { "Error", c.error }, { "Debug", c.comment } }) do
          hl["SnacksNotifier" .. lv[1]] = { fg = c.fg, bg = c.bg_alt }
          hl["SnacksNotifierBorder" .. lv[1]] = { fg = c.border, bg = c.bg_alt }
          hl["SnacksNotifierTitle" .. lv[1]] = { fg = lv[2], bg = c.bg_alt, bold = true }
          hl["SnacksNotifierIcon" .. lv[1]] = { fg = lv[2], bg = c.bg_alt }
        end

        -- Dashboard
        hl.SnacksDashboardHeader = { fg = c.accent }
        hl.SnacksDashboardIcon = { fg = c.accent_dim }
        hl.SnacksDashboardDesc = { fg = c.fg }
        hl.SnacksDashboardKey = { fg = c.accent, bold = true }
        hl.SnacksDashboardFooter = { fg = c.comment, italic = true }
        hl.SnacksDashboardTitle = { fg = c.fg_dark, bold = true }
        hl.SnacksDashboardFile = { fg = c.fg }
        hl.SnacksDashboardDir = { fg = c.comment }
        hl.SnacksDashboardSpecial = { fg = c.accent_dim }

        -- which-key
        hl.WhichKey = { fg = c.accent, bold = true }
        hl.WhichKeyGroup = { fg = c.teal }
        hl.WhichKeyDesc = { fg = c.fg }
        hl.WhichKeySeparator = { fg = c.comment }
        hl.WhichKeyNormal = { bg = c.bg_alt }
        hl.WhichKeyBorder = { fg = c.border, bg = c.bg_alt }
        hl.WhichKeyTitle = { fg = c.accent, bg = c.bg_alt, bold = true }

        -- noice: the `:` palette and the bottom search line.
        hl.NoiceCmdlinePopup = { fg = c.fg, bg = c.bg_alt }
        hl.NoiceCmdlinePopupBorder = { fg = c.border, bg = c.bg_alt }
        hl.NoiceCmdlinePopupTitle = { fg = c.accent, bg = c.bg_alt, bold = true }
        hl.NoiceCmdlinePopupTitleCmdline = { fg = c.accent, bg = c.bg_alt, bold = true }
        hl.NoiceCmdlinePopupBorderCmdline = { fg = c.border, bg = c.bg_alt }
        hl.NoiceCmdlineIcon = { fg = c.accent }
        hl.NoiceCmdlinePopupBorderSearch = { fg = c.border, bg = c.bg_alt }
        hl.NoiceCmdlineIconSearch = { fg = c.accent_soft }

        -- Treesitter context (the sticky function signature at the top): the
        -- raised surface, so it reads as pinned rather than as code.
        hl.TreesitterContext = { bg = c.bg_alt }
        hl.TreesitterContextLineNumber = { fg = c.fg_gutter, bg = c.bg_alt }
        hl.TreesitterContextBottom = { sp = c.border, underline = true }

        -- neo-tree: names in plain text, only folder icons in green.
        hl.NeoTreeNormal = { fg = c.fg_dark, bg = c.bg_dark }
        hl.NeoTreeNormalNC = { fg = c.fg_dark, bg = c.bg_dark }
        hl.NeoTreeWinSeparator = { fg = c.bg_dark, bg = c.bg_dark }
        hl.NeoTreeDirectoryName = { fg = c.fg }
        hl.NeoTreeDirectoryIcon = { fg = c.accent_dim }
        hl.NeoTreeFileName = { fg = c.fg_dark }
        hl.NeoTreeRootName = { fg = c.accent, bold = true }
        hl.NeoTreeGitModified = { fg = c.git_change }
        hl.NeoTreeGitAdded = { fg = c.git_add }
        hl.NeoTreeGitUntracked = { fg = c.git_add }
        hl.NeoTreeGitDeleted = { fg = c.git_delete }
        hl.NeoTreeGitConflict = { fg = c.error, bold = true }
        hl.NeoTreeGitIgnored = { fg = c.fg_gutter }
        hl.NeoTreeDotfile = { fg = c.comment }
        hl.NeoTreeIndentMarker = { fg = c.border }
        hl.NeoTreeExpander = { fg = c.fg_gutter }
        hl.NeoTreeCursorLine = { bg = c.bg_sel }
        hl.NeoTreeTabActive = { fg = c.fg, bg = c.bg_dark, bold = true }
        hl.NeoTreeTabInactive = { fg = c.comment, bg = c.bg_dark }
        hl.NeoTreeTabSeparatorActive = { fg = c.bg_dark, bg = c.bg_dark }
        hl.NeoTreeTabSeparatorInactive = { fg = c.bg_dark, bg = c.bg_dark }
        hl.NeoTreeFloatBorder = { fg = c.border, bg = c.bg_alt }
        hl.NeoTreeTitleBar = { fg = c.bg, bg = c.accent }

        -- blink.cmp
        hl.BlinkCmpMenu = { fg = c.fg, bg = c.bg_alt }
        hl.BlinkCmpMenuBorder = { fg = c.border, bg = c.bg_alt }
        hl.BlinkCmpMenuSelection = { bg = c.bg_sel, bold = true }
        hl.BlinkCmpLabelMatch = { fg = c.accent, bold = true }
        hl.BlinkCmpLabelDetail = { fg = c.comment }
        hl.BlinkCmpLabelDescription = { fg = c.comment }
        hl.BlinkCmpKind = { fg = c.teal }
        hl.BlinkCmpSource = { fg = c.fg_gutter }
        hl.BlinkCmpDoc = { fg = c.fg, bg = c.bg_alt }
        hl.BlinkCmpDocBorder = { fg = c.border, bg = c.bg_alt }
        hl.BlinkCmpDocSeparator = { fg = c.border, bg = c.bg_alt }
        hl.BlinkCmpSignatureHelp = { fg = c.fg, bg = c.bg_alt }
        hl.BlinkCmpSignatureHelpBorder = { fg = c.border, bg = c.bg_alt }
        hl.BlinkCmpGhostText = { fg = c.fg_gutter }

        -- gitsigns: bars in the gutter, and blame that must stay quiet — it
        -- sits on the line you are editing.
        hl.GitSignsAdd = { fg = c.git_add }
        hl.GitSignsChange = { fg = c.git_change }
        hl.GitSignsDelete = { fg = c.git_delete }
        hl.GitSignsUntracked = { fg = c.accent_deep }
        hl.GitSignsCurrentLineBlame = { fg = c.fg_gutter, italic = true }

        -- Mini/lazy/mason panels use NormalFloat already; their accents:
        hl.LazyH1 = { fg = c.bg, bg = c.accent, bold = true }
        hl.LazyButtonActive = { fg = c.bg, bg = c.accent, bold = true }
        hl.MasonHeader = { fg = c.bg, bg = c.accent, bold = true }
        hl.MasonHighlight = { fg = c.accent }
        hl.MasonHighlightBlockBold = { fg = c.bg, bg = c.accent, bold = true }
      end,
    },

    config = function(_, opts)
      require("tokyonight").setup(opts)
      vim.cmd.colorscheme("tokyonight")

      -- Explicitly set the 16 ANSI colours for `:terminal` buffers from our
      -- palette, so a shell (or lazygit) running inside Neovim matches Ghostty
      -- exactly. `terminal_colors = true` above gets most of the way there; this
      -- pins the exact values.
      local t = c.terminal
      local ansi = {
        t.black,
        t.red,
        t.green,
        t.yellow,
        t.blue,
        t.magenta,
        t.cyan,
        t.white,
        t.bright_black,
        t.bright_red,
        t.bright_green,
        t.bright_yellow,
        t.bright_blue,
        t.bright_magenta,
        t.bright_cyan,
        t.bright_white,
      }
      for i, colour in ipairs(ansi) do
        vim.g["terminal_color_" .. (i - 1)] = colour
      end
    end,
  },
}
