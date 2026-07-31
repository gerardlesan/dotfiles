# CLAUDE.md

Guidance for Claude Code (claude.ai/code) working in this repository.

Read the whole file before your first edit. It is long because this config's
behaviour depends on a handful of non-obvious invariants, and every one of them
was discovered by something breaking.

---

## 1. What this repo is

A personal dotfiles repo whose only real payload is `nvim/` — a Lua-only Neovim
config targeting **Neovim 0.12+**, built for **Rust / Python / TypeScript**.

There is no application code, no build step and no test suite. **"Correctness"
here means: Neovim starts with no errors, `:checkhealth` is quiet, and the
startup time does not regress.** Section 8 is how you check that; do check it,
because a Lua config fails at *runtime* and a syntax-clean edit can still break
the editor for every future session.

Two installer scripts link `nvim/` into the platform's config location.

Remote is `github.com/gerardlesan/dotfiles.git`.

### Verified environment (ground truth as of 2026-07-29)

| Fact | Value |
|---|---|
| OS | CachyOS Linux, Wayland |
| Neovim | 0.12.4 |
| Terminal | **Ghostty 1.3.1** (`TERM=xterm-ghostty`) |
| Shell | `/usr/bin/zsh` — `'shell'` correctly inherits `$SHELL` on Linux |
| Rust | pacman `rust` 1:1.97.1 — **no rustup**; `rust-analyzer` from pacman |
| Font | `JetBrainsMono Nerd Font`, installed |
| Treesitter | 46 parsers built |
| Plugins | 52, pinned in `nvim/lazy-lock.json` |
| Leader mappings | 182 live in a plain buffer (more attach per-filetype) |
| Startup | ~280 ms median under a captured pty (5 samples, ~10 ms spread); ~180 ms real (see §8 on the 100 ms artifact) |

Do not trust environment claims in comments over what you can measure. If a
comment and the machine disagree, verify, then fix the comment as part of your
change.

### The terminal is Ghostty, and its config IS in this repo — but copied, not linked

`ghostty/config` → `~/.config/ghostty/config` — **no extension**. Ghostty reads
exactly `config` and silently ignores any other filename; a stray `config.ghostty`
is why this machine once ran a completely unconfigured terminal while Neovim
rendered its own palette. `install.sh` warns if that stray file is still present.

`starship/starship.toml` → `~/.config/starship.toml` (or `$STARSHIP_CONFIG`) works
the same way.

**Both are copied by `install.sh`, not symlinked, and only on Linux.** That is
deliberate: they are single files that get retuned live, and a symlink makes every
such experiment an uncommitted change in this repo. The repo is what you install
*from* — a local tweak has to be copied back by hand to survive. Consequence worth
remembering: **the file in `~/.config` may be ahead of the repo copy.** Diff before
assuming the repo version is what is running. `install.sh` backs up a differing
target with a timestamp and prompts unless `--force`.

`ghostty/config` **mirrors** the hex values in `nvim/lua/config/palette.lua`.
Ghostty cannot read Neovim's Lua, so the numbers are duplicated with a pointer
comment back. **Retune one, retune the other** — `background`, `foreground`,
`cursor-color`, `selection-*`, and `palette = 0..15` from `M.colors.terminal`.

Two settings there exist for reasons that live in this repo: `resize-overlay =
never` (Ghostty's size readout otherwise draws over a reflowing Neovim layout
mid-drag) and `shell-integration = fish`, matching the login shell
(`getent passwd $USER` → `/bin/fish`; note `$SHELL` in some spawned environments
still reads `/usr/bin/zsh`).

**Plain `CTRL+arrow` is deliberately unbound in Ghostty** — Neovim's split-resize
keys need it. Ghostty's defaults use `CTRL+SHIFT+arrow` and `CTRL+ALT+arrow`.

### Windows support is secondary but must not be deleted

The repo was built on Windows 11 / WezTerm and moved to Linux. Windows still
works and stays. **Keep** every `is_win` branch in `options.lua` (notably the
pwsh `'shell'` block), `install.ps1`, and `.gitattributes`' CRLF rule for
`*.ps1`. Do not extend, optimise or test the Windows paths unless asked.

