# Keybindings

**This file is a convenience, not the source of truth.** The live keymap table is,
and there are three ways to read it inside the editor:

| Key | Shows |
|---|---|
| `<Space>` | which-key panel — drill down group by group |
| `<leader>?` | every mapping active in **this buffer**, including LSP ones |
| `<leader>sk` | fuzzy-**search** all mappings by description |
| `<F1>` | the full panel |

Use `<leader>sk` when you know what you want to do but not which key does it. Use
`<leader>?` when a mapping only exists in some buffers (LSP, filetype-local).

`<leader>` = **Space**. `<localleader>` = **`\`** (backslash), reserved for
filetype-specific commands.

168 leader mappings, plus the non-leader ones below.

---

## Leader groups

```
<leader><space>  find files            <leader>b  Buffer
<leader>/        grep project          <leader>c  Code / LSP
<leader>,        switch buffer         <leader>d  Debug (not installed)
<leader>:        command history       <leader>f  File / Find
<leader>?        buffer keymaps        <leader>g  Git
<leader>e        explorer              <leader>i  Image
<leader>E        explorer (root)       <leader>l  Lazy / Plugins
<leader>n        notifications         <leader>o  Outline / Symbols
<leader>z        zen mode              <leader>q  Quit / Session
<leader>Z        zoom window           <leader>r  Run / Language actions
<leader>D        delete to black hole  <leader>s  Search
<leader>-        split below           <leader>t  Test / Terminal
<leader>|        split right           <leader>u  UI Toggles
<leader>`        alternate buffer      <leader>w  Window
<leader>1..5     go to buffer N        <leader>x  Diagnostics / Quickfix
                                       <leader><tab>  Tab pages
```

---

## Non-leader — the ones you use constantly

### Motion and editing

| Key | Action |
|---|---|
| `s` / `S` | **flash jump** — type 2 chars, then the label. `S` jumps to a treesitter node |
| `j` `k` | move by *screen* line when wrapped; `5j` still moves 5 real lines |
| `<C-d>` `<C-u>` | half page, cursor recentred |
| `n` `N` | next/previous match, recentred |
| `Y` | yank to end of line (consistent with `D` and `C`) |
| `J` | join lines without moving the cursor |
| `x` | delete char **without** clobbering the clipboard |
| `<A-j>` `<A-k>` | move the line (or selection) down/up, re-indenting |
| `<` `>` in visual | shift and **keep the selection**, so you can repeat |
| `p` in visual | paste **without** losing your register — the most useful remap here |
| `<Esc>` | clear search highlight |
| `]<Space>` `[<Space>` | insert a blank line below/above |
| `gc` `gcc` | comment (built into Neovim 0.10+, made embedded-language-aware) |
| `gsa` `gsd` `gsr` | surround add / delete / replace — `gs` because flash owns `s` |

### Incremental selection — grow a selection along the syntax tree

| Key | Mode | Action |
|---|---|---|
| `<C-space>` | normal | select the node under the cursor |
| `<C-space>` | visual | grow to the parent node — press repeatedly |
| `<BS>` | visual | step back down to the previous, smaller node |
| `<A-space>` | visual | jump straight out to the enclosing multi-line construct |

From inside the string in `map.insert(String::from("a"), vec![1, 2, 3])`, repeated
`<C-space>` gives you `"a"` → `String::from("a")` → the argument list → the whole
call → the statement. Beats counting characters or nudging with `w`.

> The upstream `nvim-treesitter.incremental_selection` module was **deleted** in the
> `main`-branch rewrite, so every tutorial that configures it now errors with
> "module not found". This is a local reimplementation in `lua/util/incsel.lua`.

### Text objects

| Object | Selects |
|---|---|
| `af` / `if` | a function / its body |
| `ac` / `ic` | a class / its body |
| `aa` / `ia` | an argument |
| `ao` / `io` | a block, conditional or loop |
| `at` / `it` | an HTML/JSX tag pair |
| `ih` | a git hunk — so `dih` reverts the change under the cursor |
| `ii` / `ai` | the current indent scope |
| `ag` / `ig` | the whole buffer |

### Jumping between things — `]` next, `[` previous

| Key | Jumps to |
|---|---|
| `]d` `[d` | diagnostic (any severity) |
| `]e` `[e` | error only |
| `]w` `[w` | warning only |
| `]h` `[h` | git hunk (`]H` `[H` for last/first) |
| `]f` `[f` | function start (`]F` `[F` for its end) |
| `]c` `[c` | class start |
| `]a` `[a` | parameter |
| `]t` `[t` | TODO/FIXME comment |
| `]q` `[q` | quickfix item |
| `]x` `[x` | Trouble list item |
| `]T` `[T` | failing test |
| `]]` `[[` | next/previous reference of the symbol under the cursor |
| `]/` `[/` | comment block |
| `[C` | up to the enclosing function signature |

