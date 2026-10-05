--- ~/.config/nvim/lua/plugins/ui.lua
---
--- The visible chrome: statusline, buffer tabs, message/cmdline UI, icons, and
--- markdown rendering. snacks.nvim (dashboard, notifications, indent guides,
--- picker) lives in lua/plugins/snacks.lua.

local P = require("config.palette")
local c = P.colors
local icons = P.icons

return {
  -- ═════════════════════════════════════════════════════════════════════════
  -- ICONS — required by lualine, bufferline, neo-tree and the picker
  -- ═════════════════════════════════════════════════════════════════════════
  {
    "nvim-tree/nvim-web-devicons",
    lazy = true,
    opts = {
      -- Fall back to a generic file icon rather than nothing for unknown types.
      default = true,
      color_icons = true,
      -- Tint a few filetypes toward the theme so the tabline is not a rainbow.
      override = {
        lua = { icon = "\u{e620}", color = c.blue, name = "Lua" },
        rs = { icon = "\u{e7a8}", color = c.orange, name = "Rust" },
        py = { icon = "\u{e73c}", color = c.yellow, name = "Python" },
        ts = { icon = "\u{e628}", color = c.cyan, name = "TypeScript" },
        toml = { icon = "\u{e6b2}", color = c.accent_dim, name = "Toml" },
      },
    },
  },

  -- ═════════════════════════════════════════════════════════════════════════
  -- STATUSLINE
  -- ═════════════════════════════════════════════════════════════════════════
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    init = function()
      -- Neovim shows the default statusline for a fraction of a second before
      -- lualine loads on VeryLazy. Blanking it avoids that flicker.
      vim.o.statusline = " "
    end,
    opts = function()
      -- ── Custom components ────────────────────────────────────────────────
      -- Each is a function returning a string; lualine calls them on redraw.

      --- Names of the language servers attached to this buffer.
      --- More useful than a generic "LSP" indicator: it tells you *which* server
      --- answered, which matters when two are attached (e.g. basedpyright + ruff).
      local function lsp_clients()
        local buf_clients = vim.lsp.get_clients({ bufnr = 0 })
        if #buf_clients == 0 then
          return ""
        end
        local names = {}
        for _, client in ipairs(buf_clients) do
          -- Skip copilot-style clients that are not really language servers.
          if client.name ~= "null-ls" then
            table.insert(names, client.name)
          end
        end
        return icons.ui.lsp .. table.concat(names, ",")
      end

      --- The active Python virtualenv, if any. Only rendered in Python buffers.
      --- Answers "why is my import not resolving" instantly.
      local function python_env()
        if vim.bo.filetype ~= "python" then
          return ""
        end
        local venv = os.getenv("VIRTUAL_ENV") or os.getenv("CONDA_DEFAULT_ENV")
        if not venv then
          return ""
        end
        -- Show only the final path component: ".venv" not "/home/x/proj/.venv".
        return "\u{e73c} " .. vim.fn.fnamemodify(venv, ":t")
      end

      --- Indentation in force for this buffer, so a tabs-vs-spaces mismatch is
      --- visible before you commit it.
      local function indent_info()
        local expandtab = vim.bo.expandtab
        local width = vim.bo.shiftwidth
        if width == 0 then
          width = vim.bo.tabstop
        end
        return (expandtab and "spaces:" or "tabs:") .. width
      end

      --- Encoding and line endings — but ONLY when they are not the expected
      --- utf-8 / unix. A statusline segment that always says the same thing is
      --- wasted space; one that appears only when something is unusual is a
      --- warning you will actually notice.
      local function file_format()
        local parts = {}
        local enc = vim.bo.fileencoding
        if enc ~= "" and enc ~= "utf-8" then
          table.insert(parts, enc)
        end
        local ff = vim.bo.fileformat
        if ff ~= "unix" then
          -- CRLF on a file destined for Linux is exactly what you want flagged.
          table.insert(parts, ff == "dos" and "CRLF" or ff)
        end
        return table.concat(parts, " ")
      end

      --- Macro recording indicator. Vim's own "recording @q" message is hidden by
      --- 'showmode = false' and by noice, and forgetting you are recording is a
      --- genuinely confusing state to be in.
      local function macro_recording()
        local reg = vim.fn.reg_recording()
        if reg == "" then
          return ""
        end
        return "\u{f111} REC @" .. reg
      end

      --- Search match count ("3/17"), replacing the 'S' flag removed by shortmess.
      local function search_count()
        if vim.v.hlsearch == 0 then
          return ""
        end
        local ok, count = pcall(vim.fn.searchcount, { maxcount = 999, timeout = 100 })
        if not ok or not count or count.total == 0 then
          return ""
        end
        return string.format("%s%d/%d", icons.ui.search, count.current, count.total)
      end

      --- Language-server progress ("Indexing 43%"), only while there is some.
      --- Lives here rather than in a noice popup: a corner float that comes and
      --- goes on every file open is exactly the startup "notification" this
      --- config avoids. `vim.lsp.status()` drains the progress queue; lualine's
      --- 100 ms refresh keeps it current.
      local function lsp_progress()
        local msg = vim.lsp.status()
        if msg == "" then
          return ""
        end
        return msg:gsub("%%", "%%%%"):sub(1, 40)
      end

      -- ── A flat theme, Zed-style: one ground, no blocks ───────────────────
      -- Every section sits on bg_dark; only the mode label is coloured, and
      -- its colour is the mode (lime normal, acid insert, gold visual, coral
      -- replace, sky command). Text, not a filled pill, so the bar stays quiet.
      local function mode(fg)
        local sec = { a = { fg = fg, bg = c.bg_dark, gui = "bold" }, b = { fg = c.fg_dark, bg = c.bg_dark } }
        sec.c = { fg = c.fg_dark, bg = c.bg_dark }
        return sec
      end
      local theme = {
        normal = mode(c.accent),
        insert = mode(c.accent_soft),
        visual = mode(P.syntax.generic),
        replace = mode(c.orange),
        command = mode(c.cyan),
        terminal = mode(c.teal),
        inactive = mode(c.comment),
      }

      return {
        options = {
          theme = theme,
          -- Flat: no powerline arrows, no pipes. Spacing alone groups segments.
          component_separators = "",
          section_separators = "",
          -- ONE statusline for the whole editor, matching laststatus=3.
          globalstatus = true,
          -- Never draw a statusline for these — they have their own headers.
          disabled_filetypes = {
            statusline = { "dashboard", "alpha", "snacks_dashboard" },
            winbar = {},
          },
          refresh = { statusline = 100 },
        },

        sections = {
          -- ── Far left: mode. Red in normal mode, per the theme. ───────────
          lualine_a = { { "mode", padding = { left = 2, right = 1 } } },

          -- ── Git: branch, then added/modified/removed line counts ─────────
          lualine_b = {
            { "branch", icon = icons.ui.branch },
            {
              "diff",
              symbols = {
                added = icons.git.added,
                modified = icons.git.modified,
                removed = icons.git.removed,
              },
              -- Prefer gitsigns' already-computed counts over shelling out to git.
              source = function()
                local gitsigns = vim.b.gitsigns_status_dict
                if gitsigns then
                  return {
                    added = gitsigns.added,
                    modified = gitsigns.changed,
                    removed = gitsigns.removed,
                  }
                end
              end,
            },
          },

          -- ── Middle: diagnostics, then the file itself ────────────────────
          lualine_c = {
            {
              "diagnostics",
              symbols = {
                error = icons.diagnostics.Error,
                warn = icons.diagnostics.Warn,
                info = icons.diagnostics.Info,
                hint = icons.diagnostics.Hint,
              },
            },
            { "filetype", icon_only = true, separator = "", padding = { left = 1, right = 0 } },
            {
              -- `path = 1` gives the path relative to the cwd, which is the most
              -- useful of the four options: bare filenames are ambiguous in a
              -- monorepo (three files called index.ts), and absolute paths are
              -- too long to read.
              "filename",
              path = 1,
              symbols = {
                modified = " " .. icons.file.modified,
                readonly = " " .. icons.file.readonly,
                unnamed = icons.file.unnamed,
                newfile = " " .. icons.file.newfile,
              },
            },
            { macro_recording, color = { fg = c.accent, gui = "bold" } },
          },

          -- ── Right: context that changes per buffer ───────────────────────
          lualine_x = {
            { lsp_progress, color = { fg = c.comment } },
            { search_count, color = { fg = c.accent_dim } },
            { python_env, color = { fg = c.green } },
            { file_format, color = { fg = c.warn, gui = "bold" } },
            { indent_info, color = { fg = c.comment } },
            { lsp_clients, color = { fg = c.comment } },
          },

          -- ── Language name, spelled out ───────────────────────────────────
          lualine_y = {
            { "filetype", icons_enabled = false, padding = { left = 1, right = 1 } },
          },

          -- ── Far right: cursor position ───────────────────────────────────
          -- Position as Zed writes it: line:column, no percentage.
          lualine_z = {
            { "location", color = { fg = c.fg_dark, bg = c.bg_dark }, padding = { left = 1, right = 2 } },
          },
        },

        -- Extensions teach lualine how to render for special buffers, so the
        -- statusline says "neo-tree" instead of showing a meaningless file path.
        extensions = { "neo-tree", "lazy", "mason", "quickfix", "trouble", "man", "aerial" },
      }
    end,
  },

  -- ═════════════════════════════════════════════════════════════════════════
  -- BUFFER TABS along the top
  -- ═════════════════════════════════════════════════════════════════════════
  -- Note: these are BUFFERS, not Vim tab pages. Vim's tab pages are a coarser
  -- concept (a whole window layout); see <leader><tab> in keymaps.lua for those.
  {
    "akinsho/bufferline.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    keys = {
      { "<leader>bp", "<cmd>BufferLineTogglePin<cr>", desc = "Pin buffer" },
      { "<leader>bP", "<cmd>BufferLineGroupClose ungrouped<cr>", desc = "Close unpinned buffers" },
      { "<leader>br", "<cmd>BufferLineCloseRight<cr>", desc = "Close buffers to the right" },
      { "<leader>bl", "<cmd>BufferLineCloseLeft<cr>", desc = "Close buffers to the left" },
      -- Jump straight to a visible buffer by ordinal position.
      { "<leader>1", "<cmd>BufferLineGoToBuffer 1<cr>", desc = "Buffer 1" },
      { "<leader>2", "<cmd>BufferLineGoToBuffer 2<cr>", desc = "Buffer 2" },
      { "<leader>3", "<cmd>BufferLineGoToBuffer 3<cr>", desc = "Buffer 3" },
      { "<leader>4", "<cmd>BufferLineGoToBuffer 4<cr>", desc = "Buffer 4" },
      { "<leader>5", "<cmd>BufferLineGoToBuffer 5<cr>", desc = "Buffer 5" },
    },
    opts = {
      options = {
        -- Show one entry per buffer, and let the mouse close them.
        close_command = function(n)
          Snacks.bufdelete(n)
        end,
        right_mouse_command = function(n)
          Snacks.bufdelete(n)
        end,
        diagnostics = "nvim_lsp",
        -- Render a compact "  2  1" on a tab that has problems, so you can see
        -- which file is broken without opening it.
        diagnostics_indicator = function(_, _, diag)
          local out = {}
          if diag.error then
            table.insert(out, icons.diagnostics.Error .. diag.error)
          end
          if diag.warning then
            table.insert(out, icons.diagnostics.Warn .. diag.warning)
          end
          return table.concat(out, " ")
        end,
        -- Leave room for the file explorer so tabs are not hidden behind it.
        offsets = {
          {
            filetype = "neo-tree",
            text = "Explorer",
            highlight = "Directory",
            text_align = "left",
            separator = true,
          },
        },
        separator_style = "thin",
        indicator = { style = "underline" }, -- lime underline on the active buffer
        show_buffer_close_icons = true,
        show_close_icon = false,
        always_show_bufferline = false, -- hide the bar entirely with only one file
        diagnostics_update_in_insert = false,
        move_wraps_at_ends = true,
        -- Group and sort so related files sit together.
        sort_by = "insert_after_current",
      },
      -- Bufferline derives its colours from the theme; these only take the
      -- italics out. By default a selected tab with errors is red ITALIC — the
      -- slant reads as "provisional", and the count beside it already says it.
      highlights = (function()
        local h = { buffer_selected = { italic = false, bold = true }, diagnostic_selected = { italic = false } }
        for _, k in ipairs({ "error", "warning", "info", "hint" }) do
          h[k .. "_selected"] = { italic = false, bold = true }
          h[k .. "_diagnostic_selected"] = { italic = false, bold = true }
        end
        return h
      end)(),
    },
    config = function(_, opts)
      require("bufferline").setup(opts)
      -- After a session restore, bufferline can render stale tabs until something
      -- forces a refresh.
      vim.api.nvim_create_autocmd({ "BufAdd", "BufDelete" }, {
        callback = function()
          vim.schedule(function()
            pcall(nvim_bufferline)
          end)
        end,
      })
    end,
  },

  -- ═════════════════════════════════════════════════════════════════════════
  -- MESSAGES, CMDLINE AND POPUPS
  -- ═════════════════════════════════════════════════════════════════════════
  -- noice replaces Neovim's bottom-line message area with floating windows: the
  -- command line becomes a centred popup, LSP progress goes to the statusline,
  -- and long messages open in a split instead of a "press ENTER" prompt.
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    dependencies = {
      "MunifTanjim/nui.nvim", -- UI component library noice is built on
      -- Notifications are handled by snacks.notifier, not nvim-notify.
    },
    keys = {
      {
        "<leader>un",
        function()
          require("noice").cmd("dismiss")
        end,
        desc = "Dismiss all notifications",
      },
      {
        "<leader>uN",
        function()
          require("noice").cmd("history")
        end,
        desc = "Message history",
      },
      -- Scroll inside an LSP hover/documentation float without leaving the buffer.
      {
        "<C-f>",
        function()
          if not require("noice.lsp").scroll(4) then
            return "<C-f>"
          end
        end,
        silent = true,
        expr = true,
        desc = "Scroll forward in float",
        mode = { "i", "n", "s" },
      },
      {
        "<C-b>",
        function()
          if not require("noice.lsp").scroll(-4) then
            return "<C-b>"
          end
        end,
        silent = true,
        expr = true,
        desc = "Scroll backward in float",
        mode = { "i", "n", "s" },
      },
    },
    opts = {
      lsp = {
        -- Render LSP markdown (hover docs, signature help) with treesitter
        -- highlighting instead of as plain text. This is a big readability win on
        -- Rust and TypeScript hovers, which are mostly code.
        override = {
          ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
          ["vim.lsp.util.stylize_markdown"] = true,
        },
        hover = { enabled = true },
        -- Signature help is provided by blink.cmp, which shows it inline as you
        -- type arguments. Two implementations would fight over the same float.
        signature = { enabled = false },
        -- "Indexing 43%" style progress from rust-analyzer et al.
        -- Off: progress is a statusline segment (lsp_progress above) instead of
        -- a "mini" float in the corner that appeared on every file open.
        progress = { enabled = false },
        message = { enabled = true },
      },

      presets = {
        -- Keep `/` and `?` search at the bottom where the matches are, rather
        -- than in a centred popup that covers the text you are searching.
        bottom_search = true,
        -- `:` opens a centred command palette.
        command_palette = true,
        -- Long messages (`:messages`, stack traces) open in a split you can
        -- scroll and yank from, instead of a hit-enter prompt.
        long_message_to_split = true,
        inc_rename = false,
        -- Border on LSP documentation floats, matching the rest of the theme.
        lsp_doc_border = true,
      },

      -- Routes filter or redirect specific messages.
      routes = {
        {
          -- Suppress the "written" / "N lines yanked" chatter. 'shortmess' already
          -- handles some of this; noice sees the rest.
          filter = {
            event = "msg_show",
            any = {
              { find = "%d+L, %d+B" }, -- "12L, 340B" after writing
              { find = "; after #%d+" }, -- undo/redo position spam
              { find = "; before #%d+" },
              { find = "%d fewer lines" },
              { find = "%d more lines" },
              { find = "search hit BOTTOM" },
            },
          },
          opts = { skip = true },
        },
        {
          -- Route genuinely long output to a split rather than truncating it.
          filter = { event = "msg_show", min_height = 10 },
          view = "split",
        },
      },

      views = {
        -- Give the command palette the same rounded border as every other float.
        cmdline_popup = {
          border = { style = P.border },
          win_options = { winhighlight = { Normal = "NormalFloat", FloatBorder = "FloatBorder" } },
        },
      },
    },
  },

  -- ═════════════════════════════════════════════════════════════════════════
  -- MARKDOWN RENDERING
  -- ═════════════════════════════════════════════════════════════════════════
  -- Renders headings, code blocks, tables, callouts, checkboxes and quotes as
  -- styled blocks *in the buffer* while keeping the text editable. Pairs with
  -- snacks.image, which renders the actual images referenced in the document.
  {
    "MeanderingProgrammer/render-markdown.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
    ft = { "markdown", "markdown.mdx", "codecompanion" },
    keys = {
      { "<leader>um", "<cmd>RenderMarkdown toggle<cr>", desc = "Toggle markdown rendering" },
    },
    opts = {
      -- Render everywhere except insert mode, so editing shows raw markdown and
      -- reading shows the pretty version. This is the setting that makes the
      -- plugin practical rather than annoying.
      render_modes = { "n", "v", "i", "c", "t" },
      -- Reveal the raw markup on the cursor's line in insert mode only. In
      -- normal mode the rendered view stays intact — a revealed row is wider
      -- than its rendered self, which is what knocks table columns out of line.
      anti_conceal = {
        enabled = true,
        disabled_modes = { "n", "v", "V", "\22", "c", "t" },
      },
      -- Same idea for Vim's own conceal: hide `**` markers under the cursor
      -- everywhere except insert mode.
      win_options = {
        concealcursor = { default = vim.o.concealcursor, rendered = "nvc" },
      },
      heading = {
        sign = false,
        -- Coloured background bars for h1..h6, warm-to-cool so nesting is obvious.
        icons = { "\u{f0a9} ", "\u{f105} ", "\u{f105} ", "\u{f105} ", "\u{f105} ", "\u{f105} " },
        backgrounds = {
          "RenderMarkdownH1Bg",
          "RenderMarkdownH2Bg",
          "RenderMarkdownH3Bg",
          "RenderMarkdownH4Bg",
          "RenderMarkdownH5Bg",
          "RenderMarkdownH6Bg",
        },
      },
      code = {
        style = "full",
        width = "block",
        right_pad = 2,
        border = "thin",
      },
      bullet = { icons = { "\u{25cf}", "\u{25cb}", "\u{25aa}", "\u{25ab}" } },
      checkbox = {
        unchecked = { icon = "\u{f0c8} " },
        checked = { icon = "\u{f14a} ", highlight = "RenderMarkdownChecked" },
      },
      pipe_table = { style = "full", preset = "round" },
      -- Do not fight snacks.image over image links.
      link = { enabled = true },
    },
    config = function(_, opts)
      require("render-markdown").setup(opts)
      -- Heading background bars, derived from the palette so they stay in family.
      local heading_colors = { c.accent, c.yellow, c.orange, c.teal, c.cyan, c.blue }
      for i, colour in ipairs(heading_colors) do
        vim.api.nvim_set_hl(0, "RenderMarkdownH" .. i, { fg = colour, bold = true })
        -- A very dark tint of the heading colour as the background bar.
        vim.api.nvim_set_hl(0, "RenderMarkdownH" .. i .. "Bg", { bg = c.bg_alt, fg = colour, bold = true })
      end
      -- Code blocks on the raised surface: in a markdown file they lift off the
      -- page, and inside an LSP hover (also bg_alt) they are seamless instead of
      -- a patchwork of darker rectangles.
      vim.api.nvim_set_hl(0, "RenderMarkdownCode", { bg = c.bg_alt })
      vim.api.nvim_set_hl(0, "RenderMarkdownCodeInline", { fg = c.fg, bg = c.bg_sel })
      vim.api.nvim_set_hl(0, "RenderMarkdownDash", { fg = c.border })
      -- Table rules in the chrome colour: the default took the head row from
      -- the heading hue and body rows from another, so one table had two
      -- different frames.
      vim.api.nvim_set_hl(0, "RenderMarkdownTableHead", { fg = c.fg_gutter })
      vim.api.nvim_set_hl(0, "RenderMarkdownTableRow", { fg = c.fg_gutter })
      vim.api.nvim_set_hl(0, "RenderMarkdownBullet", { fg = c.accent_dim })
      vim.api.nvim_set_hl(0, "RenderMarkdownChecked", { fg = c.green })
    end,
  },
}