---

## 2. Repo map

```
dotfiles/
├── CLAUDE.md                    this file
├── README.md                    dependency table, platform gotchas, known issues
├── install.sh    install.ps1    Linux/macOS symlink · Windows directory junction
├── .stylua.toml                 Lua formatter config (repo root, not nvim/)
├── .gitattributes               LF everywhere except *.ps1 (CRLF)
├── .gitignore                   ignores lua/config/local.lua; NOT lazy-lock.json
├── ghostty/config               terminal config; COPIED to ~/.config/ghostty/ (Linux)
├── starship/starship.toml       prompt config; COPIED to ~/.config/ (Linux)
├── docs/
│   ├── ADDING-A-LANGUAGE.md     five-edit worked example (Go) + how to add nvim-dap
│   └── KEYBINDINGS.md           convenience copy; live keymap table is the truth
└── nvim/
    ├── init.lua                 42 lines: fixes the load order, nothing else
    ├── lazy-lock.json           52 pinned commits — COMMITTED on purpose
    ├── lua/
    │   ├── config/
    │   │   ├── options.lua      1832 lines, 37 numbered sections, TOC at top
    │   │   ├── palette.lua      ALL colour + icon definitions
    │   │   ├── keymaps.lua      global keymaps only
    │   │   ├── autocmds.lua     14 active augroups, all prefixed cfg_
    │   │   ├── lazy.lua         plugin-manager bootstrap
    │   │   └── local.lua        GIT-IGNORED, per-machine, loaded last, wins
    │   ├── plugins/             one file per CONCERN (12 files)
    │   │   ├── colorscheme.lua completion.lua editor.lua explorer.lua
    │   │   ├── format.lua git.lua lint.lua lsp.lua
    │   │   ├── snacks.lua test.lua treesitter.lua ui.lua
    │   │   └── lang/            one file per LANGUAGE (rust, python, typescript)
    │   └── util/
    │       ├── folds.lua        fold text that keeps syntax highlighting + line count
    │       ├── incsel.lua       incremental selection (removed upstream, reimplemented)
    │       └── lspsync.lua      workaround: Neovim 0.12 stops tracking a buffer
    │                            after a server restart (see §5)
    ├── after/
    │   ├── lsp/                 per-server overrides (7 servers + README)
    │   └── ftplugin/            per-filetype buffer-local settings (14 fts + README)
    └── snippets/                README only; snippets come from friendly-snippets
```

`nvim/after/lsp/README.md`, `nvim/after/ftplugin/README.md` and
`nvim/snippets/README.md` state the rules for those directories. Read the
relevant one before adding a file there.

---

## 3. Commands

```bash
./install.sh                    # symlink ~/.config/nvim -> nvim/, copy ghostty +
                                # starship configs (Linux), report missing tools
./install.sh --tools            # ...and install system packages (apt/dnf/pacman/zypper/apk/brew)
./install.sh --tools --sync     # ...and install every plugin + treesitter parser
./install.sh --force            # replace an existing config without prompting
```

```powershell
.\install.ps1 -InstallTools -Sync   # Windows; creates a directory JUNCTION, not a symlink
```

Both back up an existing config with a timestamp and are safe to re-run.
`install.sh` is distro-first for Rust on Arch (pacman `rust-analyzer rust-src`)
because pacman's `rustup` **conflicts with** its `rust` package; it falls back to
`rustup component add` elsewhere.

**Never run `sudo` yourself.** Surface the command and let the user run it.

### Formatting

```bash
stylua nvim/
```

`stylua` is installed by **mason, inside Neovim** — it is frequently *not* on
`PATH`, and it is not in `~/.local/share/nvim/mason/bin/` until mason fetches it.
If it is absent, either open each edited file in Neovim and save (conform runs
stylua on `BufWritePre` for Lua) or hand-check against `.stylua.toml`: 2-space
indent, **120 columns**, double quotes, `require("x")` always parenthesised.

