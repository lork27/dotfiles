# Windows PowerShell profile. windows\apply.ps1 copies this into
# Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1.

# zoxide - smarter directory jumping
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    zoxide init powershell | Out-String | Invoke-Expression
}

# YoRHa theme - the same NieR: Automata palette the dotfiles use for Zed,
# Ghostty, Windows Terminal and Herdr. The mode follows Windows' own light/dark
# app setting (AppsUseLightTheme), like .zshrc reads AppleInterfaceStyle on macOS.
$YorhaMode = 'light'
try {
    $personalize = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey(
        'Software\Microsoft\Windows\CurrentVersion\Themes\Personalize')
    if ($personalize -and $personalize.GetValue('AppsUseLightTheme') -eq 0) {
        $YorhaMode = 'dark'
    }
}
catch { }
if ($env:YORHA_MODE -eq 'light' -or $env:YORHA_MODE -eq 'dark') {
    $YorhaMode = $env:YORHA_MODE
}

# Colors come from the Windows Terminal scheme (which Herdr's theme = "terminal"
# also follows), so nothing is set on the PowerShell host here: Windows PowerShell
# only offers the 16 named console colors, and overriding them would fight the
# scheme on hosts that do support true color.

# Claude Code: launch with the ANSI theme matching the mode above. Windows
# PowerShell mangles embedded quotes in native arguments, so the theme goes through
# a generated settings file instead of --settings '<json>'.
$ClaudeThemeFile = Join-Path $HOME '.claude\yorha-theme.json'
$ClaudeTheme = if ($YorhaMode -eq 'light') { 'light-ansi' } else { 'dark-ansi' }
if (Test-Path (Join-Path $HOME '.claude')) {
    try {
        [System.IO.File]::WriteAllText($ClaudeThemeFile, ('{"theme":"' + $ClaudeTheme + '"}'),
            (New-Object System.Text.UTF8Encoding($false)))
    }
    catch { }
}

function claude {
    $external = Get-Command claude -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $external) {
        Write-Host 'claude: not found on PATH'
        return
    }
    if (Test-Path $ClaudeThemeFile) {
        & $external.Source --settings $ClaudeThemeFile $args
    }
    else {
        & $external.Source $args
    }
}
