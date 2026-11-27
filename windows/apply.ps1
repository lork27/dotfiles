# Applies this repo's Windows-side configs: Zed (settings + Yorha palette),
# Herdr, Windows Terminal (YoRHa color schemes merged into its own settings.json)
# and the PowerShell profile. Windows apps rewrite their own config files, so these
# are copied rather than symlinked; an existing file is backed up once to <name>.bak
# before being replaced.
#
#   powershell -NoProfile -File windows\apply.ps1 [-DryRun] [-Light | -Dark]
#
# The palette follows Windows' own light/dark setting
# (HKCU\...\Themes\Personalize\AppsUseLightTheme, 0 = dark), the same idea as the
# macOS .zshrc reading AppleInterfaceStyle. -Light / -Dark override it.

param([switch] $DryRun, [switch] $Light, [switch] $Dark)

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot

function Get-YorhaMode {
    if ($Light -and $Dark) {
        Write-Host 'error: -Light and -Dark conflict'
        exit 2
    }
    if ($Light) { return 'light' }
    if ($Dark) { return 'dark' }
    $mode = 'light'
    try {
        $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey(
            'Software\Microsoft\Windows\CurrentVersion\Themes\Personalize')
        if ($key -and $key.GetValue('AppsUseLightTheme') -eq 0) { $mode = 'dark' }
    }
    catch { }
    if ($env:YORHA_MODE -eq 'light' -or $env:YORHA_MODE -eq 'dark') { $mode = $env:YORHA_MODE }
    return $mode
}

$YorhaMode = Get-YorhaMode
$YorhaScheme = if ($YorhaMode -eq 'light') { 'Yorha' } else { 'Yorha Dark' }

function Read-Text {
    param([string] $Path)
    $t = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    # Git checks these out with CRLF on Windows; keep the apps' files LF.
    $t -replace "`r`n", "`n"
}

function Write-Text {
    param([string] $Path, [string] $Text)
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    # .NET writes UTF-8 without a BOM, which JSON/TOML parsers expect.
    [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($false)))
}

function Backup-Once {
    param([string] $Path)
    # Keep the pre-dotfiles original: only create the .bak if there is no backup
    # yet, so later runs never overwrite it.
    if ((Test-Path -LiteralPath $Path) -and -not (Test-Path -LiteralPath "$Path.bak")) {
        Copy-Item -LiteralPath $Path -Destination "$Path.bak"
        Write-Host "backed up: $Path.bak"
    }
}

function Install-File {
    param([string] $Source, [string] $Target, [scriptblock] $Transform, [string] $RequireDir)

    if ($RequireDir -and -not (Test-Path -LiteralPath $RequireDir)) {
        Write-Host "skip (not installed: $RequireDir)"
        return
    }
    if (-not (Test-Path -LiteralPath $Source)) {
        Write-Host "skip (missing source): $Source"
        return
    }
    $new = Read-Text $Source
    if ($Transform) { $new = & $Transform $new }
    if ((Test-Path -LiteralPath $Target) -and ((Read-Text $Target) -eq $new)) {
        Write-Host "up to date: $Target"
        return
    }
    if ($DryRun) {
        Write-Host "would write: $Target"
        return
    }
    Backup-Once $Target
    Write-Text $Target $new
    Write-Host "wrote: $Target"
}

function Merge-ByName {
    param([array] $Existing, [array] $Incoming)
    $list = New-Object System.Collections.ArrayList
    foreach ($item in @($Existing)) { [void] $list.Add($item) }
    foreach ($item in @($Incoming)) {
        $index = -1
        for ($i = 0; $i -lt $list.Count; $i++) {
            if ($list[$i].name -eq $item.name) { $index = $i; break }
        }
        if ($index -ge 0) { $list[$index] = $item } else { [void] $list.Add($item) }
    }
    , @($list)
}

