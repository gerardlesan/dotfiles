#!/usr/bin/env bash
#
# Installs this Neovim configuration on Linux (and macOS).
#
#   ./install.sh              link the config, report what is missing
#   ./install.sh --tools      also install the missing system packages
#   ./install.sh --tools --sync   ...and install all plugins and parsers
#   ./install.sh --force      overwrite existing configs without prompting
#
# Symlinks ~/.config/nvim to the nvim/ directory in this repo. The Windows
# counterpart is install.ps1, which uses a directory junction instead (a symlink
# on Windows needs Administrator or Developer Mode; a junction does not).
#
# On Linux it also COPIES ghostty/config and starship/starship.toml into
# ~/.config (copied, not linked — see section 5 for why). Existing files are
# backed up with a timestamp first. Both steps are skipped on macOS and are not
# mirrored in install.ps1.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NVIM_SOURCE="$REPO_ROOT/nvim"
# Respect XDG_CONFIG_HOME if the user has set it; otherwise the standard location.
NVIM_TARGET="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"

INSTALL_TOOLS=0
SYNC=0
FORCE=0
for arg in "$@"; do
  case "$arg" in
    --tools) INSTALL_TOOLS=1 ;;
    --sync)  SYNC=1 ;;
    --force) FORCE=1 ;;
    -h|--help) sed -n '2,17p' "$0" | sed 's/^# \?//'; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 1 ;;
  esac
done

# ── Output helpers ────────────────────────────────────────────────────────────
if [ -t 1 ]; then
  C_STEP='\033[35m'; C_OK='\033[32m'; C_WARN='\033[33m'; C_ERR='\033[31m'; C_OFF='\033[0m'
else
  C_STEP=''; C_OK=''; C_WARN=''; C_ERR=''; C_OFF=''
fi
step()  { printf "\n${C_STEP}=== %s ===${C_OFF}\n" "$1"; }
ok()    { printf "  ${C_OK}[ok]${C_OFF}   %s\n" "$1"; }
warn()  { printf "  ${C_WARN}[warn]${C_OFF} %s\n" "$1"; }
err()   { printf "  ${C_ERR}[FAIL]${C_OFF} %s\n" "$1"; }

have() { command -v "$1" >/dev/null 2>&1; }

# ── 0. Detect the package manager ─────────────────────────────────────────────
step "Detecting platform"

OS="$(uname -s)"
PM=""
if [ "$OS" = "Darwin" ]; then
  PM="brew"
elif have apt-get; then PM="apt"
elif have dnf;     then PM="dnf"
elif have pacman;  then PM="pacman"
elif have zypper;  then PM="zypper"
elif have apk;     then PM="apk"
fi

if [ -z "$PM" ]; then
  warn "No supported package manager found. Tool installation will be skipped."
else
  ok "$OS, using $PM"
fi

# Package names differ per distro. This table is the whole reason a plain
# "apt install" one-liner in a README does not work across machines.
#
# Notable trap: on Debian/Ubuntu the fd package is called `fd-find` and it
# installs the binary as `fdfind`, not `fd`, because of a name clash. Handled below.
#
# `nodejs` is deliberately NOT listed: on every distro here `npm` depends on it,
# so naming both is redundant. (brew is the exception — its package is `node` and
# it carries npm, so that branch lists `node`.)
#
# `starship` and the Nerd Font are listed only where the package name is verified
# to exist and to be the right thing: pacman (`starship`, `ttf-jetbrains-mono-nerd`
# — both in extra) and brew (`starship`; its Nerd Font is a cask, so it is not in
# this list and section 3 prints the cask command instead). Debian/Fedora/SUSE/Alpine
# are left out on purpose — their JetBrains Mono packages are the UNPATCHED upstream
# font, which installs cleanly and then renders every icon as a hollow box, which is
# worse than the honest "not installed" message section 3 prints.
#
# pacman also gets `rust-analyzer`, `rust-src` and `lazygit` from the repos.
# Arch's `rust` package does not ship the standard-library sources that
# go-to-definition needs, and pacman's `rustup` *conflicts* with `rust` — so on
# Arch the distro packages are the only route, not a convenience. `rust-src`
# depends on `rust`, which version-locks it to the installed rustc.
pkgs_for() {
  case "$PM" in
    apt)    echo "git curl tar unzip build-essential ripgrep fd-find imagemagick npm python3 python3-venv wl-clipboard xclip fontconfig" ;;
    dnf)    echo "git curl tar unzip gcc gcc-c++ make ripgrep fd-find ImageMagick npm python3 wl-clipboard xclip fontconfig" ;;
    pacman) echo "git curl tar unzip base-devel ripgrep fd imagemagick npm python wl-clipboard xclip fontconfig rust-analyzer rust-src lazygit starship ttf-jetbrains-mono-nerd" ;;
    zypper) echo "git curl tar unzip gcc gcc-c++ make ripgrep fd ImageMagick npm python3 wl-clipboard xclip fontconfig" ;;
    apk)    echo "git curl tar unzip build-base ripgrep fd imagemagick npm python3 wl-clipboard xclip fontconfig" ;;
    brew)   echo "git curl ripgrep fd imagemagick node python3 lazygit starship" ;;
    *)      echo "" ;;
  esac
}

