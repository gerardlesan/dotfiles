--- ~/.config/wezterm/wezterm.lua
---
--- ═════════════════════════════════════════════════════════════════════════════
--- WEZTERM — cross-platform terminal configuration
--- ═════════════════════════════════════════════════════════════════════════════
---
--- THIS PATH WORKS ON BOTH PLATFORMS. WezTerm looks for its config at, in order:
---   $WEZTERM_CONFIG_FILE
---   $XDG_CONFIG_HOME/wezterm/wezterm.lua
---   ~/.config/wezterm/wezterm.lua      ← this file, on Windows AND Linux
---   ~/.wezterm.lua
--- So copying this one file to a Linux box is the whole migration. Per-OS
--- differences are handled by the `is_windows` branches below rather than by
--- keeping two files.
---
--- TRACKED IN THE REPO, DEPLOYED ONLY ON WINDOWS. This file lives at
--- wezterm/wezterm.lua and is copied out by install.ps1 (see its "WezTerm,
--- fastfetch and PowerShell profile" step). install.sh deliberately does NOT
--- touch it — the active Linux terminal is Ghostty (see ~/.config/ghostty), so
--- there is no path by which editing this file affects the Linux install.
---
--- COLOURS ARE DUPLICATED FROM NEOVIM, deliberately. WezTerm cannot `require`
--- anything from Neovim's runtimepath, so the palette below repeats the hex values
--- from ~/.config/nvim/lua/config/palette.lua. If you retune the theme, change
--- both files. The two are matched so that a shell inside Neovim (`<C-/>`) and a
--- shell outside it look identical.
---
--- Reload after editing: WezTerm watches this file and applies changes instantly.
--- No restart needed. Check for errors with `wezterm --config-file ... ls-fonts`
--- or by looking at the debug overlay (CTRL+SHIFT+L).

local wezterm = require("wezterm")
local act = wezterm.action
local config = wezterm.config_builder()

local is_windows = wezterm.target_triple:find("windows") ~= nil
local is_mac = wezterm.target_triple:find("darwin") ~= nil

-- The WSL distro that Windows sessions default to. Declared here because both the
-- SHELL AND DOMAINS section and the keybindings below need the same string, and a
-- typo in one of two copies is a silent "unknown domain" at spawn time.
local WSL_DEFAULT = "WSL:Debian"

-- ═════════════════════════════════════════════════════════════════════════════
-- PALETTE — mirrors ~/.config/nvim/lua/config/palette.lua
-- ═════════════════════════════════════════════════════════════════════════════
local P = {
  bg_dark   = "#15131a",
  bg        = "#1a1820",
  bg_alt    = "#1f1c27",
  bg_hl     = "#2b2333",
  bg_sel    = "#2f2739",
  bg_visual = "#3a2b42",

  fg        = "#cbc6d9",
  fg_dark   = "#a8a2bb",
  fg_gutter = "#3b3548",
  comment   = "#6d6484",

  accent      = "#f7768e",
  accent_soft = "#ffa0ae",
  accent_dim  = "#d4687d",
  accent_deep = "#c53b53",

  orange  = "#ff9e64",
  yellow  = "#e0af68",
  green   = "#9ece6a",
  teal    = "#5ec8b0",
  cyan    = "#7dcfff",
  blue    = "#7aa2f7",
  magenta = "#bb9af7",

  error = "#db4b4b",
}

config.colors = {
  foreground = P.fg,
  background = P.bg,

  cursor_bg = P.accent,
  cursor_fg = P.bg,
  -- The cursor's outline when the window is unfocused.
  cursor_border = P.accent,

  selection_bg = P.bg_visual,
  selection_fg = P.fg,

  -- The thin line WezTerm draws between split panes. Red, matching Neovim's
  -- WinSeparator, so panes and splits read as the same visual language.
  split = P.accent_deep,

  -- ANSI 0-7 and bright 8-15. These are what every CLI tool colours itself with,
  -- and they are identical to g:terminal_color_0..15 in Neovim.
  ansi = {
    P.bg_sel,  -- 0 black
    P.accent,  -- 1 red
    P.green,   -- 2 green
    P.yellow,  -- 3 yellow
    P.blue,    -- 4 blue
    P.magenta, -- 5 magenta
    P.cyan,    -- 6 cyan
    P.fg,      -- 7 white
  },
  brights = {
    "#4b4360", -- 8  bright black (grey)
    "#ff8fa3", -- 9  bright red
    "#b9f27c", -- 10 bright green
    "#ffc777", -- 11 bright yellow
    "#95b6ff", -- 12 bright blue
    "#cdaaff", -- 13 bright magenta
    "#a4dcff", -- 14 bright cyan
    "#e8e4f0", -- 15 bright white
  },

  -- ── Tab bar ─────────────────────────────────────────────────────────────
  -- The active tab gets the red accent as a background; inactive tabs stay dark.
  -- This is the single strongest "this setup is red" visual cue outside Neovim.
  tab_bar = {
    background = P.bg_dark,
    active_tab = {
      bg_color = P.accent_deep,
      fg_color = "#ffffff",
      intensity = "Bold",
    },
    inactive_tab = {
      bg_color = P.bg_alt,
      fg_color = P.comment,
    },
    inactive_tab_hover = {
      bg_color = P.bg_hl,
      fg_color = P.fg,
      italic = false,
    },
    new_tab = {
      bg_color = P.bg_dark,
      fg_color = P.comment,
    },
    new_tab_hover = {
      bg_color = P.bg_hl,
      fg_color = P.accent,
    },
  },

  -- Colour of the scrollbar thumb, if enabled below.
  scrollbar_thumb = P.bg_hl,

  -- Visual bell flash colour. See the bell section.
  visual_bell = P.accent_deep,
}

-- ═════════════════════════════════════════════════════════════════════════════
-- FONT
-- ═════════════════════════════════════════════════════════════════════════════
-- A NERD FONT IS REQUIRED. Neovim's statusline, file explorer, git signs and
-- pickers all use glyphs from the Nerd Font private-use range. Without a patched
-- font you get hollow boxes everywhere. Verify inside Neovim with `:CheckIcons`.
--
-- Install:
--   Windows  winget install DEVCOM.JetBrainsMonoNerdFont
--   Debian   sudo apt install fonts-jetbrains-mono   (then check it is the NF
--            build; if not, download from github.com/ryanoasis/nerd-fonts)
--   Arch     sudo pacman -S ttf-jetbrains-mono-nerd
--   macOS    brew install --cask font-jetbrains-mono-nerd-font
config.font = wezterm.font_with_fallback({
  { family = "JetBrainsMono Nerd Font", weight = "Regular" },
  -- Fallbacks, in order, so a missing glyph degrades rather than showing a box.
  { family = "JetBrains Mono", weight = "Regular" },
  "Symbols Nerd Font Mono", -- glyph-only font: covers icons if the main font lacks them
  "Noto Color Emoji",
})

config.font_size = is_mac and 14.0 or 11.5

-- Explicit line height. JetBrains Mono is fairly tight by default; 1.1 gives the
-- text room to breathe without wasting vertical space.
config.line_height = 1.1
config.cell_width = 1.0

-- Ligatures. JetBrains Mono turns `->`, `=>`, `!=`, `>=` into single glyphs.
-- Pleasant in Rust and TypeScript, which are full of arrows.
--
-- If you find them confusing (they change how many characters *appear* to be
-- there, which can mislead when counting columns), disable with:
--   config.harfbuzz_features = { "calt=0", "clig=0", "liga=0" }
config.harfbuzz_features = { "calt=1", "clig=1", "liga=1" }

-- Use the bold font variant for bright ANSI colours? No — bright colours already
-- differ by hue, and forcing bold makes half the terminal heavy.
config.bold_brightens_ansi_colors = false

-- Do not pop up a warning for every glyph the font lacks. It is noisy, and
-- `:CheckIcons` in Neovim is the deliberate way to test coverage.
config.warn_about_missing_glyphs = false

-- ═════════════════════════════════════════════════════════════════════════════
-- IMAGE SUPPORT — required for image viewing in Neovim
-- ═════════════════════════════════════════════════════════════════════════════
-- snacks.image (see ~/.config/nvim/lua/plugins/snacks.lua) renders images by
-- speaking the Kitty graphics protocol to the terminal. This must be on.
--
-- HONEST CAVEAT: WezTerm's implementation of that protocol is partial. It does not
-- support Unicode placeholders, so an image rendered INLINE in a scrolling
-- document can leave artefacts when you scroll past it — press <C-l> in Neovim to
-- force a redraw. Opening an image in a float (<leader>ii) is reliable.
--
-- If inline images in markdown matter a lot to you, Kitty and Ghostty implement
-- the protocol completely. Everything else in this setup is terminal-agnostic, so
-- switching is just a different terminal config — the Neovim side is unchanged.
config.enable_kitty_graphics = true

-- WezTerm's extended keyboard protocol (kitty-keyboard / CSI-u). OFF.
--
-- Was ON: it lets Neovim distinguish key combinations that legacy terminals
-- cannot encode (for example <C-i> from <Tab>, and <C-S-h>).
--
-- Turned off because it broke SHIFT entirely inside Claude Code's CLI: no
-- capitals, no shifted punctuation, nothing. Claude Code's input layer is a
-- Node/Ink TUI, and that stack does not correctly unpack the extended CSI-u
-- sequences this protocol sends for a plain Shift+key — the keystroke never
-- becomes a typed character. This was diagnosed by reading this very comment,
-- which already named "the first thing to try" — confirmed against the running
-- config, not guessed.
--
-- Cost of turning it off: Neovim goes back to legacy key disambiguation (fine —
-- it doesn't lean on the exotic combos above), and every other CSI-u-aware app
-- loses the same fine-grained modifier reporting. Given the alternative was a
-- fragile per-process override (detect the foreground process, toggle this via
-- a config override just for that pane), a single global switch is the lazier
-- and more robust fix. Re-enable only if you confirm the TUI you're using has
-- fixed its CSI-u handling.
config.enable_kitty_keyboard = false

-- ═════════════════════════════════════════════════════════════════════════════
-- WINDOW AND APPEARANCE
-- ═════════════════════════════════════════════════════════════════════════════

-- Asymmetric padding: a little breathing room on the sides, none at the bottom so
-- Neovim's statusline sits flush against the window edge.
config.window_padding = {
  left = 8,
  right = 8,
  top = 6,
  bottom = 0,
}

-- Slight transparency plus a blur behind the window. Subtle enough to keep text
-- fully legible (anything below ~0.9 starts to hurt).
--
-- Set to 1.0 if you dislike it, or if you notice compositor lag on Linux.
config.window_background_opacity = 0.97
if is_mac then
  config.macos_window_background_blur = 20
end

-- Keep the native title bar and buttons but drop the heavy border. "RESIZE" alone
-- gives a borderless look; use "TITLE | RESIZE" for the standard window frame.
config.window_decorations = is_windows and "TITLE | RESIZE" or "TITLE | RESIZE"

-- Do not resize the window when the font size changes — only reflow the grid.
config.adjust_window_size_when_changing_font_size = false

config.initial_cols = 140
config.initial_rows = 38

-- ── Tab bar ──────────────────────────────────────────────────────────────────
config.use_fancy_tab_bar = false      -- the retro bar respects our colours exactly
config.tab_bar_at_bottom = false
config.hide_tab_bar_if_only_one_tab = true -- no wasted row when there is one tab
config.tab_max_width = 32
config.show_new_tab_button_in_tab_bar = false
config.show_tab_index_in_tab_bar = true

-- ── Cursor ───────────────────────────────────────────────────────────────────
-- A blinking bar in the shell. Neovim overrides this per mode via 'guicursor'
-- (block in normal, bar in insert) — see lua/config/options.lua section 04.
config.default_cursor_style = "BlinkingBar"
config.cursor_blink_rate = 600
-- "Constant" instead of the default easing, which some GPUs render as a smear.
config.cursor_blink_ease_in = "Constant"
config.cursor_blink_ease_out = "Constant"

-- ── Scrollback ───────────────────────────────────────────────────────────────
config.scrollback_lines = 10000
config.enable_scroll_bar = false -- Neovim has its own; a shell rarely needs one

-- ── Bell ─────────────────────────────────────────────────────────────────────
-- No audible beep. A brief, subtle red flash instead, which is informative
-- without being startling.
config.audible_bell = "Disabled"
config.visual_bell = {
  fade_in_function = "EaseIn",
  fade_in_duration_ms = 75,
  fade_out_function = "EaseOut",
  fade_out_duration_ms = 150,
}

-- ═════════════════════════════════════════════════════════════════════════════
-- SHELL AND DOMAINS
-- ═════════════════════════════════════════════════════════════════════════════
-- On Linux and macOS this whole block is skipped, so WezTerm uses the real login
-- shell from /etc/passwd. Hardcoding "/bin/bash" would override a deliberate
-- choice of zsh or fish.
--
-- On Windows the default is PowerShell 7 (`pwsh`) over the bundled 5.1 and over
-- cmd.exe. Neovim's 'shell' is configured to match — see section 28 of
-- lua/config/options.lua, which also fixes the quoting options PowerShell needs.
--
-- WSL IS NEVER WHAT YOU LAND IN. It is one keystroke away — CTRL+SHIFT+D for a
-- Debian tab, or the launcher (CTRL+SHIFT+P) — and nothing more.
--
-- But the distros are still registered as DOMAINS rather than reached by running
-- `wsl.exe` as a program, and that distinction is the whole reason this block is
-- more than two lines. Running wsl.exe as a *program* leaves the pane in the
-- `local` (Windows) domain, so `CurrentPaneDomain` still resolves to Windows —
-- and every binding below that uses it hands you a PowerShell out of a Debian
-- pane: SpawnTab (CTRL+SHIFT+T) and both splits (CTRL+SHIFT+| and CTRL+SHIFT+_).
-- Registering the domain makes CurrentPaneDomain *be* WSL:Debian once you are in
-- such a pane, so tabs and splits opened from it inherit the distro. It also gets
-- \\wsl$ path translation for `pane:get_current_working_dir()`, which
-- update-right-status at the bottom of this file reads to draw the cwd.
--
-- ON `default_prog` AND `default_domain` TOGETHER: don't. default_prog applies to
-- spawns in the DEFAULT domain, so setting default_domain = WSL while this is set
-- runs pwsh.exe *inside* Debian. It does not even fail cleanly — WSL appends the
-- Windows PATH by default, so pwsh.exe resolves through /mnt/c and you get a
-- Windows shell in a WSL pane. Since the default here is Windows, default_domain
-- is deliberately left unset (it defaults to `local`) and this stays.
if is_windows then
  config.default_prog = { "pwsh.exe", "-NoLogo" }

  -- Shells out to `wsl -l -v` and returns one domain per installed distro, named
  -- "WSL:<distro>". Verified on this machine: yields exactly WSL:Debian. Safe when
  -- no distro is installed — the list is simply empty, and the CTRL+SHIFT+D
  -- binding then reports an unknown domain instead of silently doing nothing.
  local wsl_domains = wezterm.default_wsl_domains()

  for _, dom in ipairs(wsl_domains) do
    if dom.name == WSL_DEFAULT then
      -- Start in the WINDOWS user folder, not the WSL home. Chosen deliberately:
      -- the work — including the dotfiles repo this config comes from — lives on
      -- the Windows side, and landing in /home/gerard means every session begins
      -- with the same `cd /mnt/c/...`.
      --
      -- Two costs, both accepted. /mnt/c is a 9p mount (cache=0x5, msize=65536),
      -- so file-heavy operations here are markedly slower than on ext4. And the
      -- starship `directory` module cannot shorten this to `~` — that is
      -- home_symbol, and this is not $HOME — so expect the truncated
      -- `…/Users/gerard.lesan` form instead, from truncation_length = 3.
      --
      -- Set this back to "/home/gerard" for the fast, short-prompt behaviour.
      -- A literal "~" is NOT expanded in this field, so either way it is spelled out.
      dom.default_cwd = "/mnt/c/Users/gerard.lesan"
    end
  end
  config.wsl_domains = wsl_domains

  -- Launcher: CTRL+SHIFT+P. Windows shells first, since they are the default.
  --
  -- The `local` domain is still named EXPLICITLY on each Windows entry. It is
  -- redundant while default_domain is unset, and kept anyway: it is the one line
  -- that stops these entries silently following default_domain into WSL — and
  -- straight into the pwsh-inside-Debian trap above — if that is ever set again.
  --
  -- The Debian entry deliberately passes no `args` at all, so it uses the distro's
  -- login shell from /etc/passwd (fish), rather than pinning a shell here that
  -- would then disagree with `chsh`.
  config.launch_menu = {
    { label = "PowerShell 7", domain = { DomainName = "local" }, args = { "pwsh.exe", "-NoLogo" } },
    { label = "PowerShell 5.1", domain = { DomainName = "local" }, args = { "powershell.exe", "-NoLogo" } },
    { label = "Command Prompt", domain = { DomainName = "local" }, args = { "cmd.exe" } },
    { label = "Debian (WSL)", domain = { DomainName = WSL_DEFAULT } },
  }
end

-- Do not prompt "are you sure?" when closing a window whose only running process
-- is a shell. Still prompts if something (a build, ssh, Neovim) is actually
-- running, which is the behaviour you want.
config.window_close_confirmation = "AlwaysPrompt"
config.skip_close_confirmation_for_processes_named = {
  "bash", "sh", "zsh", "fish", "tmux", "nu",
  "cmd.exe", "pwsh.exe", "powershell.exe",
}

-- ═════════════════════════════════════════════════════════════════════════════
-- KEY BINDINGS
-- ═════════════════════════════════════════════════════════════════════════════
-- DESIGN DECISION: every WezTerm binding uses CTRL+SHIFT, and there is no leader
-- key.
--
-- The reason is Neovim. A WezTerm leader would swallow one chord before Neovim
-- ever sees it, and every comfortable candidate is already meaningful in Vim:
--   CTRL+A  increment number      CTRL+B  page up / noice scroll
--   CTRL+Space  completion menu   CTRL+W  window commands
-- CTRL+SHIFT combinations are, by contrast, almost never bound in terminal
-- applications, so nothing is shadowed.
--
-- Note also that Neovim already owns splits, tabs and buffers. WezTerm's panes are
-- here for the cases Neovim cannot cover — running a dev server beside the editor,
-- or a shell in a different working directory.
config.disable_default_key_bindings = false -- keep WezTerm's sensible defaults too

config.keys = {
  -- ── Panes ─────────────────────────────────────────────────────────────────
  -- The `|` and `-` mnemonics mirror <leader>| and <leader>- in Neovim, so the
  -- same shapes mean the same thing in both.
  {
    key = "|",
    mods = "CTRL|SHIFT",
    action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }),
  },
  {
    key = "_",
    mods = "CTRL|SHIFT",
    action = act.SplitVertical({ domain = "CurrentPaneDomain" }),
  },
  -- Pane navigation with the same hjkl directions as Neovim's <C-hjkl>.
  { key = "h", mods = "CTRL|SHIFT", action = act.ActivatePaneDirection("Left") },
  { key = "j", mods = "CTRL|SHIFT", action = act.ActivatePaneDirection("Down") },
  { key = "k", mods = "CTRL|SHIFT", action = act.ActivatePaneDirection("Up") },
  { key = "l", mods = "CTRL|SHIFT", action = act.ActivatePaneDirection("Right") },
  { key = "w", mods = "CTRL|SHIFT", action = act.CloseCurrentPane({ confirm = true }) },
  -- Full-screen the current pane and back, like Neovim's <leader>wm.
  { key = "z", mods = "CTRL|SHIFT", action = act.TogglePaneZoomState },

  -- Resize panes with CTRL+SHIFT+arrows, matching Neovim's CTRL+arrows.
  { key = "LeftArrow", mods = "CTRL|SHIFT", action = act.AdjustPaneSize({ "Left", 3 }) },
  { key = "RightArrow", mods = "CTRL|SHIFT", action = act.AdjustPaneSize({ "Right", 3 }) },
  { key = "UpArrow", mods = "CTRL|SHIFT", action = act.AdjustPaneSize({ "Up", 3 }) },
  { key = "DownArrow", mods = "CTRL|SHIFT", action = act.AdjustPaneSize({ "Down", 3 }) },

  -- ── Tabs ──────────────────────────────────────────────────────────────────
  { key = "t", mods = "CTRL|SHIFT", action = act.SpawnTab("CurrentPaneDomain") },
  { key = "[", mods = "CTRL|SHIFT", action = act.ActivateTabRelative(-1) },
  { key = "]", mods = "CTRL|SHIFT", action = act.ActivateTabRelative(1) },
  { key = "e", mods = "CTRL|SHIFT", action = act.ShowTabNavigator },
  -- Rename the current tab, so a long session stays navigable.
  {
    key = "r",
    mods = "CTRL|SHIFT",
    action = act.PromptInputLine({
      description = "Rename tab:",
      action = wezterm.action_callback(function(window, _, line)
        if line and line ~= "" then
          window:active_tab():set_title(line)
        end
      end),
    }),
  },

  -- ── Domains ───────────────────────────────────────────────────────────────
  -- CTRL+SHIFT+D IS THE WAY INTO WSL. Windows is the default everywhere else:
  -- new windows, and CTRL+SHIFT+T, which spawns into CurrentPaneDomain and so
  -- stays on whichever side you are already on.
  --
  -- CTRL+ALT+P is the reverse trip. It is not redundant with the Windows default:
  -- once you are inside a Debian pane, CTRL+SHIFT+T keeps you there, so this is
  -- the only one-key route back to a Windows shell.
  --
  -- On the keys: `d` for Debian was one of only seven CTRL+SHIFT letters still
  -- free (a b d g i q y — checked with `wezterm show-keys`, which renders
  -- CTRL+SHIFT+h as "CTRL H", so read it carefully). PowerShell breaks the
  -- CTRL+SHIFT-only rule stated above because CTRL+SHIFT+P is ShowLauncher and none
  -- of the free letters mean "PowerShell"; CTRL+ALT keeps the mnemonic, and there
  -- is precedent for it in the ClearScrollback binding further down.
  {
    key = "d",
    mods = "CTRL|SHIFT",
    action = act.SpawnCommandInNewTab({ domain = { DomainName = WSL_DEFAULT } }),
  },
  {
    key = "p",
    mods = "CTRL|ALT",
    action = act.SpawnCommandInNewTab({
      domain = { DomainName = "local" },
      args = { "pwsh.exe", "-NoLogo" },
    }),
  },

  -- ── Font size ─────────────────────────────────────────────────────────────
  { key = "+", mods = "CTRL|SHIFT", action = act.IncreaseFontSize },
  { key = "-", mods = "CTRL", action = act.DecreaseFontSize },
  { key = "0", mods = "CTRL", action = act.ResetFontSize },

  -- ── Copy and paste ────────────────────────────────────────────────────────
  -- CTRL+SHIFT+C/V are WezTerm defaults, listed here for discoverability.
  { key = "c", mods = "CTRL|SHIFT", action = act.CopyTo("Clipboard") },
  { key = "v", mods = "CTRL|SHIFT", action = act.PasteFrom("Clipboard") },

  -- ── Scrollback ────────────────────────────────────────────────────────────
  -- Vim-style search over terminal output.
  { key = "/", mods = "CTRL|SHIFT", action = act.Search({ CaseInSensitiveString = "" }) },
  -- Copy mode: navigate and select scrollback with Vim motions.
  { key = "x", mods = "CTRL|SHIFT", action = act.ActivateCopyMode },
  { key = "PageUp", mods = "SHIFT", action = act.ScrollByPage(-1) },
  { key = "PageDown", mods = "SHIFT", action = act.ScrollByPage(1) },
  -- Clear the scrollback AND the screen — the equivalent of `clear` but complete.
  { key = "k", mods = "CTRL|ALT", action = act.ClearScrollback("ScrollbackAndViewport") },

  -- ── Utility ───────────────────────────────────────────────────────────────
  -- No explicit "reload config" binding: WezTerm watches this file and applies
  -- changes the moment you save. (A `key = "K"` binding here would also collide
  -- with `key = "k"` above, since both resolve to CTRL+SHIFT+K.)
  --
  -- The debug overlay: a Lua REPL against the live config, and the error log.
  -- This is where a config mistake shows up.
  { key = "L", mods = "CTRL|SHIFT", action = act.ShowDebugOverlay },
  { key = "p", mods = "CTRL|SHIFT", action = act.ShowLauncher },
  { key = "f", mods = "CTRL|SHIFT", action = act.ToggleFullScreen },

  -- Quick-select mode: highlights every URL, path and hash on screen and labels
  -- them, so you copy one with two keystrokes instead of selecting by mouse.
  -- Genuinely one of WezTerm's best features.
  { key = "s", mods = "CTRL|SHIFT", action = act.QuickSelect },
  -- Open a URL on screen without touching the mouse.
  { key = "o", mods = "CTRL|SHIFT", action = act.QuickSelectArgs({
      label = "open url",
      patterns = { "https?://\\S+" },
      action = wezterm.action_callback(function(window, pane)
        local url = window:get_selection_text_for_pane(pane)
        wezterm.open_with(url)
      end),
    }),
  },
}

