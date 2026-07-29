#!/usr/bin/env bash
#
# Installs this Neovim configuration on Linux (and macOS).
#
#   ./install.sh              link the config, report what is missing
#   ./install.sh --tools      also install the missing system packages
#   ./install.sh --tools --sync   ...and install all plugins and parsers
#
# Symlinks ~/.config/nvim to the nvim/ directory in this repo. The Windows
# counterpart is install.ps1, which uses a directory junction instead (a symlink
# on Windows needs Administrator or Developer Mode; a junction does not).

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
    -h|--help) sed -n '2,12p' "$0" | sed 's/^# \?//'; exit 0 ;;
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
# pacman also gets `rust-analyzer`, `rust-src` and `lazygit` from the repos.
# Arch's `rust` package does not ship the standard-library sources that
# go-to-definition needs, and pacman's `rustup` *conflicts* with `rust` — so on
# Arch the distro packages are the only route, not a convenience. `rust-src`
# depends on `rust`, which version-locks it to the installed rustc.
pkgs_for() {
  case "$PM" in
    apt)    echo "git curl tar unzip build-essential ripgrep fd-find imagemagick npm python3 python3-venv wl-clipboard xclip fontconfig" ;;
    dnf)    echo "git curl tar unzip gcc gcc-c++ make ripgrep fd-find ImageMagick npm python3 wl-clipboard xclip fontconfig" ;;
    pacman) echo "git curl tar unzip base-devel ripgrep fd imagemagick npm python wl-clipboard xclip fontconfig rust-analyzer rust-src lazygit" ;;
    zypper) echo "git curl tar unzip gcc gcc-c++ make ripgrep fd ImageMagick npm python3 wl-clipboard xclip fontconfig" ;;
    apk)    echo "git curl tar unzip build-base ripgrep fd imagemagick npm python3 wl-clipboard xclip fontconfig" ;;
    brew)   echo "git curl ripgrep fd imagemagick node python3 lazygit" ;;
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
  if ! have nvim || ! nvim --version | head -1 | grep -qE 'v0\.(1[2-9]|[2-9][0-9])'; then
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
step "Checking for a Nerd Font"
if have fc-list && fc-list 2>/dev/null | grep -qi "nerd font"; then
  ok "a Nerd Font is installed"
else
  warn "No Nerd Font detected — icons will render as boxes."
  echo "         Install JetBrains Mono Nerd Font:"
  echo "           mkdir -p ~/.local/share/fonts && cd ~/.local/share/fonts"
  echo "           curl -fLO https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
  echo "           unzip -o JetBrainsMono.zip && fc-cache -fv"
  echo "         Then set it in ~/.config/wezterm/wezterm.lua (config.font)."
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

# ── 5. WezTerm config ─────────────────────────────────────────────────────────
# The WezTerm config is NOT part of this repo (by design — it is one file), but it
# lives at a path that is identical on both platforms, so mention it.
step "WezTerm"
WEZ_TARGET="${XDG_CONFIG_HOME:-$HOME/.config}/wezterm/wezterm.lua"
if [ -f "$WEZ_TARGET" ]; then
  ok "found $WEZ_TARGET"
else
  warn "no WezTerm config at $WEZ_TARGET"
  echo "         Copy it from your other machine — the path is the same on"
  echo "         Windows and Linux, so the file needs no changes."
fi

# ── 6. Sync plugins ───────────────────────────────────────────────────────────
if [ "$SYNC" = "1" ]; then
  step "Installing plugins"
  nvim --headless "+Lazy! sync" +qa 2>&1 | sed 's/^/    /' || true

  step "Installing treesitter parsers"
  # No 'jsonc' — it is an alias onto the 'json' parser, not a parser itself.
  PARSERS="'lua','luadoc','vim','vimdoc','query','markdown','markdown_inline','bash','rust','python','typescript','javascript','tsx','json','yaml','toml','html','css','scss','regex','diff','git_config','git_rebase','gitcommit','gitignore','dockerfile','make','cmake','ninja','printf','xml','sql','ssh_config','comment','rst','requirements','jsdoc'"
  nvim --headless "+lua require('nvim-treesitter').install({$PARSERS}):wait(900000)" +qa 2>&1 | sed 's/^/    /' || true

  step "Installing language servers and formatters"
  MASON="lua-language-server basedpyright ruff vtsls eslint-lsp json-lsp yaml-language-server taplo bash-language-server marksman html-lsp css-lsp dockerfile-language-server stylua prettierd shfmt markdownlint-cli2 shellcheck"
  # shellcheck disable=SC2086
  nvim --headless "+MasonInstall $MASON" +qa 2>&1 | tail -5 | sed 's/^/    /' || true
fi

# ── Done ──────────────────────────────────────────────────────────────────────
step "Done"
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