install_pkgs() {
  local list="$1"
  [ -z "$list" ] && return 0
  # shellcheck disable=SC2086
  case "$PM" in
    apt)    sudo apt-get update && sudo apt-get install -y $list ;;
    dnf)    sudo dnf install -y $list ;;
    pacman) sudo pacman -S --needed --noconfirm $list ;;
    zypper) sudo zypper install -y $list ;;
    apk)    sudo apk add $list ;;
    brew)   brew install $list ;;
  esac
}

# ── 1. Check what is present ──────────────────────────────────────────────────
step "Checking required tools"

check() { # name, why, required(0/1)
  if have "$1"; then ok "$1"
  elif [ "$3" = "1" ]; then err "$1 missing — $2"; return 1
  else warn "$1 missing — $2"; fi
  return 0
}

MISSING=0
check nvim        "the editor itself"                       1 || MISSING=1
check git         "the plugin manager clones over git"      1 || MISSING=1
check cc          "C compiler, for treesitter parsers"      1 || MISSING=1
check rg          "grep picker and :grep"                   1 || MISSING=1
check tree-sitter "treesitter parser generator"             1 || MISSING=1
check curl        "downloading parsers"                     1 || MISSING=1
check tar         "extracting parsers"                      1 || MISSING=1
check fd          "fast file picker"                        0 || true
check node        "TypeScript LSP, prettier, jest"          0 || true
check lazygit     "git UI on <leader>gg"                    0 || true
check magick      "image viewing (non-PNG conversion)"      0 || true
check rust-analyzer "Rust LSP"                              0 || true

# ── 2. Install what is missing ────────────────────────────────────────────────
if [ "$INSTALL_TOOLS" = "1" ] && [ -n "$PM" ]; then
  step "Installing system packages"
  install_pkgs "$(pkgs_for)"

  # Debian/Ubuntu: the fd binary is installed as `fdfind`. Provide a `fd` on PATH,
  # because the config (and venv-selector in particular) invokes `fd` by name.
  if have fdfind && ! have fd; then
    mkdir -p "$HOME/.local/bin"
    ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
    ok "linked fdfind -> ~/.local/bin/fd"
  fi

  # Neovim: distro packages are often far behind. THIS CONFIG REQUIRES 0.11+ for
  # the native vim.lsp.config API, and nvim-treesitter's main branch requires
  # 0.12+. Debian stable in particular ships something much older, so prefer the
  # official AppImage.
  # Version read through a command substitution, not a live pipeline: `head -1`
  # exits early, and under `set -o pipefail` that turns a SIGPIPE upstream into a
  # failed test. It happens to survive today only because `nvim --version` fits
  # in the pipe buffer before head closes it — a race, not a guarantee. See the
  # long note in section 3.
  NVIM_VERSION_LINE="$(nvim --version 2>/dev/null | head -1 || true)"
  if ! have nvim || ! [[ "$NVIM_VERSION_LINE" =~ v0\.(1[2-9]|[2-9][0-9]) ]]; then
    step "Installing Neovim 0.12+ (AppImage)"
    warn "distro Neovim is absent or older than 0.12; this config needs 0.12+"
    mkdir -p "$HOME/.local/bin"
    ARCH="$(uname -m)"
    case "$ARCH" in
      x86_64)  NVIM_ASSET="nvim-linux-x86_64.appimage" ;;
      aarch64) NVIM_ASSET="nvim-linux-arm64.appimage" ;;
      *) err "no Neovim AppImage for $ARCH — build from source"; NVIM_ASSET="" ;;
    esac
    if [ -n "$NVIM_ASSET" ]; then
      curl -fL "https://github.com/neovim/neovim/releases/latest/download/$NVIM_ASSET" \
        -o "$HOME/.local/bin/nvim"
      chmod +x "$HOME/.local/bin/nvim"
      ok "installed to ~/.local/bin/nvim"
      warn "AppImages need FUSE. If it fails to run: ./nvim --appimage-extract"
    fi
  fi

  # tree-sitter CLI: required by nvim-treesitter's main branch, and packaged
  # almost nowhere. Prefer the prebuilt release binary over `cargo install`,
  # which needs libclang and takes several minutes.
  if ! have tree-sitter; then
    step "Installing tree-sitter CLI"
    mkdir -p "$HOME/.local/bin"
    ARCH="$(uname -m)"
    case "$ARCH" in
      x86_64)  TS_ASSET="tree-sitter-linux-x64.gz" ;;
      aarch64) TS_ASSET="tree-sitter-linux-arm64.gz" ;;
      *)       TS_ASSET="" ;;
    esac
    if [ "$OS" = "Darwin" ]; then
      case "$ARCH" in
        arm64)  TS_ASSET="tree-sitter-macos-arm64.gz" ;;
        x86_64) TS_ASSET="tree-sitter-macos-x64.gz" ;;
      esac
    fi
    if [ -n "$TS_ASSET" ]; then
      TAG="$(curl -fsSL https://api.github.com/repos/tree-sitter/tree-sitter/releases/latest \
             | grep -m1 '"tag_name"' | cut -d'"' -f4)"
      curl -fL "https://github.com/tree-sitter/tree-sitter/releases/download/$TAG/$TS_ASSET" \
        | gunzip > "$HOME/.local/bin/tree-sitter"
      chmod +x "$HOME/.local/bin/tree-sitter"
      ok "tree-sitter $TAG installed to ~/.local/bin"
    else
      warn "no prebuilt tree-sitter for $ARCH — try: cargo install tree-sitter-cli"
    fi
  fi

  # lazygit is not in Debian/Ubuntu repos before 24.04. The `have lazygit` guard
  # matters now that pacman and brew supply it in pkgs_for above: without it this
  # would shell out to the GitHub API to reinstall a binary the package manager
  # just put on PATH.
  if ! have lazygit && [ "$PM" = "apt" ]; then
    step "Installing lazygit"
    LG_VER="$(curl -fsSL https://api.github.com/repos/jesseduffield/lazygit/releases/latest \
              | grep -m1 '"tag_name"' | cut -d'"' -f4 | tr -d 'v')"
    curl -fL "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LG_VER}_Linux_x86_64.tar.gz" \
      | tar -xz -C /tmp lazygit
    mkdir -p "$HOME/.local/bin" && mv /tmp/lazygit "$HOME/.local/bin/lazygit"
    ok "lazygit $LG_VER installed to ~/.local/bin"
  fi

  # rust-analyzer: distro first where the distro actually has it, rustup
  # otherwise. On Arch this ordering is required, not preferred — pacman's
  # `rustup` conflicts with its `rust` package, so a machine with `rust`
  # installed cannot use `rustup component add` at all. pkgs_for already added
  # rust-analyzer and rust-src to the pacman list, so by here it is in place.
  if have rust-analyzer; then
    ok "rust-analyzer (from the distro packages)"
  elif [ "$PM" = "pacman" ]; then
    step "Installing Rust components"
    install_pkgs "rust-analyzer rust-src"
  elif have rustup; then
    step "Installing Rust components"
    rustup component add rust-analyzer rust-src clippy rustfmt
    ok "rust-analyzer, rust-src, clippy, rustfmt"
  else
    warn "no rust-analyzer and no rustup — get rustup from https://rustup.rs,"
    echo "         or install your distro's rust-analyzer + rust-src packages"
  fi

  # ~/.local/bin must be on PATH for the binaries installed above.
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) warn "add ~/.local/bin to your PATH:"
       echo '         echo '"'"'export PATH="$HOME/.local/bin:$PATH"'"'"' >> ~/.profile' ;;
  esac