There is no "run a single test" for this repo. `<leader>t*` drives **neotest**
against whatever project the user has open — never against this repo.

---

## 4. Architecture

### 4.1 Load order is load-bearing

`nvim/init.lua` does nothing but fix the order of four requires. Each position
has a reason:

1. **`config.options`** — must be first. It sets `<leader>`, and a plugin spec
   declaring `<leader>x` resolves that key **at spec-load time**, so a leader set
   later silently mis-maps every plugin key. It also sets `'shell'` before
   lazy.nvim shells out to git.
2. **`config.lazy`** — bootstraps lazy.nvim, imports `lua/plugins/**`.
3. **`config.keymaps`** — editor-wide keymaps only.
4. **`config.autocmds`** — event-driven behaviour.

Then `config.local` is `pcall`-required — git-ignored, per-machine, loaded last
so it overrides everything. The `pcall` distinguishes "absent" (silent) from
"broken" (reports the error), so don't simplify it to a bare `pcall`.

### 4.2 How specs are discovered

`lazy.setup` in `config/lazy.lua` imports **two** directories explicitly:

```lua
spec = {
  { import = "plugins" },      -- concerns
  { import = "plugins.lang" }, -- languages
}
```

`import` reads only **one** directory level, which is why the language folder is
listed separately. Dropping a new file into either directory is enough — there is
no registration step. A third level would need a third `import` line.

### 4.3 Where a change belongs

| Change | File |
|---|---|
| any colour or icon | `lua/config/palette.lua` — the single source of truth |
| a Vim option | `lua/config/options.lua` (37 numbered sections, TOC at top) |
| a global keymap | `lua/config/keymaps.lua` |
| a **plugin's** keymap | that plugin's spec in `lua/plugins/` — keeps it lazy-loaded |
| a new plugin (general) | the matching concern file in `lua/plugins/` |
| a new plugin (one language) | `lua/plugins/lang/<lang>.lua` |
| a language server's settings | `after/lsp/<server>.lua` |
| enabling a language server | the `servers` list in `lua/plugins/lsp.lua` |
| shared LSP keymaps / capabilities | the `LspAttach` autocmd in `lua/plugins/lsp.lua` |
| indent / filetype-local keys | `after/ftplugin/<filetype>.lua` |
| which formatter runs | `lua/plugins/format.lua` (`formatters_by_ft`) |
| a non-LSP linter | `lua/plugins/lint.lua` (`linters_by_ft`) |
| a treesitter parser | the `parser_groups` table in `lua/plugins/treesitter.lua` |
| treesitter behaviour | the `ts` options table at the top of `lua/plugins/treesitter.lua` |
| a mason-installed tool | `ensure_installed` in `lua/plugins/lsp.lua` |
| an autocommand | `lua/config/autocmds.lua` |
| a terminal setting | `ghostty/config`, then re-run `install.sh` to push it out |
| the shell prompt | `starship/starship.toml`, same — it is copied, not linked |
| machine-specific anything | `lua/config/local.lua` (git-ignored) — never commit it |

`lua/plugins/*.lua` is one file per *concern*; `lua/plugins/lang/*.lua` is one
file per *language*. Keep that split: a Rust-only plugin in `editor.lua` is
misfiled even if it works.

### 4.4 The two `after/` mechanisms

Both exist because `after/` is read **last** on the runtimepath, so what you put
there always wins.

**`after/lsp/<server>.lua`** — Neovim deep-merges every `lsp/<name>.lua` on the
runtimepath, in order. nvim-lspconfig supplies the base (`cmd`, `filetypes`,
`root_markers`) for ~300 servers; this repo supplies **only** `settings` /
`init_options` / `on_attach`. That is why enabling a language is one small file
plus one line in `servers`. Only 7 of the 13 enabled servers need a file at all —
if the defaults are right, don't create one.

**`after/ftplugin/<filetype>.lua`** — runs after built-in and plugin ftplugins.
Use `vim.bo` / `vim.wo` / `vim.opt_local` **only** (never `vim.opt`, which is
global and leaks into every other buffer) and pass `buffer = 0` on every keymap.