-- ═════════════════════════════════════════════════════════════════════════════
-- MOUSE
-- ═════════════════════════════════════════════════════════════════════════════
config.mouse_bindings = {
  -- CTRL+click opens a hyperlink, rather than a bare click doing it by accident.
  {
    event = { Up = { streak = 1, button = "Left" } },
    mods = "CTRL",
    action = act.OpenLinkAtMouseCursor,
  },
  -- Right-click pastes, which is the fast shell workflow. Note that Neovim's
  -- 'mousemodel' is set to "extend", so inside Neovim right-click extends a
  -- selection instead — each layer does the sensible thing for its context.
  {
    event = { Down = { streak = 1, button = "Right" } },
    mods = "NONE",
    action = act.PasteFrom("Clipboard"),
  },
}

-- Copy on select, so highlighting with the mouse puts text on the clipboard.
config.selection_word_boundary = " \t\n{}[]()\"'`,;:│"

-- ═════════════════════════════════════════════════════════════════════════════
-- HYPERLINKS
-- ═════════════════════════════════════════════════════════════════════════════
-- Make more things clickable than the default URL matcher manages.
config.hyperlink_rules = wezterm.default_hyperlink_rules()

-- Linkify GitHub-style `owner/repo` references.
table.insert(config.hyperlink_rules, {
  regex = [[["']?([\w\d]{1}[-\w\d]+)(/){1}([-\w\d\.]+)["']?]],
  format = "https://www.github.com/$1/$3",
})
-- Linkify file:line references, as emitted by compilers, ripgrep and test runners.
table.insert(config.hyperlink_rules, {
  regex = [[\b\w+\.\w+:\d+\b]],
  format = "$0",
  highlight = 0,
})

-- ═════════════════════════════════════════════════════════════════════════════
-- PERFORMANCE
-- ═════════════════════════════════════════════════════════════════════════════
-- Cap the frame rate. 60 is plenty for a terminal and noticeably reduces GPU and
-- battery use versus WezTerm's uncapped default on a high-refresh display.
config.max_fps = 60
config.animation_fps = 60

-- Rendering backend. "WebGpu" is the modern default and generally fastest.
-- If you get a black window, garbled text or a driver crash — most often on a
-- Windows VM, over RDP, or with old Intel graphics — switch to "Software":
--   config.front_end = "Software"
config.front_end = "WebGpu"
config.webgpu_power_preference = "HighPerformance"

-- ═════════════════════════════════════════════════════════════════════════════
-- TAB TITLES
-- ═════════════════════════════════════════════════════════════════════════════
-- Show the running program, or Neovim's own title (which lua/config/options.lua
-- sets to "filename [+] — nvim (project)"), rather than a bare shell path.
wezterm.on("format-tab-title", function(tab, _, _, _, hover, max_width)
  local title = tab.tab_title
  -- An explicitly set title (CTRL+SHIFT+R) always wins.
  if title == nil or #title == 0 then
    title = tab.active_pane.title
  end

  -- Trim the noise Windows adds to process titles.
  title = title:gsub("^Administrator: ", ""):gsub("%.exe$", "")

  -- Mark a tab whose process has produced output since you last looked.
  local prefix = tab.is_active and " " or " "
  if tab.active_pane.has_unseen_output and not tab.is_active then
    prefix = " ● "
  end

  local text = prefix .. (tab.tab_index + 1) .. ": " .. title .. " "
  if #text > max_width then
    text = wezterm.truncate_right(text, max_width - 1) .. "… "
  end

  return {
    { Text = text },
  }
end)

-- Show the current working directory and a clock in the top right.
wezterm.on("update-right-status", function(window, pane)
  local cells = {}

  -- Current directory, shortened to its last two components.
  local cwd_uri = pane:get_current_working_dir()
  if cwd_uri then
    local cwd = type(cwd_uri) == "userdata" and cwd_uri.file_path or tostring(cwd_uri)
    -- Keep only the last two path segments so the bar stays short.
    local parts = {}
    for part in cwd:gmatch("[^/\\]+") do
      table.insert(parts, part)
    end
    local short = #parts > 1 and (parts[#parts - 1] .. "/" .. parts[#parts]) or (parts[#parts] or "")
    table.insert(cells, { Foreground = { Color = P.accent_dim } })
    table.insert(cells, { Text = "  " .. short .. " " })
  end

  table.insert(cells, { Foreground = { Color = P.comment } })
  table.insert(cells, { Text = "│ " })
  table.insert(cells, { Foreground = { Color = P.fg_dark } })
  table.insert(cells, { Text = wezterm.strftime("%H:%M") .. " " })

  window:set_right_status(wezterm.format(cells))
end)

return config