elif [ "$MISSING" = "1" ]; then
  warn "Re-run with --tools to install the missing packages."
fi

# ── 3. Nerd Font ──────────────────────────────────────────────────────────────
# Checks for the font the terminal config actually ASKS for, not for "any Nerd
# Font". The old check was `fc-list | grep -qi 'nerd font'`, which had TWO
# independent bugs, and each on its own was enough to make it lie:
#
#   1. It asked the wrong question. It passed on a machine carrying Meslo and
#      Fantasque while ghostty/config requested JetBrainsMono, so Ghostty
#      silently fell back to a default font and the check reported all fine. An
#      unsatisfiable font request is invisible: nothing errors, the glyphs are
#      just wrong.
#
#   2. **`grep -q` at the end of a pipeline is unsafe under `set -o pipefail`**
#      (line 19). `grep -q` exits the moment it matches; the process upstream
#      then dies of SIGPIPE writing to a closed pipe, the pipeline's status
#      becomes 141, and pipefail hands that to the `if`. So the check reported
#      "No Nerd Font detected" on a machine with 84 of them — a MATCH read as a
#      failure. Verified directly:
#        set -euo pipefail; fc-list | grep -qi "nerd font"; echo $?   -> 141
#        set -eu;           fc-list | grep -qi "nerd font"; echo $?   -> 0
#      The fix is to collect the output first and match against a here-string:
#      no pipe, nothing to break. Anywhere in this file that a pipeline ends in
#      an early-exiting command (`grep -q`, `head`), it needs this treatment.
step "Checking for a Nerd Font"
# Parsed out of ghostty/config so the two can never drift; the fallback is only
# for a checkout where that file is missing.
WANTED_FONT="$(sed -n 's/^font-family[[:space:]]*=[[:space:]]*//p' "$REPO_ROOT/ghostty/config" 2>/dev/null | head -1)"
WANTED_FONT="${WANTED_FONT:-JetBrainsMono Nerd Font}"
# `sort -u` reads its input to the end, so nothing in here can exit early.
FONT_FAMILIES=""
have fc-list && FONT_FAMILIES="$(fc-list : family 2>/dev/null | tr ',' '\n' | sort -u || true)"

if ! have fc-list; then
  warn "fontconfig (fc-list) missing — cannot check for $WANTED_FONT"
elif grep -qixF "$WANTED_FONT" <<<"$FONT_FAMILIES"; then
  ok "$WANTED_FONT is installed"