### Windows, buffers, terminal

| Key | Action |
|---|---|
| `<C-h/j/k/l>` | move between splits (also works from a terminal) |
| `<C-arrows>` | resize the split |
| `<S-h>` `<S-l>` | previous / next buffer |
| `<C-s>` | save (works from insert mode too) |
| `<C-/>` | toggle a floating terminal |
| `<Esc><Esc>` | leave terminal insert mode |
| `-` | **oil** — edit the current directory as a buffer |
| `q` | close a help / quickfix / diagnostic window |

### LSP — only present once a server attaches (`<leader>?` to confirm)

| Key | Action |
|---|---|
| `gd` | definition (in the picker, with preview) |
| `gr` | references |
| `gI` | implementation |
| `gy` | type definition |
| `gD` | declaration |
| `K` | hover documentation |
| `gK` / `<C-k>` (insert) | signature help |
| `gs` (TypeScript) | go to *source* definition, skipping `.d.ts` |

### Completion (insert mode)

| Key | Action |
|---|---|
| `<Tab>` / `<S-Tab>` | next/previous item, or jump between snippet placeholders |
| `<CR>` | accept the selected item; a plain newline if nothing is selected |
| `<C-y>` | accept |
| `<C-e>` | dismiss |
| `<C-space>` | open the menu, then toggle documentation |
| `<C-d>` / `<C-u>` | scroll the documentation window |

Nothing is preselected, so `<CR>` is never hijacked into inserting a random symbol.

---

## Leader mappings by group

### `<leader>f` — File / Find
`ff` files · `fF` files in this dir · `fg` git files · `fr` recent · `fb` buffers ·
`fC` find in config · `fc` edit config · `fz` zoxide dirs · `fo` oil (float) ·
`fn` new file · `fs` save · `fS` save all · `fp` copy absolute path ·
`fP` copy relative path

### `<leader>s` — Search
`sg` grep project · `sB` grep open buffers · `sw` grep word under cursor ·
`sb` lines in buffer · **`sk` search keymaps** · `sh` help · `sd` diagnostics
(project) · `sD` diagnostics (buffer) · `sc` commands · `sa` autocommands ·
`sH` highlight groups · `sm` marks · `sj` jumplist · `sq` quickfix · `sl` loclist ·
`su` undo history · `s"` registers · `s/` search history · `sC` colorschemes (live
preview) · `si` icons/emoji · `sp` projects · `sM` man pages · `sR` resume last
picker · `st` todo list · `sT` todo/fix only · **`sr` search & replace (project)**

### `<leader>g` — Git
`gg` **lazygit** · `gf` lazygit file history · `gl` log · `gL` log for current line ·
`gs` status · `gS` stash · `gB` branches · `gd` diff hunks · `ge` explorer of
changed files · `go` open on GitHub/GitLab · `gv` diffview (working tree) ·
`gV` close diffview · `gm` diff vs main branch · `gr` repo history ·
`gR` this file's history

**`<leader>gh` — hunks (gitsigns):** `ghs` stage · `ghr` reset · `ghS` stage buffer ·
`ghR` reset buffer · `ghu` undo stage · `ghp` preview inline · `ghP` preview float ·
`ghb` blame line · `ghB` blame file · `ghd` diff vs index · `ghD` diff vs last commit.
In visual mode `ghs`/`ghr` act on the selected lines only — this replaces `git add -p`.

> **Inline blame is OFF.** The always-on virtual text at end of line changed on every
> cursor move, which is a constant distraction while writing code. The information is
> one key away and in better form: `<leader>ghb` (float, full commit message),
> `<leader>ghB` (whole file), `<leader>gL` (every commit that touched this line), or
> `<leader>gtb` to switch the inline version back on for the session.

**`<leader>gt` — git toggles:** `gtb` inline blame · `gtd` deleted lines · `gtw` word diff

### `<leader>c` — Code / LSP
`ca` code action · `cr` rename · `cA` source action (organise imports) ·
`cf` format · `cF` format with LSP only · `cI` formatter info · `cd` line
diagnostics · `cL` run linters · `cR` rename file and update imports ·
`cs` / `cS` swap parameter with next/previous · `cc` run codelens ·
`cv` select Python interpreter · `cV` reuse last one · `ce` ESLint fix all ·
`cM` add missing imports (TS) · `cu` remove unused imports (TS) ·
`cp*` npm package management

