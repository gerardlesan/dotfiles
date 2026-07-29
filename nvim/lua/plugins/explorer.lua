--- ~/.config/nvim/lua/plugins/explorer.lua
---
--- FILE EXPLORING. Two complementary tools, because they solve different problems
--- and using both is genuinely faster than picking one:
---
---   neo-tree  a persistent sidebar tree. Best for *orientation* — seeing project
---             structure, spotting which directories have git changes, dragging a
---             file somewhere. <leader>e
---   oil.nvim  the current directory AS AN EDITABLE BUFFER. Best for *bulk
---             operations* — rename five files with `ciw` and a macro, delete a
---             range with `dd`, create nested dirs by typing a path. `-`
---
--- Neither is netrw, which is disabled in lua/config/lazy.lua.

local P = require("config.palette")
local icons = P.icons

return {
  -- ═════════════════════════════════════════════════════════════════════════
  -- NEO-TREE — the sidebar
  -- ═════════════════════════════════════════════════════════════════════════
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    cmd = "Neotree",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    },

    keys = {
      {
        "<leader>e",
        function()
          -- `reveal = true` selects the current file in the tree when opening, so
          -- you always land where you are rather than at the project root.
          require("neo-tree.command").execute({ toggle = true, reveal = true, dir = vim.uv.cwd() })
        end,
        desc = "Explorer (reveal current file)",
      },
      {
        "<leader>E",
        function()
          require("neo-tree.command").execute({ toggle = true, dir = vim.uv.cwd() })
        end,
        desc = "Explorer (project root)",
      },
      {
        -- Tree filtered to only files git considers changed. Excellent for
        -- reviewing your own work before committing.
        "<leader>ge",
        function()
          require("neo-tree.command").execute({ source = "git_status", toggle = true })
        end,
        desc = "Explorer: git changes",
      },
      {
        "<leader>be",
        function()
          require("neo-tree.command").execute({ source = "buffers", toggle = true })
        end,
        desc = "Explorer: open buffers",
      },
    },

    -- Called when lazy.nvim unloads the plugin, so the sidebar does not linger.
    deactivate = function()
      vim.cmd([[Neotree close]])
    end,

    init = function()
      -- Make `nvim some/directory` open the tree instead of an empty buffer
      -- showing the directory listing. netrw normally does this; since netrw is
      -- disabled, neo-tree takes over.
      vim.api.nvim_create_autocmd("BufEnter", {
        group = vim.api.nvim_create_augroup("neotree_dir_open", { clear = true }),
        desc = "Open neo-tree when Neovim is started on a directory",
        callback = function()
          local f = vim.fn.argv(0)
          if type(f) == "string" and f ~= "" and vim.fn.isdirectory(f) == 1 then
            vim.g.neo_tree_opened_dir = true
            require("neo-tree")
            return true -- delete this autocmd, it only needs to fire once
          end
        end,
      })
    end,

    opts = {
      -- Which sources are available; cycle between them with `<` and `>` inside
      -- the tree, or jump directly with the keymaps above.
      sources = { "filesystem", "buffers", "git_status", "document_symbols" },

      -- Close the tree when you open a file from it. Off: keeping the sidebar
      -- open is the point of having a sidebar.
      close_if_last_window = true,
      popup_border_style = P.border,
      enable_git_status = true,
      enable_diagnostics = true,

      -- Do not show these sources' own titles as a header bar; the winbar is
      -- cleaner.
      source_selector = {
        winbar = true,
        content_layout = "center",
        sources = {
          { source = "filesystem", display_name = icons.ui.folder .. "Files" },
          { source = "buffers", display_name = "\u{f0f6} Buffers" },
          { source = "git_status", display_name = icons.ui.branch .. "Git" },
          { source = "document_symbols", display_name = "\u{f02b} Symbols" },
        },
      },

      default_component_configs = {
        indent = {
          with_expanders = true, -- show ▸/▾ arrows on directories
          expander_collapsed = "\u{25b8}",
          expander_expanded = "\u{25be}",
          expander_highlight = "NeoTreeExpander",
        },
        icon = {
          folder_closed = "\u{f07b}",
          folder_open = "\u{f07c}",
          folder_empty = "\u{f114}",
        },
        modified = { symbol = icons.file.modified },
        git_status = {
          symbols = {
            added = icons.git.added,
            modified = icons.git.modified,
            deleted = "\u{f014}",
            renamed = "\u{f45a}",
            untracked = "\u{f059}",
            ignored = "\u{f04c}",
            unstaged = "\u{f06a}",
            staged = "\u{f00c}",
            conflict = "\u{f071}",
          },
        },
        diagnostics = {
          symbols = {
            error = icons.diagnostics.Error,
            warn = icons.diagnostics.Warn,
            info = icons.diagnostics.Info,
            hint = icons.diagnostics.Hint,
          },
        },
      },

      window = {
        position = "left",
        width = 34,
        mappings = {
          -- Space is <leader>; letting neo-tree steal it would break every leader
          -- mapping while the tree has focus.
          ["<space>"] = "none",

          -- Open in splits, matching the picker's <C-s>/<C-v>.
          ["<cr>"] = "open",
          ["l"] = "open",
          ["h"] = "close_node",
          ["<C-s>"] = "open_split",
          ["<C-v>"] = "open_vsplit",
          ["t"] = "open_tabnew",
          -- Preview without leaving the tree — press again to close.
          ["P"] = { "toggle_preview", config = { use_float = true } },

          -- File operations. neo-tree prompts for the name; typing a path with
          -- slashes creates the intermediate directories.
          ["a"] = { "add", config = { show_path = "relative" } },
          ["A"] = "add_directory",
          ["d"] = "delete",
          ["r"] = "rename",
          ["y"] = "copy_to_clipboard",
          ["x"] = "cut_to_clipboard",
          ["p"] = "paste_from_clipboard",
          ["c"] = "copy",
          ["m"] = "move",

          -- Copy the path of the highlighted node — constantly useful.
          ["Y"] = function(state)
            local path = state.tree:get_node().path
            vim.fn.setreg("+", path)
            vim.notify(path, vim.log.levels.INFO, { title = "Copied path" })
          end,

          -- Open with the OS default application (image viewer, PDF reader).
          ["O"] = function(state)
            local path = state.tree:get_node().path
            local opener = vim.fn.has("win32") == 1 and "explorer"
              or (vim.fn.has("mac") == 1 and "open" or "xdg-open")
            vim.fn.jobstart({ opener, path }, { detach = true })
          end,

          ["H"] = "toggle_hidden",
          ["/"] = "fuzzy_finder",
          ["f"] = "filter_on_submit",
          ["<C-c>"] = "clear_filter",
          ["R"] = "refresh",
          ["?"] = "show_help",
          ["<"] = "prev_source",
          [">"] = "next_source",
          ["q"] = "close_window",
        },
      },

      filesystem = {
        -- Keep the tree's selection in sync with the buffer you are editing.
        follow_current_file = { enabled = true, leave_dirs_open = true },

        -- "open_default" is the sane choice: navigating into a directory in the
        -- tree does NOT change Neovim's cwd. Changing cwd silently reroots your
        -- LSP, fuzzy finder and :grep, which is the same trap as 'autochdir'.
        hijack_netrw_behavior = "open_default",

        -- Watch the filesystem so files created outside Neovim appear without a
        -- manual refresh. Uses libuv, cheap on both platforms.
        use_libuv_file_watcher = true,

        filtered_items = {
          -- Show dotfiles and gitignored files, but DIMMED rather than hidden.
          -- Hiding them means you cannot find .github/workflows or .env when you
          -- need them; dimming keeps them out of the way but reachable.
          visible = true,
          hide_dotfiles = false,
          hide_gitignored = false,
          hide_hidden = false, -- Windows "hidden" attribute
          -- These, though, are pure noise and are hidden outright.
          hide_by_name = {
            "node_modules", "__pycache__", ".git", ".DS_Store",
            "thumbs.db", ".mypy_cache", ".ruff_cache", ".pytest_cache",
            ".venv", "target", "dist", ".next", ".turbo",
          },
          never_show = { ".DS_Store", "thumbs.db" },
        },
      },

      buffers = {
        follow_current_file = { enabled = true },
        group_empty_dirs = true,
        show_unloaded = true,
      },

      git_status = {
        window = { position = "float" },
      },

      event_handlers = {
        {
          -- Neo-tree's own buffer should not show the cursorline-follows-focus
          -- behaviour from autocmds.lua fighting its highlighting.
          event = "neo_tree_buffer_enter",
          handler = function()
            vim.opt_local.signcolumn = "no"
            vim.opt_local.foldcolumn = "0"
            vim.opt_local.number = false
            vim.opt_local.relativenumber = false
          end,
        },
      },
    },
  },

  -- ═════════════════════════════════════════════════════════════════════════
  -- OIL — the filesystem as a normal, editable buffer
  -- ═════════════════════════════════════════════════════════════════════════
  -- This is the one that changes how you work. Press `-` and the directory opens
  -- as text. Every normal Vim edit applies to the filesystem when you `:w`:
  --   `cw`   rename a file
  --   `dd`   delete a file      (staged, then confirmed on write)
  --   `p`    move/copy a file
  --   `o`    create a new file; type `a/b/c.rs` and it creates the directories
  --   visual block + `I` — prefix twenty filenames at once
  -- Nothing touches the disk until you write, and it shows you a confirmation
  -- diff of exactly what it is about to do.
  {
    "stevearc/oil.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    -- Load eagerly so `nvim .` opens oil rather than an empty buffer.
    lazy = false,
    keys = {
      { "-", "<cmd>Oil<cr>", desc = "Open parent directory (oil)" },
      { "<leader>fo", function() require("oil").toggle_float() end, desc = "Oil (floating)" },
    },
    opts = {
      -- Take over `:edit <directory>`. neo-tree deliberately does not
      -- (hijack_netrw_behavior = "open_default"), so there is no conflict: oil
      -- owns "edit a directory", neo-tree owns the sidebar.
      default_file_explorer = true,

      columns = {
        "icon",
        -- Uncomment for a fuller `ls -l` view. Off by default because the extra
        -- columns push filenames right and make the buffer noisier to edit.
        -- "permissions",
        -- "size",
        -- "mtime",
      },

      -- Never silently overwrite. oil shows a confirmation listing every create,
      -- delete, move and copy before applying it.
      skip_confirm_for_simple_edits = false,
      prompt_save_on_select_new_entry = true,

      delete_to_trash = true, -- recoverable deletes; needs `trash-cli` on Linux

      view_options = {
        -- Show dotfiles: this repo is full of them.
        show_hidden = true,
        -- Hide the "..", since `-` already goes up.
        is_always_hidden = function(name)
          return name == ".."
        end,
      },

      -- Wipe oil buffers when hidden so a stale directory listing never resurfaces.
      cleanup_delay_ms = 2000,

      keymaps = {
        ["g?"] = "actions.show_help",
        ["<CR>"] = "actions.select",
        ["<C-s>"] = { "actions.select", opts = { horizontal = true } },
        ["<C-v>"] = { "actions.select", opts = { vertical = true } },
        ["<C-t>"] = { "actions.select", opts = { tab = true } },
        ["<C-p>"] = "actions.preview",
        ["<C-c>"] = "actions.close",
        ["<C-l>"] = "actions.refresh",
        ["-"] = "actions.parent",
        ["_"] = "actions.open_cwd",
        ["`"] = "actions.cd",
        ["gs"] = "actions.change_sort",
        ["gx"] = "actions.open_external", -- open with the OS default app
        ["g."] = "actions.toggle_hidden",
        ["g\\"] = "actions.toggle_trash",
      },
      -- oil defines its own <CR> etc, so do not also inherit the defaults.
      use_default_keymaps = false,

      float = {
        padding = 2,
        max_width = 100,
        max_height = 30,
        border = P.border,
      },
    },
  },
}
