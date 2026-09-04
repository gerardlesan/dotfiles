# ~/Documents/PowerShell/Microsoft.PowerShell_profile.ps1 ($PROFILE)
#
# TRACKED IN THE REPO, DEPLOYED ONLY ON WINDOWS by install.ps1, which copies
# this to $PROFILE (backing up whatever was there first). $PROFILE's actual
# location is OneDrive-redirected on this machine and not something a repo
# file can hardcode, hence letting install.ps1 resolve it at copy time rather
# than symlinking.

#f45873b3-b655-43a6-b217-97c00aa0db58 PowerToys CommandNotFound module

Import-Module -Name Microsoft.WinGet.CommandNotFound
#f45873b3-b655-43a6-b217-97c00aa0db58

# --- Fish-like abbreviations (expand on Space/Enter) ---
$global:Abbreviations = @{
    'cr'  = 'cargo run'
    'crb' = 'cargo run --bin'
    'cb'  = 'cargo build'
    'cc'  = 'cargo check'
}

function Expand-Abbreviation {
    param([switch]$OnlyIfWholeLine)

    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

    if ($line -notmatch '^(\S+)') { return }
    $firstWord = $Matches[1]
    if (-not $global:Abbreviations.ContainsKey($firstWord)) { return }

    # For Spacebar: only expand while the abbreviation is the only thing typed so far
    # (avoids re-expanding while editing later words on the same line).
    if ($OnlyIfWholeLine -and $line.Trim() -ne $firstWord) { return }

    $expansion = $global:Abbreviations[$firstWord]
    $diff = $expansion.Length - $firstWord.Length
    [Microsoft.PowerShell.PSConsoleReadLine]::Replace(0, $firstWord.Length, $expansion)
    [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + $diff)
}

Set-PSReadLineKeyHandler -Key Spacebar -ScriptBlock {
    Expand-Abbreviation -OnlyIfWholeLine
    [Microsoft.PowerShell.PSConsoleReadLine]::Insert(' ')
}

Set-PSReadLineKeyHandler -Key Enter -ScriptBlock {
    Expand-Abbreviation
    [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
}

# --- fastfetch: system info + WezTerm cheatsheet, WezTerm tabs only ---
# $env:WEZTERM_PANE is set by WezTerm on every pane it spawns and nowhere else,
# so this never fires in VS Code's integrated terminal, Windows Terminal, or a
# plain PowerShell window — exactly "when I open WezTerm", not every PowerShell
# launch anywhere. The Get-Command guard keeps a profile copied to a machine
# without fastfetch installed from erroring on every new tab.
if ($env:WEZTERM_PANE -and (Get-Command fastfetch -ErrorAction SilentlyContinue)) {
    fastfetch --config "$HOME\.config\fastfetch\config.jsonc"
}