### `<leader>x` — Diagnostics / Quickfix (Trouble)
`xx` project diagnostics · `xX` buffer diagnostics · `xs` symbols panel ·
`xr` references · `xl` loclist · `xq` quickfix · `xt` todos

### `<leader>t` — Test / Terminal
`tr` run nearest · `tf` run file · `tA` run suite · `tl` re-run last ·
`ts` suite tree · `to` show output · `tO` output panel · `tS` stop ·
**`tw` watch mode** (re-runs on save) · `tW` watch nearest · `tt` terminal

### `<leader>u` — UI Toggles
Each shows its current on/off state in the which-key panel.

`uw` wrap · `us` spelling · `ul` line numbers · `uL` relative numbers ·
`uc` conceal · `ub` dark/light · `uu` cursor column · `ud` diagnostic virtual
**lines** (better for long Rust errors) · `uD` diagnostics on/off · `uh` inlay
hints · `ug` indent guides · `ur` rainbow delimiters · `uT` treesitter highlight ·
`ut` sticky context · `uS` smooth scroll · `uA` dim inactive · `um` markdown rendering ·
**`uf` format-on-save (buffer)** · **`uF` format-on-save (global)** ·
`un` dismiss notifications · `uN` message history ·
`ui` inspect highlight groups · `uI` treesitter tree · `uq` edit query ·
`ux` execute line as Lua

### `<leader>b` — Buffer
`bd` delete (**keeps the window layout**, unlike `:bdelete`) · `bo` delete others ·
`bD` delete all · `bp` pin · `bP` close unpinned · `bl` / `br` close left/right ·
`bb` alternate · `be` buffer explorer

### `<leader>w` — Window
`ws` split · `wv` vsplit · `wd` close · `ww` other · `w=` equalise · `wm` maximise

### `<leader>q` — Quit / Session
`qq` quit all · `qQ` quit discarding changes · `qs` restore this directory's
session · `qS` pick a session · `ql` restore last · `qd` don't save on exit

### `<leader>l` — Lazy / Plugins
`ll` Lazy UI · `lu` update · `lc` check updates · `lp` profile startup · `lm` Mason

### `<leader>o` / `<leader>i` / `<leader>r`
`oo` outline sidebar · `on` floating navigator · `ii` show image under cursor ·
`r*` language actions (Rust: `rr` runnables, `rm` expand macro, `re` explain
error, `rc` open Cargo.toml, `ro` docs.rs, `ru`/`rU` upgrade crates)

---

## `<localleader>` — filetype-specific (`\`)

| Filetype | Keys |
|---|---|
| **Python** | `\r` run file · `\i` REPL · `\b` insert `breakpoint()` |
| **Rust** | `\b` build · `\c` check · `\t` test · `\r` run · `\l` clippy · `\f` fmt · `\d` docs · `\u` update |
| **Lua** | `\x` source this file · `\r` reload core config |
| **Markdown** | `\x` toggle checkbox · `\o` open link · `\b`/`\i`/`\c` bold/italic/code selection · `\q` reflow |
| **Shell** | `\r` chmod +x and run |
| **JSON** | `\p` pretty-print |

---

## WezTerm — all bindings use `CTRL+SHIFT`

Chosen because `CTRL+SHIFT` combinations are essentially never bound inside
terminal programs, so nothing Neovim wants is shadowed. There is deliberately no
leader key: it would swallow a chord before Neovim saw it.

| Key | Action |
|---|---|
| `CTRL+SHIFT+\|` / `_` | split pane right / down (same mnemonics as `<leader>\|` and `-`) |
| `CTRL+SHIFT+h/j/k/l` | move between panes |
| `CTRL+SHIFT+z` | zoom pane |
| `CTRL+SHIFT+w` | close pane |
| `CTRL+SHIFT+arrows` | resize pane |
| `CTRL+SHIFT+t` | new tab · `[` `]` switch · `e` tab navigator · `r` rename |
| `CTRL+SHIFT+c` / `v` | copy / paste |
| `CTRL+SHIFT+/` | search scrollback · `x` copy mode (Vim motions over output) |
| `CTRL+SHIFT+s` | **quick-select** — label every path/URL on screen, copy with 2 keys |
| `CTRL+SHIFT+o` | open a URL from the screen without the mouse |
| `CTRL+SHIFT+f` | fullscreen · `p` launcher · `L` debug overlay |
| `CTRL+ALT+k` | clear scrollback and screen |
| `CTRL+SHIFT++` / `CTRL+-` / `CTRL+0` | font size up / down / reset |