function Install-WindowsTerminal {
    param([string] $Source)

    # A Microsoft Store install keeps its settings inside the installed package's
    # LocalState folder; the unpackaged build uses
    # %LOCALAPPDATA%\Microsoft\Windows Terminal\settings.json. Only Fragments\
    # under the latter is read by the Store build, so target whichever exists and
    # never create a file for a build that is not there.
    $Target = $null
    $candidates = @(
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
        "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
    )
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) { $Target = $candidate; break }
    }
    if (-not $Target) {
        Write-Host "skip (Windows Terminal settings.json not found; not installed?)"
        return
    }
    if (-not (Test-Path -LiteralPath $Source)) {
        Write-Host "skip (missing source): $Source"
        return
    }

    try {
        $defs = ConvertFrom-JSON (Read-Text $Source)
        if (Test-Path -LiteralPath $Target) {
            $settings = ConvertFrom-JSON (Read-Text $Target)
        }
        else { $settings = $null }
    }
    catch {
        Write-Host "skip (could not parse JSON: $($_.Exception.Message))"
        return
    }
    if (-not $settings) { $settings = [pscustomobject]@{} }

    if (-not $settings.PSObject.Properties['schemes']) {
        Add-Member -InputObject $settings -MemberType NoteProperty -Name schemes -Value @()
    }
    $settings.schemes = Merge-ByName $settings.schemes $defs.schemes
    if (-not $settings.PSObject.Properties['profiles']) {
        Add-Member -InputObject $settings -MemberType NoteProperty -Name profiles -Value ([pscustomobject]@{})
    }
    if (-not $settings.profiles.PSObject.Properties['defaults']) {
        Add-Member -InputObject $settings.profiles -MemberType NoteProperty -Name defaults -Value ([pscustomobject]@{})
    }
    # Drop whichever selector we wrote before so colorScheme and theme never fight.
    foreach ($key in 'theme', 'colorScheme') {
        if ($settings.profiles.defaults.PSObject.Properties[$key]) {
            $settings.profiles.defaults.PSObject.Properties.Remove($key)
        }
    }
    # The scheme is this machine's, not the file's: it comes from the Windows
    # light/dark setting (or -Light / -Dark).
    Add-Member -InputObject $settings.profiles.defaults -MemberType NoteProperty -Name colorScheme -Value $YorhaScheme -Force
    # An earlier run may also have set a top-level theme pointing at a themes entry
    # that no longer exists; drop it so nothing stale is left behind.
    if ($settings.PSObject.Properties['theme'] -and $settings.theme -eq 'YoRHa') {
        $settings.PSObject.Properties.Remove('theme')
    }

    # Runs from before selected a "YoRHa" themes entry; drop it so only the
    # explicit colorScheme is left in control.
    if ($settings.PSObject.Properties['themes']) {
        $settings.themes = @($settings.themes | Where-Object { $_.name -ne 'YoRHa' })
    }

    # ConvertTo-JSON escapes < > & ' as \u00xx; put them back so profile commandlines
    # stay readable. Note: this rewrite drops any comments in the settings file.
    $new = ($settings | ConvertTo-JSON -Depth 12) -replace "`r`n", "`n"
    $new = $new.Replace('\u003c', '<').Replace('\u003e', '>').Replace('\u0026', '&').Replace('\u0027', '''')
    if ((Test-Path -LiteralPath $Target) -and ((Read-Text $Target) -eq $new)) {
        Write-Host "up to date: $Target"
        return
    }
    if ($DryRun) {
        Write-Host "would write: $Target"
        return
    }
    Backup-Once $Target
    Write-Text $Target $new
    Write-Host "wrote: $Target ($YorhaScheme)"
}

# Zed: settings plus the Yorha / Yorha Dark palettes. Zed rewrites settings.json
# itself, so this file replaces it wholesale - edit windows/zed.settings.json instead
# of adding settings in %APPDATA%.
Install-File (Join-Path $RepoRoot 'windows\zed.settings.json') "$env:APPDATA\Zed\settings.json" $null "$env:APPDATA\Zed"
Install-File (Join-Path $RepoRoot 'themes\zed\yorha.json') "$env:APPDATA\Zed\themes\yorha.json" $null "$env:APPDATA\Zed"

# Herdr: same tracked config as macOS/Linux; theme = "terminal" then follows
# the Windows Terminal palette installed below.
Install-File (Join-Path $RepoRoot 'herdr.toml') "$env:APPDATA\herdr\config.toml" $null "$env:APPDATA\herdr"

# Windows Terminal: merge the YoRHa schemes and select the palette for this machine.
Install-WindowsTerminal (Join-Path $RepoRoot 'themes\windows-terminal\yorha.schemes.json')

# PowerShell profile (Windows PowerShell 5.1 path); it detects the mode itself.
$Documents = [Environment]::GetFolderPath('MyDocuments')
Install-File (Join-Path $RepoRoot 'windows\powershell.profile.ps1') "$Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"

Write-Host "Done (mode: $YorhaMode). Windows Terminal resolves its palette at startup: quit it and relaunch."
