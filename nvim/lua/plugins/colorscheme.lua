--- ~/.config/nvim/lua/plugins/colorscheme.lua
---
--- Tokyonight "night", warm-shifted and re-accented around a gentle red.
---
--- Two overrides do the work:
---   on_colors     — swaps Tokyonight's *palette entries* for the ones in
---                   lua/config/palette.lua. Everything the theme derives from
---                   those entries (and there are hundreds of groups) follows
---                   automatically. This is why the whole editor goes warm from
---                   one table rather than a thousand highlight overrides.
---   on_highlights — reassigns specific *roles*. This is where "red owns control
---                   flow, not data" actually happens.
---
--- To retune: edit lua/config/palette.lua, not this file. To find the highlight
--- group behind any character on screen, put the cursor on it and press
--- <leader>ui — that prints the exact group name plus the treesitter capture.

local P = require("config.palette")
local c = P.colors
local t = P.types -- per-type-kind colours; see the long note in palette.lua

return {
  {
    "folke/tokyonight.nvim",
    -- `lazy = false` + high priority: the colorscheme must be applied before any
    -- other plugin draws anything, otherwise you get a visible flash of the
    -- default theme on startup.
    lazy = false,
    priority = 1000,

    opts = {
      -- "night" is the darkest of the four Tokyonight variants. Others:
      -- "storm" (lighter, bluer), "moon" (mid), "day" (light).
      style = "night",

      -- Let the terminal's own background show through. Off: a solid background
      -- is more legible, and WezTerm's background is already this exact colour so
      -- there is nothing to gain.
      transparent = false,

      -- Set g:terminal_color_0..15 so a `:terminal` inside Neovim uses the same
      -- ANSI palette as WezTerm. Without this, a shell inside Neovim looks
      -- jarringly different from one outside it.
      terminal_colors = true,

      styles = {
        -- Italics are confined to prose. Toggle the whole policy in
        -- lua/config/palette.lua (M.style.italic_comments).
        comments = { italic = P.style.italic_comments },
        -- Keywords bold rather than italic: they are the red structural anchors of
        -- the file, and bold reinforces that better than a slant.
        keywords = { bold = true, italic = false },
        -- Explicitly non-italic. Tokyonight italicises some of these by default,
        -- and `on_highlights` below clears the rest.
        functions = { italic = false },
        variables = { italic = false },
        -- Sidebars and floats sit on the darker background, which visually
        -- separates chrome from content.
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

      -- Dim windows that do not have focus. Off: with a global statusline and
      -- cursorline-follows-focus (see autocmds.lua) you already know where you
      -- are, and dimming makes reference code in the other split harder to read —
      -- which is the whole reason it is open.
      dim_inactive = false,

      -- Bold section labels in the statusline.
      lualine_bold = true,

      --- Swap Tokyonight's palette for ours.
      --- @param colors table the theme's full colour table, mutated in place
      on_colors = function(colors)
        -- Backgrounds
        colors.bg = c.bg
        colors.bg_dark = c.bg_dark
        colors.bg_float = c.bg_dark
        colors.bg_popup = c.bg_alt
        colors.bg_sidebar = c.bg_dark
        colors.bg_statusline = c.bg_dark
        colors.bg_highlight = c.bg_hl
        colors.bg_visual = c.bg_visual
        colors.bg_search = c.accent_deep

        -- Foregrounds
        colors.fg = c.fg
        colors.fg_dark = c.fg_dark
        colors.fg_float = c.fg
        colors.fg_sidebar = c.fg_dark
        colors.fg_gutter = c.fg_gutter
        colors.comment = c.comment

        -- Chrome. `border` is what every floating window's edge uses, so this one
        -- line is most of what makes the UI read as red.
        colors.border = c.accent_deep
        colors.border_highlight = c.accent

        -- Diagnostics. Kept distinct from `accent` on purpose — see palette.lua.
        colors.error = c.error
        colors.warning = c.warn
        colors.info = c.info
        colors.hint = c.hint

        -- Syntax hues. `red` is the accent; `red1` the deeper variant.
        colors.red = c.accent
        colors.red1 = c.accent_deep
        colors.orange = c.orange
        colors.yellow = c.yellow
        colors.green = c.green
        colors.teal = c.teal
        colors.cyan = c.cyan
        colors.blue = c.blue
        colors.magenta = c.magenta
        colors.purple = c.purple

        -- Git
        colors.git = { add = c.git_add, change = c.git_change, delete = c.git_delete }
        colors.gitSigns = { add = c.git_add, change = c.git_change, delete = c.git_delete }

        colors.terminal_black = c.terminal.bright_black
      end,

      --- Reassign roles. THIS is the "gentle red" design decision made concrete.
      --- @param hl table highlight groups, mutated in place
      --- @param colors table the (already-overridden) colour table
      on_highlights = function(hl, colors)
        -- ── Control flow and structure → RED ────────────────────────────────
        -- These are the tokens that describe what the code *does*, and making
        -- them red is what gives the theme its character while leaving the actual
        -- data legible.
        local kw = { fg = c.accent, bold = true }
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
        -- Imports get the dimmer red: structurally important, but you read them
        -- once and then ignore them for the rest of the session.
        hl["@keyword.import"] = { fg = c.accent_dim }
        hl["@keyword.directive"] = { fg = c.accent_dim }

        -- Operators and brackets: dim red. Present enough to trace an expression,
        -- quiet enough not to shout.
        hl.Operator = { fg = c.accent_dim }
        hl["@operator"] = { fg = c.accent_dim }
        hl["@punctuation.bracket"] = { fg = c.accent_dim }
        hl["@punctuation.delimiter"] = { fg = c.fg_dark }
        hl["@punctuation.special"] = { fg = c.accent }

        -- ── Data → keeps its own hue ───────────────────────────────────────
        -- Deliberately NOT red. A file where strings, numbers and identifiers are
        -- all the same colour as the keywords is unreadable.
        hl.String = { fg = c.green }
        hl["@string"] = { fg = c.green }
        -- A doc-string is prose, so it follows the comment italics policy.
        hl["@string.documentation"] = { fg = c.green, italic = P.style.italic_comments }
        hl["@string.escape"] = { fg = c.teal, bold = true }
        hl["@string.regexp"] = { fg = c.teal }

        hl.Number = { fg = c.orange }
        hl.Float = { fg = c.orange }
        hl.Boolean = { fg = c.orange, bold = true }
        hl.Constant = { fg = c.orange }
        hl["@number"] = { fg = c.orange }
        hl["@boolean"] = { fg = c.orange, bold = true }
        hl["@constant"] = { fg = c.orange }
        hl["@constant.builtin"] = { fg = c.orange, bold = true }

        -- Functions in warm yellow rather than Tokyonight's blue. This is the
        -- second half of pulling the blue cast out of the theme.
        hl.Function = { fg = c.yellow }
        hl["@function"] = { fg = c.yellow }
        hl["@function.call"] = { fg = c.yellow }
        hl["@function.method"] = { fg = c.yellow }
        hl["@function.method.call"] = { fg = c.yellow }
        -- Bold, not italic: a builtin is still a real function.
        hl["@function.builtin"] = { fg = c.yellow, bold = true, italic = false }
        hl["@constructor"] = { fg = c.orange, bold = true }

        -- Types stay cool — the one place blue-ish colour earns its keep, because
        -- it distinguishes "what kind of thing" from "what it does".
        --
        -- These are the TREESITTER fallbacks. Where a language server provides
        -- semantic tokens (Rust, TypeScript, Go, C), the far more specific
        -- `@lsp.*` groups in the section below take over and split "type" into
        -- struct / enum / trait / alias / generic.
        hl.Type = { fg = t.struct }
        hl["@type"] = { fg = t.struct }
        hl["@type.builtin"] = { fg = t.struct, bold = true, italic = false }
        hl["@type.definition"] = { fg = t.struct, bold = true }
        hl["@type.qualifier"] = { fg = c.accent, bold = true }
        hl["@module"] = { fg = t.namespace }
        hl["@namespace"] = { fg = t.namespace }

        hl["@variable"] = { fg = c.fg }
        hl["@variable.builtin"] = { fg = c.accent_dim, bold = true, italic = false }
        hl["@variable.parameter"] = { fg = c.fg_dark, italic = false }
        hl["@variable.member"] = { fg = c.teal }
        hl["@property"] = { fg = c.teal }
        hl["@attribute"] = { fg = t.attribute }
        hl["@attribute.builtin"] = { fg = t.attribute }
        hl["@label"] = { fg = t.lifetime }

        hl.Comment = { fg = c.comment, italic = P.style.italic_comments }
        hl["@comment"] = { fg = c.comment, italic = P.style.italic_comments }
        hl["@comment.documentation"] = { fg = c.comment, italic = P.style.italic_comments }

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
        hl["@lsp.type.struct"] = { fg = t.struct }
        hl["@lsp.type.class"] = { fg = t.struct } -- TS/Python/Java equivalent
        hl["@lsp.type.enum"] = { fg = t.enum }
        hl["@lsp.type.interface"] = { fg = t.trait } -- a Rust trait
        hl["@lsp.type.typeAlias"] = { fg = t.alias, underline = true }
        hl["@lsp.type.typeParameter"] = { fg = t.generic, bold = true }
        hl["@lsp.type.union"] = { fg = t.union, bold = true, underline = true }
        hl["@lsp.type.builtinType"] = { fg = t.struct, bold = true }
        hl["@lsp.type.generic"] = { fg = t.generic }

        -- ── Values ───────────────────────────────────────────────────────
        hl["@lsp.type.enumMember"] = { fg = t.enum_member }
        hl["@lsp.type.const"] = { fg = t.constant, bold = true }
        hl["@lsp.type.static"] = { fg = t.constant, bold = true }
        hl["@lsp.type.variable"] = { fg = c.fg }
        hl["@lsp.type.parameter"] = { fg = c.fg_dark }
        hl["@lsp.type.property"] = { fg = c.teal }
        hl["@lsp.type.field"] = { fg = c.teal }

        -- ── Callables ────────────────────────────────────────────────────
        hl["@lsp.type.function"] = { fg = c.yellow }
        hl["@lsp.type.method"] = { fg = c.yellow }
        -- Macros join the function family but bold, because they generate code.
        -- (Default was the same cyan as `struct`, which was actively misleading.)
        hl["@lsp.type.macro"] = { fg = t.macro, bold = true }
        hl["@lsp.type.decorator"] = { fg = t.attribute }

        -- ── Keywords ─────────────────────────────────────────────────────
        hl["@lsp.type.keyword"] = { fg = c.accent, bold = true }
        -- `self` / `Self`. Was italic by default; a keyword is not provisional.
        hl["@lsp.type.selfKeyword"] = { fg = c.accent, bold = true, italic = false }
        hl["@lsp.type.selfTypeKeyword"] = { fg = t.struct, bold = true }

        -- ── Quiet scaffolding ────────────────────────────────────────────
        -- Module paths recede so the type at the end of them stands out:
        -- in `std::collections::HashMap`, only `HashMap` should draw the eye.
        hl["@lsp.type.namespace"] = { fg = t.namespace }
        -- `'a`. An annotation, not a type — kept in the red family but quiet.
        hl["@lsp.type.lifetime"] = { fg = t.lifetime, italic = false }
        -- The `#[` and `]` of an attribute, and the attribute body.
        hl["@lsp.type.attributeBracket"] = { fg = t.attribute }
        hl["@lsp.mod.attribute"] = { fg = t.attribute }
        hl["@lsp.typemod.namespace.attribute"] = { fg = t.attribute }
        hl["@lsp.typemod.generic.attribute"] = { fg = t.attribute }
        hl["@lsp.typemod.attributeBracket.attribute"] = { fg = t.attribute }

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
        hl["@lsp.typemod.keyword.controlFlow"] = { fg = c.accent, bold = true }
        hl["@lsp.mod.controlFlow"] = { fg = c.accent, bold = true }

        -- `async` / `await`: structure, and worth spotting at a glance.
        hl["@lsp.mod.async"] = { fg = c.accent, bold = true }
        hl["@lsp.typemod.keyword.async"] = { fg = c.accent, bold = true }
        hl["@lsp.typemod.function.async"] = { fg = c.yellow, bold = true }

        -- Anything the server considers constant reads as a constant.
        hl["@lsp.mod.constant"] = { fg = t.constant }
        hl["@lsp.typemod.keyword.constant"] = { fg = c.accent, bold = true }
        hl["@lsp.typemod.variable.constant"] = { fg = t.constant, bold = true }

        -- A `mut` binding is underlined. Mutability is the single most
        -- consequential property of a Rust binding and is otherwise invisible
        -- after the declaration line.
        hl["@lsp.typemod.variable.mutable"] = { underline = true }
        hl["@lsp.typemod.selfKeyword.mutable"] = { underline = true }
        hl["@lsp.mod.mutable"] = { underline = true }

        -- Deprecated APIs get struck through, which is the one place a text
        -- decoration is genuinely worth more than a colour.
        hl["@lsp.mod.deprecated"] = { strikethrough = true }

        -- Declared-but-unused, where the server reports it.
        hl["@lsp.mod.unused"] = { fg = c.fg_gutter }

        -- Library vs first-party code. Kept deliberately UNSET (empty table) so
        -- standard-library types look identical to your own — distinguishing them
        -- sounds useful and in practice just makes `Vec` and `MyVec` inconsistent.
        -- Uncomment to dim third-party symbols instead:
        -- hl["@lsp.mod.library"] = { fg = c.fg_dark }
        hl["@lsp.mod.defaultLibrary"] = {}

        -- Inlay hints are the LSP's inferred types shown inline. Not italic:
        -- these are type names, and this config's rule is that type names are
        -- never slanted. Distinguished from real code by colour and background.
        hl.LspInlayHint = { fg = c.comment, bg = c.bg_alt, italic = false }

        -- ══════════════════════════════════════════════════════════════════
        -- RAINBOW DELIMITERS
        -- ══════════════════════════════════════════════════════════════════
        -- Nesting depth by colour. Genuinely useful in Rust, where a single line
        -- can hold `Result<Vec<HashMap<String, Box<dyn Error>>>, io::Error>` and
        -- matching the closing angle brackets by eye is otherwise guesswork.
        -- Configured in lua/plugins/treesitter.lua; palette in palette.lua.
        for _, level in ipairs(P.rainbow) do
          hl["RainbowDelimiter" .. level.name] = { fg = level.color }
        end

        -- ── Chrome: the red frame around everything ────────────────────────
        hl.CursorLineNr = { fg = c.accent, bold = true }
        hl.LineNr = { fg = c.fg_gutter }
        hl.LineNrAbove = { fg = c.fg_gutter }
        hl.LineNrBelow = { fg = c.fg_gutter }
        hl.CursorLine = { bg = c.bg_hl }
        hl.ColorColumn = { bg = c.bg_alt }
        hl.Visual = { bg = c.bg_visual }
        hl.VisualNOS = { bg = c.bg_visual }
        hl.MatchParen = { fg = c.accent, bold = true, underline = true }

        -- Search: three distinct states, which most themes conflate.
        --   Search    = every other match
        --   CurSearch = the one you are on   ← brightest, so `n` is trackable
        --   IncSearch = live preview while typing the pattern
        hl.Search = { fg = c.bg, bg = c.accent_dim }
        hl.CurSearch = { fg = c.bg, bg = c.accent, bold = true }
        hl.IncSearch = { fg = c.bg, bg = c.accent_soft, bold = true }

        -- Floating windows and separators — the most visible red surfaces.
        hl.NormalFloat = { fg = c.fg, bg = c.bg_dark }
        hl.FloatBorder = { fg = c.accent_deep, bg = c.bg_dark }
        hl.FloatTitle = { fg = c.accent, bg = c.bg_dark, bold = true }
        hl.WinSeparator = { fg = c.accent_deep, bold = true }

        -- Completion popup
        hl.Pmenu = { fg = c.fg, bg = c.bg_alt }
        hl.PmenuSel = { fg = c.accent_soft, bg = c.bg_sel, bold = true }
        hl.PmenuSbar = { bg = c.bg_alt }
        hl.PmenuThumb = { bg = c.accent_deep }
        hl.PmenuKind = { fg = c.yellow, bg = c.bg_alt }
        hl.PmenuExtra = { fg = c.comment, bg = c.bg_alt }

        hl.QuickFixLine = { bg = c.bg_sel, bold = true }
        hl.Directory = { fg = c.accent, bold = true }
        hl.Title = { fg = c.accent, bold = true }
        hl.NonText = { fg = c.fg_gutter }
        hl.SpecialKey = { fg = c.fg_gutter }
        hl.Whitespace = { fg = c.fg_gutter }
        hl.EndOfBuffer = { fg = c.bg }
        hl.Folded = { fg = c.accent_dim, bg = c.bg_alt }
        hl.FoldColumn = { fg = c.fg_gutter, bg = c.bg }
        hl.SignColumn = { bg = c.bg }
        hl.WinBar = { fg = c.fg_dark, bg = c.bg }
        hl.WinBarNC = { fg = c.comment, bg = c.bg }

        -- ── Diff, tuned for the linematch:60 option in options.lua ─────────
        -- Backgrounds are deliberately desaturated so DiffText (the *changed
        -- words* inside a changed line) stands out against DiffChange.
        hl.DiffAdd = { bg = "#1f2b1f" }
        hl.DiffChange = { bg = "#252132" }
        hl.DiffDelete = { fg = c.git_delete, bg = "#2b1c20" }
        hl.DiffText = { bg = "#4a2b38", bold = true }

        -- LSP document highlight — the three states of "other uses of this symbol".
        hl.LspReferenceText = { bg = c.bg_sel }
        hl.LspReferenceRead = { bg = c.bg_sel }
        hl.LspReferenceWrite = { bg = c.bg_sel, underline = true }
        hl.LspSignatureActiveParameter = { fg = c.accent, bold = true }
        -- LspInlayHint is set in the semantic-tokens section below, where it sits
        -- with the rest of the type-rendering rules.

        -- ── Plugin surfaces ────────────────────────────────────────────────
        -- snacks.indent: the guides are near-invisible, the *active scope* guide
        -- is red. That contrast is what makes indent guides useful rather than
        -- decorative — you see the block you are in, not fifty vertical lines.
        hl.SnacksIndent = { fg = c.fg_gutter }
        hl.SnacksIndentScope = { fg = c.accent_deep }

        -- Picker
        hl.SnacksPickerMatch = { fg = c.accent, bold = true }
        hl.SnacksPickerTitle = { fg = c.accent, bg = c.bg_dark, bold = true }
        hl.SnacksPickerDir = { fg = c.comment }

        -- Notifications, coloured by level.
        hl.SnacksNotifierInfo = { fg = c.info, bg = c.bg_dark }
        hl.SnacksNotifierWarn = { fg = c.warn, bg = c.bg_dark }
        hl.SnacksNotifierError = { fg = c.error, bg = c.bg_dark }
        hl.SnacksNotifierBorderInfo = { fg = c.info, bg = c.bg_dark }
        hl.SnacksNotifierBorderWarn = { fg = c.warn, bg = c.bg_dark }
        hl.SnacksNotifierBorderError = { fg = c.error, bg = c.bg_dark }

        -- Dashboard
        hl.SnacksDashboardHeader = { fg = c.accent, bold = true }
        hl.SnacksDashboardIcon = { fg = c.accent_dim }
        hl.SnacksDashboardDesc = { fg = c.fg_dark }
        hl.SnacksDashboardKey = { fg = c.yellow, bold = true }
        hl.SnacksDashboardFooter = { fg = c.comment, italic = true }
        hl.SnacksDashboardTitle = { fg = c.accent, bold = true }

        -- which-key: the keybinding screen. Keys red, groups accented.
        hl.WhichKey = { fg = c.accent, bold = true }
        hl.WhichKeyGroup = { fg = c.yellow }
        hl.WhichKeyDesc = { fg = c.fg }
        hl.WhichKeySeparator = { fg = c.comment }
        hl.WhichKeyBorder = { fg = c.accent_deep, bg = c.bg_dark }
        hl.WhichKeyTitle = { fg = c.accent, bg = c.bg_dark, bold = true }

        -- Treesitter context (the sticky function signature at the top).
        hl.TreesitterContext = { bg = c.bg_alt }
        hl.TreesitterContextLineNumber = { fg = c.accent_dim, bg = c.bg_alt }

        -- neo-tree
        hl.NeoTreeGitModified = { fg = c.git_change }
        hl.NeoTreeGitAdded = { fg = c.git_add }
        hl.NeoTreeGitDeleted = { fg = c.git_delete }
        hl.NeoTreeRootName = { fg = c.accent, bold = true }
        hl.NeoTreeIndentMarker = { fg = c.fg_gutter }
        hl.NeoTreeCursorLine = { bg = c.bg_hl }

        -- bufferline: the selected buffer gets a red underline, which is a much
        -- clearer "you are here" than a subtle background change.
        hl.BufferLineIndicatorSelected = { fg = c.accent }
        hl.BufferLineBufferSelected = { fg = c.fg, bold = true, italic = false }

        -- blink.cmp
        hl.BlinkCmpLabelMatch = { fg = c.accent, bold = true }
        hl.BlinkCmpKind = { fg = c.yellow }
        hl.BlinkCmpMenuBorder = { fg = c.accent_deep, bg = c.bg_dark }
        hl.BlinkCmpDocBorder = { fg = c.accent_deep, bg = c.bg_dark }

        -- gitsigns inline blame — must be quiet, it sits on the line you are editing.
        hl.GitSignsCurrentLineBlame = { fg = c.fg_gutter, italic = true }
      end,
    },

    config = function(_, opts)
      require("tokyonight").setup(opts)
      vim.cmd.colorscheme("tokyonight")

      -- Explicitly set the 16 ANSI colours for `:terminal` buffers from our
      -- palette, so a shell (or lazygit) running inside Neovim matches WezTerm
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