### 4.5 LSP is native, not `lspconfig.setup{}`

`vim.lsp.config()` + `vim.lsp.enable()` — the Neovim 0.12 API. **Tutorial code
using `require("lspconfig").<server>.setup{}` does not belong here.**

A single `LspAttach` autocmd in `lua/plugins/lsp.lua` installs every shared
keymap (`gd`, `gr`, `K`, `<leader>ca`, …), each gated on
`client:supports_method(...)` so a key is only mapped when the server can answer
it, and enables inlay hints, codelens, document highlight and LSP folding.
Language-specific `on_attach` handlers **add to** this — they never replace it.

Enabled servers (13): `lua_ls`, `basedpyright`, `ruff`, `vtsls`, `eslint`,
`jsonls`, `yamlls`, `taplo`, `bashls`, `marksman`, `html`, `cssls`, `dockerls`.
`rust_analyzer` is **not** in that list — see §5.

`vim.lsp.config("*")` advertises `didChangeWatchedFiles.dynamicRegistration =
true` to *every* server. That is a real trade-off: a server taking it up routes
file watching through Neovim's `vim._watch`, which with no `fswatch`/
`inotifywait` binary degrades to a libuv recursive poll written in Lua. Kept on
because vtsls needs it; opt individual servers out server-side instead (see
rust-analyzer's `files.watcher = "server"`).

### 4.6 Formatting and linting are separate systems

- **conform.nvim** (`lua/plugins/format.lua`) owns formatting: `stylua` for Lua,
  `ruff_organize_imports` **then** `ruff_format` for Python (order matters —
  reversing it reformats imports that are about to be reordered), `prettierd`
  with a `prettier` fallback and `stop_after_first` for the web stack, `rustfmt`
  for Rust, `shfmt` for shell.
- **nvim-lint** (`lua/plugins/lint.lua`) owns only what no LSP covers:
  `shellcheck` for sh/bash, `markdownlint-cli2` for markdown. Python, TS, Lua,
  JSON, YAML and Rust are deliberately **absent** — their language servers
  already report those diagnostics, and adding them here double-reports every
  problem. That exclusion list is documented in the file; read it before adding.

### 4.7 Palette is the single source of colour

`lua/config/palette.lua` exports `M.colors` (backgrounds, foregrounds, the red
accent family, syntax hues, diagnostics, git, and `terminal` ANSI 0-15),
`M.style`, type-kind colours, `M.border` and the icon tables. Everything
downstream — statusline, borders, syntax, git signs, `:terminal` colours —
derives from it. **Never hard-code a hex value in a plugin spec.**

The theme is Tokyonight "night", warm-shifted and re-accented around a gentle
red, with two design rules worth preserving: red owns *chrome and control flow*
(borders, cursor, mode, keywords), and red does **not** own *data* (strings stay
green, numbers orange). `error` is intentionally a different, more saturated red
than `accent` so a diagnostic never reads as a keyword.

---

## 5. Deliberate configuration that looks like a bug

**Touching any of these re-breaks something that was fixed by testing.** Each
carries a comment in-place; if you change one, update the comment and this list.

- **`rust_analyzer` is absent from the `servers` list.** rustaceanvim
  (`lua/plugins/lang/rust.lua`) owns it completely — it must control
  initialisation to provide expand-macro, runnables and debugging. Enabling it in
  `lsp.lua` too starts a second, conflicting client. The single most common
  Rust-on-Neovim misconfiguration. `:checkhealth rustaceanvim` reports "No
  conflicting plugins detected" when this is right.

- **rustaceanvim is `ft = { "rust" }`, NOT `lazy = false`.** It used to carry
  both; `lazy = false` wins, so the `ft` was dead and rustaceanvim loaded when
  you opened a Python file. Its entire body is a `config` that assigns
  `vim.g.rustaceanvim`, and lazy.nvim's `ft` handler runs before rustaceanvim's
  own `FileType` hook, so `ft` suffices. If rust_analyzer ever stops attaching,
  restore `lazy = false` and delete the `ft` line — correctness beats the
  fraction of a millisecond.

- **Never set both `lazy = false` and `ft`/`event` on one spec.** `lazy = false`
  wins silently and the other key is dead weight that reads as intent.

- **blink.cmp has no `dependencies` on LuaSnip / friendly-snippets.**
  `lsp.lua` does `pcall(require, "blink.cmp")` for `get_lsp_capabilities`, which
  makes lazy.nvim load blink at `BufReadPre`; a `dependencies` line would drag
  the snippet engine onto that path too (~26 ms per buffer read) for something
  not needed until the first completion. Safe because blink requires LuaSnip
  lazily at function-call time inside
  `sources/snippets/luasnip.lua`. `snippets = { preset = "luasnip" }` is what
  wires them. **If snippets stop appearing in the menu, this is the regression** —
  restore the line.

- **`mason-lspconfig`'s `automatic_enable = false`.** With it on, mason's
  installed `stylua` got started as a *language server* (nvim-lspconfig ships an
  `lsp/stylua.lua` for its experimental `--lsp` mode), giving two format-capable
  clients competing with conform. Mason installs; the explicit `servers` list
  decides what runs.

- **nvim-treesitter is on the `main` branch** — a rewrite with a different API:
  `require("nvim-treesitter").install{}` (no `ensure_installed`),
  `vim.treesitter.start()` in a `FileType` autocmd (no `highlight = {enable=true}`),
  `'indentexpr'` set per buffer, no lazy-loading support (`lazy = false`), and it
  needs the `tree-sitter` CLI ≥ 0.26.1 plus a C compiler on `PATH`. **Tutorial
  snippets written for `master` will error.** Incremental selection was removed
  upstream and is reimplemented in `lua/util/incsel.lua`.

- **Parsers are declared in exactly one place**: the `parser_groups` table in
  `lua/plugins/treesitter.lua`. The `lang/*.lua` files used to each append an
  `optional = true` nvim-treesitter spec calling `install()`; lazy.nvim runs every
  merged `opts` function, so that loaded `nvim-treesitter.parsers` repeatedly at
  startup and split one concern across four files. Those specs are gone — add to
  `parser_groups` instead.

- **The dashboard's git section is `section = "terminal"`, not `"git"`.** There is
  **no `git` section in snacks** (the real list is header, keys, projects,
  recent_files, session, startup, terminal). Naming one makes `dashboard.lua` call
  a nil section function, which: leaves the start screen an **empty buffer**,
  re-throws on **every terminal resize** (the dashboard re-runs `update()` on
  `WinResized`/`VimResized`), and aborts the rest of snacks' `UIEnter` batch —
  ordered `{ dashboard, scroll, input, scope, picker }` — so scroll, input, scope
  and picker setup are all skipped. It only broke inside a git repo, because the
  section's `enabled` guard is evaluated first. Shell output goes through
  `terminal` with `cmd` + a `ttl` (it caches stdout on disk keyed by cmd+cwd).
  **One bogus string caused four separate user-visible symptoms** — treat a
  missing dashboard as a section-name bug first.

- **conform's format-on-save toggles are registered in `init`, not `config`.**
  conform lazy-loads on `BufWritePre`, so `config` doesn't run until the first
  save — `<leader>uf` would silently do nothing for most of a session.

- **Python runs two servers on purpose**: `basedpyright` for types, `ruff` for
  lints. `after/lsp/ruff.lua` disables ruff's hover and definition providers so
  `K` is deterministic. Apply the same pattern to any overlapping pair.

- **rust-analyzer gets its own `cargo.targetDir`.** `check.command = "clippy"`
  otherwise runs `cargo clippy` into the same `target/` as the user's
  `cargo build`; the two have different flags, so they evict each other's
  fingerprints and *every* analysis is a near-full rebuild. Costs disk, saves
  minutes. `files.watcher = "server"` and `check.workspace = false` are there for
  related reasons — see the comments.

- **`snacks.image.math.enabled` is gated on `tectonic`/`pdflatex`.** This does
  **not** quieten `:checkhealth` — snacks' `M.health()` probes for
  tectonic/pdflatex and `mmdc` unconditionally and never reads `math.enabled`.
  The gate exists so a markdown file full of `$…$` doesn't fire one failed
  conversion plus one notification per expression. Don't "fix" the healthcheck
  from here.

- **The `VimResized` handler skips floating windows and `pcall`s `tabdo`.**
  `wincmd =` would discard deliberate float sizing (neo-tree's, oil's), and
  `tabdo` fires autocmds in every tab, so one throwing plugin could leave the
  layout half-updated with the cursor in the wrong tab. `equalalways = false` in
  `options.lua` is deliberate and does not conflict — `wincmd =` equalises on
  demand regardless.

- **`rocks = { enabled = false }`** in `config/lazy.lua` — luarocks provisioning
  is a reliable source of Windows pain; every plugin here is pure Lua or ships
  prebuilt binaries. Kept off on Linux for parity.

- **Nerd Font glyphs are written as `\u{...}` Lua escapes**, never pasted
  literally — Private Use Area characters get eaten by editors, git filters and
  terminals, leaving an empty string that fails at runtime.

- **`lazy-lock.json` is committed** and explicitly un-ignored. It is what makes a
  fresh clone reproduce the same editor. Do not touch it beyond what `Lazy sync`
  legitimately writes, and do not hand-edit it.

- **`.gitattributes` forces LF everywhere except `*.ps1` (CRLF).** Without it a
  Windows clone with `autocrlf=true` gives `install.sh` a
  `#!/usr/bin/env bash\r` shebang and a "bad interpreter" error on Linux.

- **`lua/util/lspsync.lua` attaches a second `nvim_buf_attach` per LSP buffer**,
  which looks redundant next to the one `runtime/lua/vim/lsp.lua` already
  installs. It is a workaround for an upstream 0.12 bug, and it does nothing
  unless that first callback disappears. Edit a buffer while its last client is
  gone (crashed server, `:LspRestart`) and lsp.lua's `on_lines` returns `true` to
  detach itself — but a buffer callback that detaches that way never fires
  `on_detach` (verified), so lsp.lua's `attached_buffers[bufnr]` is never
  cleared and the next attach skips `nvim_buf_attach` entirely. From then on
  `vim.lsp.util.buf_versions[buf]` is frozen and no `didChange` is sent: the
  server silently works from stale text, and the inlay-hint decoration provider —
  whose only guard is `bufstate.version ~= util.buf_versions[bufnr]` — starts
  throwing `Invalid 'col': out of range` on every redraw. Reproduced end to end
  against the real config and rust-analyzer: with the shim stubbed out, 3 errors
  and `buf_versions` frozen; with it, 0 errors and tracking restored. Gated on
  `< 0.13` out of caution about the private module it uses — but note that master
  fixed only the inlay-hint half (neovim/neovim#40569); the self-detach is still
  there, so on 0.13 the bug goes quiet rather than away. Re-test before removing
  the gate; the file says how. **Symptom to recognise: `:e` fixes it temporarily,
  closing and reopening the buffer fixes it properly.**

---

## 6. Conventions

- **Comments explain *why*, at length.** Every non-trivial decision here carries a
  comment saying what was tried and what broke. `options.lua` documents options it
  deliberately leaves *off*, with the reason, in the same numbered sections as the
  active ones. **Match this density.** A bare setting change with no rationale is
  out of place, and will read to the next agent as an accident.
- **Say what you verified.** "Verified against the installed version", "probed
  `M.sections` — no `git` key", "median of 5 samples, 280 ms" is the house style.
  Claims without evidence are what this file exists to prevent. **Startup numbers
  vary ~10 ms run to run — take a median of several samples, never one reading, or
  you will report noise as a win.**
- **No key is both a mapping and a prefix.** That forces a `timeoutlen` wait on
  every keystroke beneath it. Enforced across all 182 leader mappings — check with
  `<leader>sk` before adding one.
- **Leader layout matches LazyVim**, so ecosystem answers' keybindings are already
  correct. `<leader>` = Space. `<localleader>` = `\`, reserved for filetype-local
  commands. The busiest groups are `<leader>s` (30, search), `<leader>u` (27,
  toggles), `<leader>g` (19, git), `<leader>c` (18, code).
- **Lua style** from `.stylua.toml` at the repo root: 2-space indent, 120 columns,
  double quotes, `require("x")` always parenthesised, `sort_requires` off.
- **Plugins are `lazy = true` and `version = false`** by default (track the default
  branch); reproducibility comes from the lockfile, not tags. Specs that must load
  eagerly say `lazy = false` themselves — currently **four**: `tokyonight`
  (colorscheme, plus high `priority` so it applies before anything else draws),
  `nvim-treesitter` (its `main` branch does not support lazy-loading), `snacks`
  (it owns `UIEnter` behaviour), and `oil` (so `nvim .` opens oil rather than an
  empty buffer). Pin a `version` only when there's a stated reason — blink.cmp
  pins `1.*` because tagged releases ship prebuilt Rust matcher binaries.
- **Prefer `event`/`ft`/`keys`/`cmd` over `lazy = false`.** If you add an eager
  spec, justify it in a comment.
- Augroups in `autocmds.lua` are created via the local `augroup()` helper, which
  prefixes `cfg_` and sets `clear = true`. Use it rather than
  `nvim_create_augroup` directly.

---

## 7. Recipes

### Add a plugin
1. Pick the file: concern → `lua/plugins/<concern>.lua`; single language →
   `lua/plugins/lang/<lang>.lua`.
2. Write the spec with a lazy trigger (`event` / `ft` / `keys` / `cmd`) and a
   comment saying what it's for and why it was chosen over the obvious
   alternative.
3. Keymaps go in the spec's `keys`, not `keymaps.lua`, so the plugin stays lazy.
4. Colours from `palette.lua`; no literal hex.
5. `nvim --headless "+Lazy! sync" +qa`, then verify per §8. Commit the
   `lazy-lock.json` change with it.

### Add a language
`docs/ADDING-A-LANGUAGE.md` is the worked example (Go), and it is accurate.
Short form — five edits:
1. `lua/plugins/lsp.lua` — add the server to `servers`.
2. `after/lsp/<server>.lua` — only if defaults need overriding.
3. `lua/plugins/treesitter.lua` — add parsers to `parser_groups`.
4. `lua/plugins/format.lua` / `lint.lua` — formatter, and a linter only if no LSP
   covers it.
5. `after/ftplugin/<ft>.lua` — indent and filetype-local keys.

### Add or change an option
Find the right numbered section in `options.lua` (TOC at the top), follow the
existing entry style — `(default: x)` plus `[global]`/`[window]`/`[buffer]` — and
say why. If you are turning something *off*, leave the commented-out line with the
reason rather than deleting it.

### Change a colour
Edit `palette.lua` only, then mirror any of the terminal-relevant values into
`~/.config/ghostty/config`. Check the result with `<leader>ui` (highlight groups
under the cursor).

---

## 8. Verifying a change

A clean `git diff` proves nothing here. Work through as much of this as your
change touches.

**1. It loads at all** (catches syntax errors and load-order breakage):

```bash
nvim --headless "+lua print('ok')" +qa
```

**2. Health:**

```bash
nvim --headless "+checkhealth" "+w! /tmp/health.txt" +qa
rg -n 'ERROR|WARNING' /tmp/health.txt
```

**Four `:checkhealth` failures are headless-only artifacts** — `UIEnter` never
fires without a UI: `Snacks.dashboard: setup did not run`, `vim.ui.input is not
set to Snacks.input`, `vim.ui.select is not set`, and `your terminal does not
support the kitty graphics protocol`. All four are fine in a real terminal.

Expected-and-intentional: the `nvim-dap is configured, but not installed` warning
(documented opt-out), the five missing image parsers (`latex`, `norg`, `svelte`,
`typst`, `vue`), and the `tectonic`/`pdflatex`/`mmdc` errors (§5).

`:checkhealth rustaceanvim` needs a **Rust buffer open** — it is `ft = "rust"`, so
otherwise its section is simply absent.

**3. Anything UI-dependent needs a pty.** Dashboard, `vim.ui.*`, snacks
integrations and resize behaviour cannot be tested headless. Wrap it:

```bash
cat > /tmp/probe.lua <<'EOF'
local f = io.open("/tmp/probe.txt","w")
vim.defer_fn(function()
  f:write("dashboard lines: "..#vim.api.nvim_buf_get_lines(0,0,-1,false).."\n")
  f:close(); vim.cmd("qa!")
end, 3000)
EOF
timeout 40 script -qec "nvim -c 'luafile /tmp/probe.lua'" /dev/null >/dev/null 2>&1
cat /tmp/probe.txt
```

**Test the dashboard from inside a git repo.** Its `enabled` guard is
`Snacks.git.get_root() ~= nil`, so a whole class of bug is invisible outside one.

**4. Startup, before *and* after, same command both times:**

```bash
cd /tmp/rsproj && script -qec "nvim --startuptime /tmp/st.log src/main.rs -c 'qa!'" /dev/null >/dev/null 2>&1
grep 'NVIM STARTED' /tmp/st.log | tail -1
grep -E '^[0-9]' /tmp/st.log | awk '{print $3, $0}' | sort -rn | head -12 | cut -d' ' -f2-
```

**Subtract ~100 ms from every pty number.** Neovim 0.12 probes `'background'`
with OSC 11 + DSR and `vim.wait(100, ...)` for the reply; a captured pty never
answers, so it burns the full budget. Ghostty answers in about a millisecond.
This happens in `vim/_core/defaults.lua` before any user config loads and
**cannot be disabled from `options.lua`** — setting `opt.background` does not
help, because the guard there ignores values set from Lua (`last_set_sid == -8`).
`nvim --clean` shows the same 100 ms, which is how you confirm it isn't this
config. Don't chase it.

To check *what* loaded, dump `require("lazy.core.config").plugins[*]._.loaded` —
that is how the eager-rustaceanvim and eager-LuaSnip problems were found.

**5. Formatting:** `stylua nvim/` if available, else save in Neovim (§3).

---

## 9. Diagnosing

`:checkhealth` · `:verbose set <opt>?` (the value **and** the file that set it) ·
`:Lazy` / `:Lazy profile` · `:Mason` · `:checkhealth vim.lsp` · `:LspLog` ·
`:ConformInfo` · `:CheckIcons` · `<leader>sk` (fuzzy-search the live keymap
table — the source of truth, not `docs/KEYBINDINGS.md`) · `<leader>ui`
(highlight groups under cursor) · `<leader>uI` (live parse tree).

Common causes, in the order they are usually true:

- **A server never attaches** → its binary is missing from `PATH` (check
  `:Mason`), or no `root_markers` matched.
- **Missing highlighting** → a parser that failed to compile
  (`:checkhealth nvim-treesitter`); needs `tree-sitter` CLI and a C compiler.
- **A keymap does nothing** → something else claimed it (`:verbose map <lhs>`), or
  the owning plugin never loaded (`:Lazy`).
- **An option is not what you set** → `:verbose set foo?` names the last file to
  write it; suspect `after/ftplugin/` (buffer-local) and `config/local.lua`.
- **A plugin loads too early** → someone `require`d it from another spec's
  `config`; lazy.nvim intercepts that `require` and loads it there.
- **The start screen is empty or errors on resize** → a bogus snacks section name
  (§5).

---

## 10. Non-goals

- Do not add or remove plugins, or change keymaps or option *values*, unless
  asked. This config is tuned; drive-by "improvements" are regressions.
- Do not trim `options.lua`'s commented-out alternatives or "deliberately off"
  prose. That density is a stated convention, not clutter.
- Do not delete the Windows branches or `install.ps1` (§1).
- Do not hand-edit `lazy-lock.json`.
- Do not commit `lua/config/local.lua` — it is git-ignored on purpose.
- Do not run `sudo`; surface the command instead.
- Do not chase the 100 ms OSC-11 startup artifact or the four headless
  `:checkhealth` failures (§8). Both are already understood.
