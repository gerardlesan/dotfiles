# dotfiles — Neovim + Ghostty

A cross-platform, Lua-only Neovim configuration built for Rust, Python and
TypeScript, with a warm red-accented Tokyonight theme matched between the editor
and the terminal.

Developed on Windows 11, now running on Linux (CachyOS, Wayland, Ghostty) — the
move was one script. Windows support remains, but Linux is the primary target.

```
Neovim 0.12+ · lazy.nvim · 52 plugins · ~180 ms startup · zero vimscript
```

---

## What you get

| Requirement | How |
|---|---|
| **File exploring** | [neo-tree](https://github.com/nvim-neo-tree/neo-tree.nvim) sidebar (`<leader>e`) + [oil.nvim](https://github.com/stevearc/oil.nvim) filesystem-as-a-buffer (`-`) |
| **Image viewing** | `snacks.image` via the Kitty graphics protocol — inline in markdown, or floating (`<leader>ii`) |
| **Completion + Intellisense** | [blink.cmp](https://github.com/Saghen/blink.cmp) + native `vim.lsp.config`, with inlay hints, auto-import and signature help |
| **Easy new language** | one file in `after/lsp/`, one line in a list. See [docs/ADDING-A-LANGUAGE.md](docs/ADDING-A-LANGUAGE.md) |
| **Keybinding screen** | [which-key](https://github.com/folke/which-key.nvim) — press `<Space>`, or `<leader>sk` to fuzzy-search all 168 mappings |
| **Status bar** | [lualine](https://github.com/nvim-lualine/lualine.nvim) — branch, diff counts, diagnostics, path, language, LSP client names, venv, indent style, encoding warnings |

Plus the things that are standard in this kind of setup: fuzzy picker, treesitter,
git integration at three levels, format-on-save, linting, a test runner, sessions,
project-wide search-and-replace, a symbol outline, a diagnostics panel, and a
dashboard.

## Design decisions worth knowing

- **Everything is commented.** `lua/config/options.lua` documents *every*
  meaningful Vim option grouped by purpose — including the ones deliberately left
  off, and a final section on legacy options you should never copy from an old
  vimrc. It is the reference, not just the settings.
- **Red owns control flow, not data.** Keywords, operators, borders, the cursor and
  the mode indicator are red; strings stay green and numbers orange. A config where
  everything is one hue photographs well and is miserable to read code in.
- **Types are "marked" individually, VS Code style, and never italic.** Most themes
  collapse every kind of type onto one `Type` colour, so a struct, an enum, a trait,
  a type alias and a generic parameter all look identical — the highlighting tells
  you "this is a type" and nothing more. This config styles the language server's
  *semantic tokens* instead, so each kind gets its own hue, declarations are bold,
  `mut` bindings are underlined and `unsafe` gets an undercurl. The mapping was
  derived by dumping the 47 groups rust-analyzer actually emits, not guessed.
  See `lua/config/palette.lua` (`M.types`) to retune.
- **No key is both a mapping and a prefix.** That combination forces Neovim to wait
  out `timeoutlen` on every keystroke beneath it. Enforced across all 168 leader
  mappings — there is a checker script in the repo history.
- **The leader layout matches LazyVim.** Not for compatibility, but because it is
  the most documented keymap set in the ecosystem: when you search for how to do
  something, the answer's keybinding is usually already correct here.
- **Explicit over automatic.** For example `mason-lspconfig`'s `automatic_enable` is
  off, because it silently started `stylua --lsp` as a language server on every Lua
  buffer. Mason installs; the config decides what runs.

---

## Install

### Windows

```powershell
git clone <this-repo> $env:USERPROFILE\dotfiles
cd $env:USERPROFILE\dotfiles
.\install.ps1 -InstallTools -Sync
```

Creates a **directory junction** from `%LOCALAPPDATA%\nvim` to `nvim/`. A junction
rather than a symlink because symlinks on Windows need Administrator or Developer
Mode; junctions need neither.

### Linux / macOS

```bash
git clone <this-repo> ~/dotfiles
cd ~/dotfiles
./install.sh --tools --sync
```

Symlinks `~/.config/nvim` to `nvim/`. Detects apt / dnf / pacman / zypper / apk /
brew and installs the right package names for each — which differ more than you'd
expect (see the `fd-find` note below).

Both scripts back up an existing config with a timestamp before replacing it, and
both are safe to re-run.

### Ghostty

The terminal config is a single file and is **not** in this repo:

```
~/.config/ghostty/config
```

**The filename matters**: Ghostty reads exactly `config`, with no extension. A
file called `config.ghostty` is ignored without a warning, which leaves the
terminal on its stock theme and font while Neovim renders its own palette — the
mismatch shows up as "the colours are wrong outside nvim".

It mirrors the hex values from `nvim/lua/config/palette.lua` (`background`,
`foreground`, `cursor-color`, `selection-*`, and `palette = 0..15` from
`M.colors.terminal`). Ghostty cannot read Neovim's Lua, so the numbers are
repeated there with a pointer back. **Retune one, retune both.** Reload with
`ctrl+shift+,`.

Two settings there are worth knowing about: `resize-overlay = never`, because
Ghostty's live size readout otherwise draws over a Neovim layout that is itself
reflowing mid-drag, and `shell-integration = zsh`, which is what makes
`window-inherit-working-directory` work.

---

## Dependencies

Installed automatically by the scripts. Listed so you know what each is *for* —
skipping one degrades a specific feature rather than breaking the editor.

| Tool | Needed for | Without it |
|---|---|---|
| **Neovim ≥ 0.12** | everything | config will not load — needs `vim.lsp.config` and treesitter `main` |
| git | lazy.nvim clones plugins | nothing works |
| **C compiler** | compiling treesitter parsers | no syntax highlighting beyond the 7 bundled parsers |
| **tree-sitter CLI ≥ 0.26.1** | ditto | same |
| ripgrep | grep picker, `:grep` | project search unavailable |
| fd | file picker, venv detection | picker falls back to a slower walker |
| Node.js | TypeScript LSP, prettier, jest | no TS support |
| a Nerd Font | all icons | hollow boxes everywhere — test with `:CheckIcons` |
| ImageMagick | non-PNG image conversion | only PNGs render |
| lazygit | `<leader>gg` | use gitsigns and diffview instead |
| `rust-analyzer` + `rust-src` | Rust | no Rust support |
| fswatch *(optional)* | native LSP file watching | Neovim's `vim._watch` falls back to a recursive poll written in Lua |

**rust-analyzer comes from your distro or from rustup, never from mason.** Two
routes, and on a distro that packages Rust itself the distro route is the only
one that works:

```bash
sudo pacman -S rust-analyzer rust-src lazygit   # Arch / CachyOS
rustup component add rust-analyzer rust-src clippy rustfmt   # everywhere else
```

On Arch, pacman's `rustup` **conflicts with** its `rust` package, so if you have
`rust` installed then `rustup component add` is not available to you. Either way
`rust-src` is what makes go-to-definition jump into the standard library, and
Arch's `rust` package does not ship it.

On **Windows** the C compiler is [zig](https://ziglang.org) — a single executable
that nvim-treesitter uses as `zig cc`, avoiding a full MSVC PATH setup.

Platform gotchas the scripts handle for you:

- **Debian/Ubuntu**: the `fd` package is `fd-find` and installs the binary as
  `fdfind`. `install.sh` symlinks a `fd` into `~/.local/bin`.
- **Debian stable**: ships a Neovim far older than 0.12. `install.sh` fetches the
  official AppImage instead.
- **tree-sitter CLI** is packaged almost nowhere and needs `libclang` to build from
  source, so both scripts download the prebuilt release binary.
- **Clipboard on Linux**: needs `wl-clipboard` (Wayland) or `xclip`/`xsel` (X11).
  Over SSH it needs nothing — Neovim 0.10+ falls back to OSC 52 and Ghostty
  supports it, so yanking over SSH lands in your local clipboard.

---

## Layout

```
dotfiles/
├── install.ps1            Windows installer (junction)
├── install.sh             Linux/macOS installer (symlink)
├── .stylua.toml           formats this repo's Lua
├── docs/
│   ├── ADDING-A-LANGUAGE.md
│   └── KEYBINDINGS.md
└── nvim/
    ├── init.lua           entry point — fixes module load ORDER, nothing else
    ├── lazy-lock.json     every plugin pinned to a commit  ← commit this
    ├── lua/
    │   ├── config/
    │   │   ├── palette.lua    ALL colours and icons — the one file to retheme
    │   │   ├── options.lua    every Vim option, documented and classified
    │   │   ├── keymaps.lua    global keymaps
    │   │   ├── autocmds.lua   event-driven behaviour
    │   │   └── lazy.lua       plugin-manager bootstrap
    │   ├── util/
    │   │   ├── incsel.lua     incremental selection (upstream module was deleted)
    │   │   └── folds.lua      treesitter-highlighted foldtext + line count
    │   └── plugins/
    │       ├── colorscheme.lua  snacks.lua    ui.lua       explorer.lua
    │       ├── editor.lua       treesitter.lua lsp.lua     completion.lua
    │       ├── format.lua       lint.lua      git.lua      test.lua
    │       └── lang/            rust.lua  python.lua  typescript.lua
    ├── after/
    │   ├── lsp/           one file per language server (see its README)
    │   └── ftplugin/      one file per filetype (see its README)
    └── snippets/          your own snippets, VS Code JSON format
```

Two ideas do most of the organisational work:

**`after/lsp/<server>.lua`** — Neovim merges every `lsp/<name>.lua` on the
runtimepath in order, and `after/` is read last. So nvim-lspconfig supplies the
boring base (`cmd`, `filetypes`, `root_markers`) for ~300 servers and you supply
only `settings`. Adding a language is one small file.

**`after/ftplugin/<filetype>.lua`** — runs after every other ftplugin, so your
indent width and local keymaps always win.

---

## Where things live

Want to change… | Edit
---|---
the colours | `nvim/lua/config/palette.lua`
an editor option | `nvim/lua/config/options.lua` (find it by category)
a global keybinding | `nvim/lua/config/keymaps.lua`
a plugin's keybinding | that plugin's file in `lua/plugins/` (keeps it lazy-loaded)
a language server's settings | `nvim/after/lsp/<server>.lua`
indent width for a language | `nvim/after/ftplugin/<filetype>.lua`
which formatter runs | `nvim/lua/plugins/format.lua`
per-type-kind colours (struct vs enum vs trait) | `nvim/lua/config/palette.lua` → `M.types`
italics on/off | `nvim/lua/config/palette.lua` → `M.style.italic_comments`
rainbow brackets, folds, sticky context, incremental selection | the `ts` options table at the top of `nvim/lua/plugins/treesitter.lua`
add/remove a plugin | the relevant `lua/plugins/*.lua`, then `:Lazy sync`

Machine-specific overrides go in `nvim/lua/config/local.lua`, which is
git-ignored and sourced last so it can override anything.

---

## Debugging

| Command | Tells you |
|---|---|
| `:checkhealth` | everything that is missing or misconfigured |
| `:CheckIcons` | whether your font renders the Nerd Font glyphs |
| `:verbose set shiftwidth?` | the value **and which file last set it** |
| `:Lazy` / `:Lazy profile` | plugin status; what is slowing down startup |
| `:Mason` | installed servers, formatters and linters |
| `:checkhealth vim.lsp` | attached clients, their roots and capabilities |
| `:LspLog` | why a server exited |
| `:ConformInfo` | which formatter will run in this buffer |
| `<leader>ui` | highlight groups under the cursor — for theming |
| `<leader>uI` | live treesitter parse tree |

Most-likely first causes: a server that never attaches is usually a binary missing
from `PATH` (check `:Mason`) or no `root_markers` matching; missing highlighting is
usually a parser that failed to compile (`:checkhealth nvim-treesitter`).

## Known issues

- **Inline images need a terminal with full Kitty-graphics support.** Ghostty and
  Kitty have it. WezTerm's implementation is partial (no Unicode placeholders), so
  inline images inside a scrolling document can leave artefacts — press `<C-l>` to
  redraw; float mode (`<leader>ii`) is reliable. Nothing else in this config is
  terminal-specific.
- **A treesitter parser can fail with `EPERM: could not rename temp` on Windows.**
  A race with antivirus scanning the freshly extracted files. Just run
  `:TSInstall <lang>` again. The `gitcommit` grammar hits this most often because
  it ships a `.wasm` blob.
- **`vim.lsp.get_buffers_by_client_id() is deprecated`** appears once in Rust
  buffers. Upstream in rustaceanvim, harmless, will resolve on a plugin update.
- **Debug adapters (nvim-dap) are not installed** by choice. `<leader>d` is
  reserved for them and `<leader>rd` in Rust is already wired; see
  [docs/ADDING-A-LANGUAGE.md](docs/ADDING-A-LANGUAGE.md) for adding it.
  `:checkhealth rustaceanvim` reports one warning about this — expected.
- **`:checkhealth snacks` reports errors for optional image converters.** All are
  safe to ignore unless you want that specific format; images themselves work.

  | Reported missing | Only needed for | Install if you want it |
  |---|---|---|
  | `gs` (ghostscript) | rendering PDFs inline | `winget install ArtifexSoftware.GhostScript` / `apt install ghostscript` |
  | `pdflatex` / `tectonic` | rendering LaTeX math in markdown | a TeX distribution |
  | `mmdc` | rendering Mermaid diagrams | `npm i -g @mermaid-js/mermaid-cli` |
  | kitty graphics protocol | — | reported only when run headless; Ghostty supports it |

  The LaTeX and Mermaid errors **cannot be configured away**: snacks' image
  healthcheck probes for `tectonic`/`pdflatex` and `mmdc` unconditionally and never
  consults `math.enabled`, so setting it changes nothing here. Install a TeX
  distribution and `mmdc` if you want them gone. `math.enabled` in the `image`
  block of `nvim/lua/plugins/snacks.lua` *is* gated on that tooling, for a
  different reason: without it, a markdown file full of `$…$` would otherwise fire
  one failed conversion and one notification per expression.

- **`:checkhealth snacks` warns about missing Treesitter languages** — `latex`,
  `norg`, `svelte`, `typst`, `vue`. That is snacks.image listing parsers it *could*
  use for inline rendering. Left as-is deliberately: installing five parsers for
  languages that are never edited here is worse than one warning. Add them to
  `parser_groups` in `nvim/lua/plugins/treesitter.lua` if you disagree.

- **Four `:checkhealth` complaints are headless-only artifacts.**
  `Snacks.dashboard: setup did not run`, `vim.ui.input is not set to Snacks.input`,
  `vim.ui.select is not set`, and the kitty-graphics one all come from `UIEnter`
  never firing without a UI. Run `:checkhealth` inside Neovim, not via
  `nvim --headless`, and they are absent.

- **Startup looks ~100 ms slower under a bare pty than it really is.** Neovim 0.12
  probes `'background'` with OSC 11 + DSR and `vim.wait(100, ...)` for the reply;
  a captured pty never answers, so it burns the whole budget. Ghostty answers in
  about a millisecond. This happens in `vim/_core/defaults.lua` before any user
  config loads and cannot be disabled from `options.lua` — setting
  `opt.background` does not help, because the guard there ignores values set from
  Lua. `nvim --clean` shows the same 100 ms, which is how you confirm it is not
  this config.

## Alternatives, if you disagree with a choice

- **Picker**: `snacks.picker` is used instead of [telescope](https://github.com/nvim-telescope/telescope.nvim)
  because telescope's fast sorter is a C extension needing make/cmake — a recurring
  Windows problem. Telescope is more widely documented; swap it into
  `lua/plugins/snacks.lua` if you prefer.
- **Completion**: `blink.cmp` instead of `nvim-cmp`. nvim-cmp needs one plugin per
  source; blink bundles them.
- **Python LSP**: `basedpyright` is a stricter fork of `pyright`. Change one string
  in `lua/plugins/lsp.lua` to go back.
- **TypeScript LSP**: `vtsls` instead of `ts_ls`, for working inlay hints and better
  monorepo handling.

---

## License

MIT — see [LICENSE](LICENSE).
