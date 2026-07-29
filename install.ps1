<#
.SYNOPSIS
    Installs this Neovim configuration on Windows.

.DESCRIPTION
    Links %LOCALAPPDATA%\nvim to the nvim/ directory in this repo, checks that the
    external tools the config depends on are present, and optionally installs the
    missing ones with winget.

    A DIRECTORY JUNCTION is used rather than a symbolic link. This matters: on
    Windows, creating a symlink requires either Administrator rights or Developer
    Mode, while a junction requires neither. Neovim, git and every plugin follow
    junctions transparently, so there is no downside for a same-volume link.

.PARAMETER InstallTools
    Install any missing external tools via winget.

.PARAMETER Sync
    After linking, run Neovim headless to install and pin all plugins.

.PARAMETER Force
    Replace an existing config without prompting (the old one is still backed up).

.EXAMPLE
    .\install.ps1 -InstallTools -Sync
#>
[CmdletBinding()]
param(
    [switch]$InstallTools,
    [switch]$Sync,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$RepoRoot   = $PSScriptRoot
$NvimSource = Join-Path $RepoRoot 'nvim'
$NvimTarget = Join-Path $env:LOCALAPPDATA 'nvim'

function Write-Step  { param($m) Write-Host "`n=== $m ===" -ForegroundColor Magenta }
function Write-Ok    { param($m) Write-Host "  [ok]   $m" -ForegroundColor Green }
function Write-Warn2 { param($m) Write-Host "  [warn] $m" -ForegroundColor Yellow }
function Write-Err2  { param($m) Write-Host "  [FAIL] $m" -ForegroundColor Red }

# ─────────────────────────────────────────────────────────────────────────────
# 0. Sanity checks
# ─────────────────────────────────────────────────────────────────────────────
Write-Step "Checking prerequisites"

if (-not (Test-Path $NvimSource)) {
    Write-Err2 "No nvim/ directory found at $NvimSource. Run this from the repo root."
    exit 1
}

# Rebuild PATH from the registry. Newly installed tools are on the *user* PATH but
# not in this process's environment, so a check here would spuriously fail right
# after installing something.
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
            [Environment]::GetEnvironmentVariable('Path', 'User')

function Test-Tool { param($Name) return [bool](Get-Command $Name -ErrorAction SilentlyContinue) }

# name = winget id; $null means "cannot be installed by winget, see notes"
$Tools = [ordered]@{
    'nvim'          = @{ Id = 'Neovim.Neovim';             Why = 'the editor itself';                   Required = $true  }
    'git'           = @{ Id = 'Git.Git';                   Why = 'plugin manager clones over git';      Required = $true  }
    'rg'            = @{ Id = 'BurntSushi.ripgrep.MSVC';   Why = 'grep picker and :grep';               Required = $true  }
    'fd'            = @{ Id = 'sharkdp.fd';                Why = 'fast file picker';                    Required = $false }
    'lazygit'       = @{ Id = 'JesseDuffield.lazygit';     Why = 'git UI on <leader>gg';                Required = $false }
    'node'          = @{ Id = 'OpenJS.NodeJS.LTS';         Why = 'TypeScript LSP, prettier, jest';      Required = $false }
    'zig'           = @{ Id = 'zig.zig';                   Why = 'C compiler for treesitter parsers';   Required = $true  }
    'magick'        = @{ Id = 'ImageMagick.ImageMagick';   Why = 'image viewing (non-PNG conversion)';  Required = $false }
    'tree-sitter'   = @{ Id = $null;                       Why = 'treesitter parser generator';         Required = $true  }
    'rust-analyzer' = @{ Id = $null;                       Why = 'Rust LSP';                            Required = $false }
}

$missing = @()
foreach ($name in $Tools.Keys) {
    $t = $Tools[$name]
    if (Test-Tool $name) {
        Write-Ok "$name"
    } else {
        $missing += $name
        if ($t.Required) { Write-Err2 "$name missing - $($t.Why)" }
        else             { Write-Warn2 "$name missing - $($t.Why)" }
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# 1. Install missing tools
# ─────────────────────────────────────────────────────────────────────────────
if ($missing.Count -gt 0 -and $InstallTools) {
    Write-Step "Installing missing tools"

    foreach ($name in $missing) {
        $t = $Tools[$name]

        if ($t.Id) {
            Write-Host "  installing $name ($($t.Id))..."
            winget install --id $t.Id -e --accept-package-agreements `
                           --accept-source-agreements --disable-interactivity | Out-Null
            if ($LASTEXITCODE -eq 0) { Write-Ok "$name installed" }
            else { Write-Warn2 "$name install returned $LASTEXITCODE" }
        }
        elseif ($name -eq 'tree-sitter') {
            # Not in winget. Building from source needs libclang, so fetch the
            # prebuilt release binary into ~/.local/bin instead.
            Write-Host "  downloading tree-sitter CLI..."
            $binDir = Join-Path $env:USERPROFILE '.local\bin'
            New-Item -ItemType Directory -Force $binDir | Out-Null
            $rel = Invoke-RestMethod 'https://api.github.com/repos/tree-sitter/tree-sitter/releases/latest' `
                                     -Headers @{ 'User-Agent' = 'pwsh' }
            $asset = $rel.assets | Where-Object { $_.name -eq 'tree-sitter-windows-x64.gz' }
            $gz = Join-Path $env:TEMP 'tree-sitter.gz'
            Invoke-WebRequest $asset.browser_download_url -OutFile $gz -UseBasicParsing
            $in  = [System.IO.File]::OpenRead($gz)
            $out = [System.IO.File]::Create((Join-Path $binDir 'tree-sitter.exe'))
            $gzs = New-Object System.IO.Compression.GZipStream($in, [System.IO.Compression.CompressionMode]::Decompress)
            $gzs.CopyTo($out); $gzs.Dispose(); $out.Dispose(); $in.Dispose()
            Remove-Item $gz -Force

            $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
            if ($userPath -notlike "*$binDir*") {
                [Environment]::SetEnvironmentVariable('Path', "$userPath;$binDir", 'User')
                Write-Ok "added $binDir to user PATH"
            }
            $env:Path += ";$binDir"
            Write-Ok "tree-sitter $($rel.tag_name) installed"
        }
        elseif ($name -eq 'rust-analyzer') {
            if (Test-Tool 'rustup') {
                Write-Host "  adding rust-analyzer component..."
                rustup component add rust-analyzer | Out-Null
                Write-Ok "rust-analyzer installed"
            } else {
                Write-Warn2 "rustup not found - install Rust from https://rustup.rs to get rust-analyzer"
            }
        }
    }

    # Re-read PATH so the checks below see what we just installed.
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path', 'User')
}
elseif ($missing.Count -gt 0) {
    Write-Warn2 "Re-run with -InstallTools to install the missing tools automatically."
}

# ─────────────────────────────────────────────────────────────────────────────
# 2. A Nerd Font is required for the icons
# ─────────────────────────────────────────────────────────────────────────────
Write-Step "Checking for a Nerd Font"

$fontDirs = @(
    (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'),
    (Join-Path $env:SystemRoot   'Fonts')
)
$nerd = $fontDirs | Where-Object { Test-Path $_ } | ForEach-Object {
    Get-ChildItem $_ -Filter '*.ttf' -ErrorAction SilentlyContinue
} | Where-Object { $_.Name -match 'NerdFont|Nerd Font|NF-' } | Select-Object -First 1

if ($nerd) {
    Write-Ok "found $($nerd.Name)"
} else {
    Write-Warn2 "No Nerd Font detected. Icons will render as boxes."
    Write-Host  "         Install one with:  winget install DEVCOM.JetBrainsMonoNerdFont"
    Write-Host  "         Then set it in ~/.config/wezterm/wezterm.lua (config.font)."
}

# ─────────────────────────────────────────────────────────────────────────────
# 3. Link the config into place
# ─────────────────────────────────────────────────────────────────────────────
Write-Step "Linking Neovim config"

if (Test-Path $NvimTarget) {
    $item = Get-Item $NvimTarget -Force

    # Already linked to the right place? Nothing to do.
    if ($item.LinkType -and $item.Target -and ($item.Target -contains $NvimSource)) {
        Write-Ok "already linked: $NvimTarget -> $NvimSource"
    }
    else {
        if ($item.LinkType) {
            Write-Warn2 "$NvimTarget is a $($item.LinkType) pointing at $($item.Target)"
        } else {
            Write-Warn2 "$NvimTarget already exists as a real directory"
        }

        if (-not $Force) {
            $answer = Read-Host "  Back it up and replace? [y/N]"
            if ($answer -notmatch '^[Yy]') { Write-Host "  Aborted."; exit 1 }
        }

        # Timestamped backup so repeated runs never clobber an earlier one.
        $stamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
        $backup = "$NvimTarget.backup-$stamp"
        if ($item.LinkType) {
            # Removing a link must not touch the link *target*, so delete the
            # reparse point directly rather than recursing into it.
            [System.IO.Directory]::Delete($NvimTarget, $false)
            Write-Ok "removed old link"
        } else {
            Move-Item $NvimTarget $backup
            Write-Ok "backed up to $backup"
        }
    }
}

if (-not (Test-Path $NvimTarget)) {
    New-Item -ItemType Junction -Path $NvimTarget -Target $NvimSource | Out-Null
    Write-Ok "junction created: $NvimTarget -> $NvimSource"
}

# Neovim also keeps state (plugins, undo history, shada) separately. Mention it so
# a "clean reinstall" is discoverable.
$dataDir = Join-Path $env:LOCALAPPDATA 'nvim-data'
Write-Host "  plugin + state directory: $dataDir"
Write-Host "  (delete it for a completely clean reinstall)"

# ─────────────────────────────────────────────────────────────────────────────
# 4. Sync plugins
# ─────────────────────────────────────────────────────────────────────────────
if ($Sync) {
    Write-Step "Installing plugins (this takes a minute on a fresh install)"

    & nvim --headless "+Lazy! sync" +qa 2>&1 | ForEach-Object { "    $_" }

    Write-Step "Installing treesitter parsers"
    # No 'jsonc' — it is an alias onto the 'json' parser, not a parser itself.
    $parsers = @('lua','luadoc','vim','vimdoc','query','markdown','markdown_inline','bash',
                 'rust','python','typescript','javascript','tsx','json',
                 'yaml','toml','html','css','scss','regex','diff','git_config','git_rebase',
                 'gitcommit','gitignore','dockerfile','make','cmake','ninja','printf',
                 'xml','sql','ssh_config','comment','rst','requirements','jsdoc')
    $list = ($parsers | ForEach-Object { "'$_'" }) -join ','
    & nvim --headless "+lua require('nvim-treesitter').install({$list}):wait(600000)" +qa 2>&1 |
        ForEach-Object { "    $_" }

    Write-Step "Health check"
    & nvim --headless "+checkhealth" "+w! $env:TEMP\nvim-health.txt" +qa 2>&1 | Out-Null
    Write-Host "  full report written to $env:TEMP\nvim-health.txt"
}

# ─────────────────────────────────────────────────────────────────────────────
Write-Step "Done"
Write-Host @"
  Start Neovim with:  nvim

  First things to try:
    <Space>            open the keybinding menu (which-key)
    <Space>sk          search every keymap
    <Space><Space>     find files
    <Space>e           file explorer
    <Space>gg          lazygit
    :CheckIcons        verify your font renders the icons
    :checkhealth       diagnose anything still missing

  If icons look wrong, the font is set in WezTerm, not Neovim:
    ~/.config/wezterm/wezterm.lua
"@ -ForegroundColor Cyan
