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
        -- Italic comments read as "this is prose, not code" and is the one place
        -- italics genuinely help. Requires an italic font face — JetBrains Mono
        -- Nerd Font has one.
        comments = { italic = true },
        -- Keywords bold rather than italic: they are the red structural anchors of
        -- the file, and bold reinforces that better than a slant.
        keywords = { bold = true, italic = false },
        functions = {},
        variables = {},
        -- Sidebars and floats sit on the darker background, which visually
        -- separates chrome from content.
        sidebars = "dark",
        floats = "dark",
      },

      -- Windows treated as "sidebar" and given the darker background.
      sidebars = {
        "qf", "help", "neo-tree", "aerial", "neotest-summary",
        "trouble", "lazy", "mason", "notify", "spectre_panel",
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
        hl["@string.documentation"] = { fg = c.green, italic = true }
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
        hl["@function.builtin"] = { fg = c.yellow, italic = true }
        hl["@constructor"] = { fg = c.orange, bold = true }

        -- Types stay cool — the one place blue-ish colour earns its keep, because
        -- it distinguishes "what kind of thing" from "what it does".
        hl.Type = { fg = c.cyan }
        hl["@type"] = { fg = c.cyan }
        hl["@type.builtin"] = { fg = c.cyan, italic = true }
        hl["@type.definition"] = { fg = c.cyan, bold = true }
        hl["@module"] = { fg = c.teal }
        hl["@namespace"] = { fg = c.teal }

        hl["@variable"] = { fg = c.fg }
        hl["@variable.builtin"] = { fg = c.accent_dim, italic = true }
        hl["@variable.parameter"] = { fg = c.fg_dark, italic = true }
        hl["@variable.member"] = { fg = c.teal }
        hl["@property"] = { fg = c.teal }
        hl["@attribute"] = { fg = c.magenta }

        hl.Comment = { fg = c.comment, italic = true }
        hl["@comment"] = { fg = c.comment, italic = true }

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
        hl.LspInlayHint = { fg = c.fg_gutter, bg = "NONE", italic = true }

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
        t.black, t.red, t.green, t.yellow, t.blue, t.magenta, t.cyan, t.white,
        t.bright_black, t.bright_red, t.bright_green, t.bright_yellow,
        t.bright_blue, t.bright_magenta, t.bright_cyan, t.bright_white,
      }
      for i, colour in ipairs(ansi) do
        vim.g["terminal_color_" .. (i - 1)] = colour
      end
    end,
  },
}