else
  warn "$WANTED_FONT is NOT installed — icons will render as boxes."
  if grep -qi "nerd font" <<<"$FONT_FAMILIES"; then
    # Worth saying explicitly: this is the case that used to pass silently.
    echo "         (Other Nerd Fonts are installed, but ghostty/config asks for"
    echo "          this one by name, so Ghostty falls back to a default font.)"
  fi
  case "$PM" in
    pacman) echo "         sudo pacman -S ttf-jetbrains-mono-nerd" ;;
    apt)    echo "         sudo apt install fonts-jetbrains-mono   # not Nerd-patched on older releases" ;;
    dnf)    echo "         sudo dnf install jetbrains-mono-fonts" ;;
    brew)   echo "         brew install --cask font-jetbrains-mono-nerd-font" ;;
  esac
  echo "         Or, with no root, straight into your user font directory:"
  echo "           mkdir -p ~/.local/share/fonts && cd ~/.local/share/fonts"
  echo "           curl -fLO https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
  echo "           unzip -o JetBrainsMono.zip && fc-cache -f"
  echo "         The name must match ghostty/config's font-family exactly."
fi

# ── 4. Link the config ────────────────────────────────────────────────────────
step "Linking Neovim config"

if [ ! -d "$NVIM_SOURCE" ]; then
  err "no nvim/ directory at $NVIM_SOURCE — run this from the repo root"
  exit 1
fi

if [ -L "$NVIM_TARGET" ]; then
  CURRENT="$(readlink -f "$NVIM_TARGET")"
  if [ "$CURRENT" = "$(readlink -f "$NVIM_SOURCE")" ]; then
    ok "already linked: $NVIM_TARGET -> $NVIM_SOURCE"
  else
    warn "$NVIM_TARGET points at $CURRENT"
    if [ "$FORCE" != "1" ]; then
      read -r -p "  Replace it? [y/N] " ans
      [[ "$ans" =~ ^[Yy]$ ]] || { echo "  Aborted."; exit 1; }
    fi
    rm "$NVIM_TARGET"   # removes only the symlink, never the target
  fi
elif [ -e "$NVIM_TARGET" ]; then
  BACKUP="$NVIM_TARGET.backup-$(date +%Y%m%d-%H%M%S)"
  warn "$NVIM_TARGET exists as a real directory"
  if [ "$FORCE" != "1" ]; then
    read -r -p "  Back it up to $BACKUP and replace? [y/N] " ans
    [[ "$ans" =~ ^[Yy]$ ]] || { echo "  Aborted."; exit 1; }
  fi
  mv "$NVIM_TARGET" "$BACKUP"
  ok "backed up to $BACKUP"
fi

if [ ! -e "$NVIM_TARGET" ]; then
  mkdir -p "$(dirname "$NVIM_TARGET")"
  ln -s "$NVIM_SOURCE" "$NVIM_TARGET"
  ok "symlinked $NVIM_TARGET -> $NVIM_SOURCE"
fi

echo "  plugin + state directories (delete for a clean reinstall):"
echo "    ${XDG_DATA_HOME:-$HOME/.local/share}/nvim"
echo "    ${XDG_STATE_HOME:-$HOME/.local/state}/nvim"

# ── 5. Ghostty and Starship configs (Linux only) ──────────────────────────────
# These two are COPIED, not symlinked, unlike nvim/ above. That is deliberate:
# both are single files that get poked at live (Ghostty reloads its config, and a
# prompt gets retuned on the machine you are sitting at), and a symlink turns
# every such experiment into an uncommitted change in this repo. Copy = the repo
# is the source you install FROM; re-run ./install.sh to push a new version out,
# and copy back by hand when a local tweak is worth keeping.
#
# Linux only. macOS has Ghostty but no verified config here (window-decoration =
# server and the GTK titlebar settings below are Linux-side), and the Windows
# counterpart install.ps1 deliberately handles Neovim only.
if [ "$OS" = "Linux" ]; then
  CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

  # Copy REPO_FILE to TARGET, backing up an existing, differing file first.
  # Skips silently when the two are already identical, so re-running is quiet.
  install_file() { # repo-relative source, absolute target, human name
    local src="$REPO_ROOT/$1" dst="$2" name="$3"
    if [ ! -f "$src" ]; then
      warn "$name: nothing to install at $src"
      return 0
    fi
    if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
      ok "$name: $dst already up to date"
      return 0
    fi
    if [ -e "$dst" ] || [ -L "$dst" ]; then
      # -L as well as -e: an earlier version of this script symlinked these, and a
      # dangling symlink fails -e while still blocking the copy.
      local backup="$dst.backup-$(date +%Y%m%d-%H%M%S)"
      warn "$name: $dst exists and differs"
      if [ "$FORCE" != "1" ]; then
        read -r -p "  Back it up to $(basename "$backup") and overwrite? [y/N] " ans
        [[ "$ans" =~ ^[Yy]$ ]] || { warn "$name: skipped"; return 0; }
      fi
      mv "$dst" "$backup"
      ok "$name: backed up to $backup"
    fi
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    ok "$name: installed $dst"
  }

  step "Ghostty"
  # The filename is exactly `config`, no extension — Ghostty ignores any other
  # name without warning, which is how this machine once ran an unconfigured
  # terminal while Neovim rendered its own palette. See ghostty/config's header.
  install_file "ghostty/config" "$CONFIG_HOME/ghostty/config" "ghostty"
  if [ -e "$CONFIG_HOME/ghostty/config.ghostty" ]; then
    warn "$CONFIG_HOME/ghostty/config.ghostty is ignored by Ghostty — delete it"
  fi
  have ghostty || warn "ghostty is not on PATH — https://ghostty.org/download"

  step "Starship"
  # Starship reads $STARSHIP_CONFIG if set, else ~/.config/starship.toml — a bare
  # file, not a directory, so this is one copy rather than a linked folder.
  install_file "starship/starship.toml" "${STARSHIP_CONFIG:-$CONFIG_HOME/starship.toml}" "starship"
  if ! have starship; then
    warn "starship missing — the config is in place but nothing reads it yet"
    echo "         Arch: sudo pacman -S starship   ·  otherwise: https://starship.rs"
  else
    ok "starship on PATH"

    # Copying starship.toml is only two thirds of the job: the prompt does not
    # appear until the SHELL initialises starship, and that line lives in the
    # shell's rc file, which this repo does not ship (it is per-machine — CachyOS
    # sources its own fish config, Debian does not). Without it the prompt config
    # sits on disk doing nothing, looking installed. So: check the login shell's
    # rc file and print the exact line if it is missing. This does NOT edit the
    # rc file — an installer silently rewriting a shell rc is how a prompt ends
    # up initialised twice, or ahead of the framework that overrides it.
    #
    # The login shell comes from the passwd entry, not $SHELL: on this machine
    # $SHELL still reads /usr/bin/zsh in some spawned environments while the
    # actual login shell is /bin/fish.
    LOGIN_SHELL="$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f7)"
    LOGIN_SHELL="$(basename "${LOGIN_SHELL:-$SHELL}")"
    case "$LOGIN_SHELL" in
      fish) SHELL_RC="$CONFIG_HOME/fish/config.fish"; INIT_LINE='starship init fish | source' ;;
      zsh)  SHELL_RC="$HOME/.zshrc";                  INIT_LINE='eval "$(starship init zsh)"' ;;
      bash) SHELL_RC="$HOME/.bashrc";                 INIT_LINE='eval "$(starship init bash)"' ;;
      *)    SHELL_RC=""; INIT_LINE="" ;;
    esac
    if [ -z "$SHELL_RC" ]; then
      warn "unrecognised login shell ($LOGIN_SHELL) — see https://starship.rs/#quick-install"
    elif [ -f "$SHELL_RC" ] && grep -q "starship init" "$SHELL_RC"; then
      ok "starship is initialised in $SHELL_RC"
    else
      warn "starship is NOT initialised in your shell — the prompt will not appear"
      echo "         Add this to $SHELL_RC (last line, so it wins):"
      echo "           $INIT_LINE"
    fi
  fi

  step "fastfetch"
  # The shell greeting: fastfetch beside an animated logo. fetch.py picks how to
  # show it (see its docstring); art.py renders the frames into
  # ~/.cache/fastfetch-art the first time it meets a new terminal cell size, in
  # the background, showing a still text frame until they are ready. Copied like
  # the two above, for the same reason.
  for f in "$REPO_ROOT"/fastfetch/*; do
    [ -f "$f" ] || continue
    install_file "fastfetch/$(basename "$f")" "$CONFIG_HOME/fastfetch/$(basename "$f")" "fastfetch/$(basename "$f")"
  done
  chmod +x "$CONFIG_HOME/fastfetch/fetch.py" "$CONFIG_HOME/fastfetch/art.py"
  have fastfetch || warn "fastfetch missing — Arch: sudo pacman -S fastfetch"
  python3 -c 'import numpy, PIL' 2>/dev/null \
    || warn "art.py needs numpy and Pillow — Arch: sudo pacman -S python-numpy python-pillow"
  # Like starship, it only runs if the shell calls it, from a line that lives in
  # the per-machine rc file. Only fish is wired up; the gate is in that snippet.
  if grep -q "fastfetch/fetch.py" "$CONFIG_HOME/fish/config.fish" 2>/dev/null; then
    ok "fish_greeting runs fetch.py"
  else
    warn "fish_greeting does not run fetch.py — add to $CONFIG_HOME/fish/config.fish:"
    echo "           function fish_greeting"
    echo "               set -q NVIM; and return"
    echo "               test \"\$SHLVL\" -le 1; or return"
    echo "               if set -q SSH_CONNECTION; or test \"\$TERM_PROGRAM\" = ghostty"
    echo "                   ~/.config/fastfetch/fetch.py"
    echo "               end"
    echo "           end"
  fi
fi

# ── 6. WezTerm config ─────────────────────────────────────────────────────────
# The WezTerm config is NOT part of this repo (by design — it is one file), but it
# lives at a path that is identical on both platforms, so mention it.
#
# Only mentioned when WezTerm is actually installed. It used to warn
# unconditionally, which on a Ghostty machine is a permanent warning about a file
# that will never exist, for a terminal that is not in use — and a warning nobody
# can act on trains you to skim past the ones that matter.
step "WezTerm"
WEZ_TARGET="${XDG_CONFIG_HOME:-$HOME/.config}/wezterm/wezterm.lua"
if [ -f "$WEZ_TARGET" ]; then
  ok "found $WEZ_TARGET"
elif have wezterm; then
  warn "wezterm is installed but has no config at $WEZ_TARGET"
  echo "         Copy it from your other machine — the path is the same on"
  echo "         Windows and Linux, so the file needs no changes."
else
  ok "not installed — skipped (Ghostty is this setup's terminal)"
fi

# ── 7. Sync plugins, parsers and tools ────────────────────────────────────────
#
# All three steps drive Neovim headlessly, through small Lua drivers rather than
# through the user commands (`:Lazy sync`, `:MasonInstall …`). Two reasons, both
# found by this section failing on a fresh machine:
#
#   1. **A user command puts every item in one basket.** `:MasonInstall a b c …`
#      reports one aggregate outcome, so one tool that 404s or times out reads as
#      "the install step failed" with no way to tell what actually landed. The
#      drivers install item by item, retry once, and report per item — getting 17
#      of 18 tools is a far better outcome than stopping at the first hiccup.
#
#   2. **Installer stderr must be kept out of Neovim's error path.** In headless
#      mode mason pipes each installer's stderr straight into `nvim_err_write`,
#      and Neovim promotes an error message written while a `-c` command runs
#      into a real command-line error. So one harmless line on stderr aborted the
#      whole batch with:
#
#        Error in command line:
#        Lua :command callback: …/lazy/core/handler/cmd.lua:48:
#        Vim:npm warn install-scripts 1 package had install scripts blocked
#        because they are not covered by allowScripts:
#
#      npm >= 12 blocks dependency install scripts by default and prints exactly
#      that warning (verified on npm 12.0.2: it warns on stderr and still exits
#      0). Every mason package had installed correctly; only the report was a
#      lie. The drivers read the streams themselves, so installer output can
#      never masquerade as a Neovim error, and it is printed only when a package
#      genuinely fails.
#
# Nothing here aborts the script. Failures are collected and repeated once at the
# end, with the in-editor command that retries them.
SYNC_FAILURES=""

if [ "$SYNC" = "1" ]; then
  if ! have nvim; then
    err "nvim is not on PATH — skipping --sync"
    SYNC_FAILURES="$SYNC_FAILURES nvim-missing"
  else
    SYNC_TMP="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-sync.XXXXXX")"
    KEEP_SYNC_TMP=0
    # shellcheck disable=SC2064
    trap '[ "$KEEP_SYNC_TMP" = "1" ] || rm -rf "$SYNC_TMP"' EXIT

    # Runs one Lua driver. The driver writes machine-readable
    # "status<TAB>name<TAB>detail" lines to $DOTFILES_RESULTS; everything else it
    # (and every plugin loaded alongside it) prints goes to the log, which is
    # kept only when something failed. `-c 'qa!'` is separate from the driver so
    # a driver that dies mid-way still leaves the results written so far.
    run_driver() { # driver-file, results-file, log-file
      DOTFILES_RESULTS="$2" nvim --headless -c "luafile $1" -c "qa!" >"$3" 2>&1 || true
    }

    # Renders a driver's results. Prints one line per non-ok item plus a count,
    # because a healthy run has 18 servers and 37 parsers and nobody reads 55
    # green lines. Returns 1 if anything failed.
    report_results() { # results-file, log-file, noun
      local results="$1" log="$2" noun="$3"
      local status name detail done=0 present=0 failed=0
      if [ ! -s "$results" ]; then
        err "no $noun were reported — the driver never ran (see $log)"
        return 1
      fi
      while IFS="$(printf '\t')" read -r status name detail; do
        case "$status" in
          ok)      done=$((done + 1)) ;;
          present) present=$((present + 1)) ;;
          skip)    warn "$name — $detail" ;;
          *)       err "$name — ${detail:-failed}"; failed=$((failed + 1)) ;;
        esac
      done < "$results"
      if [ "$failed" -gt 0 ]; then
        ok "$((done + present)) $noun ready ($present already present)"
        err "$failed failed — full output in $log"
        return 1
      fi
      ok "$((done + present)) $noun ready ($present already present, $done installed)"
      return 0
    }

    # ── 7a. Plugins ───────────────────────────────────────────────────────────
    step "Installing plugins"
    cat > "$SYNC_TMP/plugins.lua" <<'LUA'
local results = assert(io.open(assert(vim.env.DOTFILES_RESULTS), "w"))
local function emit(status, name, detail)
  results:write(("%s\t%s\t%s\n"):format(status, name, ((detail or ""):gsub("%s+", " "))))
  results:flush()
end

local ok_lazy, lazy = pcall(require, "lazy")
if not ok_lazy then
  emit("fail", "lazy.nvim", "lazy.nvim did not bootstrap: " .. tostring(lazy))
  results:close()
  return
end

-- Snapshot first: after the sync every plugin looks installed, so this is the
-- only moment at which "already present" and "just fetched" can be told apart.
local before = {}
for name, plugin in pairs(require("lazy.core.config").plugins) do
  before[name] = plugin._.installed and true or false
end

-- wait = true blocks until every clone/checkout finishes; show = false keeps
-- lazy's floating window out of a headless run (it renders as noise in the log).
pcall(lazy.sync, { wait = true, show = false })

-- lazy.sync never errors on a plugin it could not fetch, so verify on disk:
-- `p._.installed` is what lazy itself uses to decide a plugin is present.
for _, plugin in pairs(require("lazy.core.config").plugins) do
  if plugin._.installed then
    emit(before[plugin.name] and "present" or "ok", plugin.name, "")
  else
    emit("fail", plugin.name, "not installed — check the network and `:Lazy`")
  end
end
results:close()
LUA
    run_driver "$SYNC_TMP/plugins.lua" "$SYNC_TMP/plugins.tsv" "$SYNC_TMP/plugins.log"
    report_results "$SYNC_TMP/plugins.tsv" "$SYNC_TMP/plugins.log" "plugins" \
      || { SYNC_FAILURES="$SYNC_FAILURES plugins"; KEEP_SYNC_TMP=1; }

    # ── 7b. Treesitter parsers ────────────────────────────────────────────────
    step "Installing treesitter parsers"
    echo "  this compiles each parser with the tree-sitter CLI — a few minutes on a cold cache"
    # Kept in sync by hand with `parser_groups` in lua/plugins/treesitter.lua,
    # which is the config's source of truth (it is a local table there, so there
    # is nothing to require from here). No 'jsonc' — it is an alias onto the
    # 'json' parser, not a parser itself.
    export DOTFILES_PARSERS="lua luadoc vim vimdoc query markdown markdown_inline bash rust python typescript javascript tsx json yaml toml html css scss regex diff git_config git_rebase gitcommit gitignore dockerfile make cmake ninja printf xml sql ssh_config comment rst requirements jsdoc"
    cat > "$SYNC_TMP/parsers.lua" <<'LUA'
local results = assert(io.open(assert(vim.env.DOTFILES_RESULTS), "w"))
local function emit(status, name, detail)
  results:write(("%s\t%s\t%s\n"):format(status, name, ((detail or ""):gsub("%s+", " "))))
  results:flush()
end

local wanted = vim.split(vim.trim(vim.env.DOTFILES_PARSERS or ""), "%s+", { trimempty = true })

local ok_ts, ts = pcall(require, "nvim-treesitter")
if not ok_ts then
  emit("fail", "nvim-treesitter", tostring(ts))
  results:close()
  return
end

local function installed()
  local ok, list = pcall(ts.get_installed, "parsers")
  return ok and vim.iter(list):fold({}, function(acc, lang)
    acc[lang] = true
    return acc
  end) or {}
end

local have = installed()
local missing = vim.tbl_filter(function(lang)
  return not have[lang]
end, wanted)

-- One batch pass first: install() compiles several parsers concurrently, which
-- is minutes faster than a serial loop over 37 of them. It returns a boolean
-- rather than raising per parser, so the result is checked on disk below.
if #missing > 0 then
  pcall(function()
    ts.install(missing, { max_jobs = 4 }):wait(1800000)
  end)
end

-- Whatever the batch missed is retried alone, so one parser whose grammar fails
-- to compile (or whose download raced) cannot take the rest down with it, and
-- its own error is the one that gets reported.
have = installed()
for _, lang in ipairs(wanted) do
  if have[lang] then
    emit(vim.tbl_contains(missing, lang) and "ok" or "present", lang, "")
  else
    local ok, err = pcall(function()
      ts.install({ lang }, { max_jobs = 1 }):wait(600000)
    end)
    if installed()[lang] then
      emit("ok", lang, "")
    else
      emit("fail", lang, ok and "did not compile — see :checkhealth nvim-treesitter" or tostring(err))
    end
  end
end
results:close()
LUA
    run_driver "$SYNC_TMP/parsers.lua" "$SYNC_TMP/parsers.tsv" "$SYNC_TMP/parsers.log"
    report_results "$SYNC_TMP/parsers.tsv" "$SYNC_TMP/parsers.log" "parsers" \
      || { SYNC_FAILURES="$SYNC_FAILURES parsers"; KEEP_SYNC_TMP=1; }

    # ── 7c. Language servers, formatters and linters ──────────────────────────
    step "Installing language servers and formatters"
    echo "  downloading via mason — npm/pip/github, so this needs the network"
    # Kept in sync by hand with the `servers` list in lua/plugins/lsp.lua and
    # `ensure_installed` in the mason-tool-installer spec there. Names are mason
    # package names, which differ from server names (`eslint` -> `eslint-lsp`).
    export DOTFILES_MASON="lua-language-server basedpyright ruff vtsls eslint-lsp json-lsp yaml-language-server taplo bash-language-server marksman html-lsp css-lsp dockerfile-language-server stylua prettierd shfmt markdownlint-cli2 shellcheck"
    cat > "$SYNC_TMP/mason.lua" <<'LUA'
local results = assert(io.open(assert(vim.env.DOTFILES_RESULTS), "w"))
local function emit(status, name, detail)
  results:write(("%s\t%s\t%s\n"):format(status, name, ((detail or ""):gsub("%s+", " "))))
  results:flush()
end

local wanted = vim.split(vim.trim(vim.env.DOTFILES_MASON or ""), "%s+", { trimempty = true })

-- mason.nvim is lazy-loaded on `:Mason*`, and this driver never runs those
-- commands, so ask lazy for it by name instead of relying on a side effect.
pcall(function()
  require("lazy").load({ plugins = { "mason.nvim" } })
end)

local ok_registry, registry = pcall(require, "mason-registry")
if not ok_registry then
  emit("fail", "mason.nvim", "mason is not installed: " .. tostring(registry))
  results:close()
  return
end

-- The registry index has to be fetched before any package can be resolved. A
-- stale-but-present index is still usable, so a refresh that fails or times out
-- is a warning, not a stop.
local refreshed = false
pcall(registry.refresh, function()
  refreshed = true
end)
if not vim.wait(180000, function()
  return refreshed
end, 100) then
  emit("skip", "mason-registry", "refresh timed out — using the cached registry")
end

local TIMEOUT = tonumber(vim.env.DOTFILES_MASON_TIMEOUT or "") or 600000

--- Runs one install to completion. Returns ok, detail.
--- Both streams are captured here rather than forwarded, which is the whole
--- point of this driver — see the long comment in install.sh.
local function attempt(pkg)
  local output, done, succeeded, err = {}, false, false, nil
  local handle = pkg:install({}, function(success, install_err)
    succeeded, err, done = success, install_err, true
  end)
  handle:on("stdout", function(chunk)
    output[#output + 1] = chunk
  end)
  handle:on("stderr", function(chunk)
    output[#output + 1] = chunk
  end)

  if not vim.wait(TIMEOUT, function()
    return done
  end, 200) then
    pcall(function()
      handle:terminate()
    end)
    return false, ("timed out after %ds"):format(TIMEOUT / 1000)
  end

  if succeeded then
    return true, nil
  end

  -- Report the installer's own last words; they name the actual cause (a 404, a
  -- missing python3, a proxy refusing the connection) far more often than
  -- mason's wrapper error does.
  local last
  for line in table.concat(output):gmatch("[^\r\n]+") do
    if vim.trim(line) ~= "" then
      last = vim.trim(line)
    end
  end
  return false, table.concat(vim.tbl_filter(function(s)
    return s ~= nil and s ~= ""
  end, { err and tostring(err) or nil, last }), " | ")
end

for _, name in ipairs(wanted) do
  local ok_pkg, pkg = pcall(registry.get_package, name)
  if not ok_pkg then
    -- A renamed or dropped mason package: report the name, keep going.
    emit("fail", name, "not a mason package (renamed or removed?)")
  elseif pkg:is_installed() then
    emit("present", name, "")
  else
    local ok, detail = attempt(pkg)
    if not ok then
      -- One retry. Most failures here are transient — a registry mirror hiccup,
      -- a half-written download — and cost seconds to redo.
      vim.wait(2000)
      local retry_ok, retry_detail = attempt(pkg)
      ok, detail = retry_ok, retry_detail or detail
    end
    emit(ok and "ok" or "fail", name, detail)
  end
end
results:close()
LUA
    run_driver "$SYNC_TMP/mason.lua" "$SYNC_TMP/mason.tsv" "$SYNC_TMP/mason.log"
    report_results "$SYNC_TMP/mason.tsv" "$SYNC_TMP/mason.log" "tools" \
      || { SYNC_FAILURES="$SYNC_FAILURES tools"; KEEP_SYNC_TMP=1; }
  fi
fi

# ── Done ──────────────────────────────────────────────────────────────────────
step "Done"

# A partial sync leaves a working editor with gaps, and the gaps are invisible
# until you open a file of the affected language. Repeat them here, with the
# in-editor command that retries each — re-running install.sh is never required,
# every one of these is fixable from inside Neovim.
if [ -n "$SYNC_FAILURES" ]; then
  warn "some items did not install:"
  case "$SYNC_FAILURES" in
    *plugins*) echo "         plugins  — open Neovim and run  :Lazy sync" ;;
  esac
  case "$SYNC_FAILURES" in
    *parsers*) echo "         parsers  — :checkhealth nvim-treesitter, then  :TSInstall <lang>" ;;
  esac
  case "$SYNC_FAILURES" in
    *tools*)   echo "         tools    — :Mason, then  i  on the package to retry it" ;;
  esac
  echo "         The failing item's own error is printed above, and the full"
  echo "         log was kept at the path named next to it."
  echo
fi

cat <<'EOF'
  Start Neovim with:  nvim

  First things to try:
    <Space>            open the keybinding menu (which-key)
    <Space>sk          search every keymap
    <Space><Space>     find files
    <Space>e           file explorer
    <Space>gg          lazygit
    :CheckIcons        verify your font renders the icons
    :checkhealth       diagnose anything still missing

  Clipboard note: yanking to the system clipboard needs wl-clipboard (Wayland)
  or xclip/xsel (X11). Over ssh it works with no tool at all, via OSC 52.
EOF
