<#
.SYNOPSIS
    Installs or updates pwsh-profile.
.DESCRIPTION
    1. Clones the repo to ~/.pwsh-profile (or downloads a zip if git is missing).
    2. Adds one line to your profile(s) that loads it. On Windows, both
       PowerShell 7 and Windows PowerShell 5.1 profiles are set up.
    3. Backs up any profile file it changes. Running it again is safe.

    One-liner:
        irm https://raw.githubusercontent.com/vspayce/pwsh-profile/main/install.ps1 | iex
.PARAMETER InstallPath
    Where the repo lives. Default: ~/.pwsh-profile
.PARAMETER Uninstall
    Removes the loader line from your profiles (leaves the folder in place).
#>
[CmdletBinding()]
param(
    [string]$InstallPath = (Join-Path $HOME '.pwsh-profile'),
    [string]$Repo = 'vspayce/pwsh-profile',
    [string]$Branch = 'main',
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSEdition -ne 'Core') {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
}
$isWin = [Environment]::OSVersion.Platform -eq 'Win32NT'
$markerStart = '# >>> pwsh-profile >>>'
$markerEnd   = '# <<< pwsh-profile <<<'

function Write-Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }

# --- which profile files to wire up ---------------------------------------
$targets = [System.Collections.Generic.List[string]]::new()
if ($isWin) {
    $docs = [Environment]::GetFolderPath('MyDocuments')   # follows OneDrive redirection
    $targets.Add((Join-Path $docs 'PowerShell\profile.ps1'))          # PowerShell 7+
    $targets.Add((Join-Path $docs 'WindowsPowerShell\profile.ps1'))   # Windows PowerShell 5.1
} else {
    $targets.Add($PROFILE.CurrentUserAllHosts)                        # ~/.config/powershell/profile.ps1
}

function Remove-LoaderBlock([string]$text) {
    $pattern = '(?s)\r?\n?' + [regex]::Escape($markerStart) + '.*?' + [regex]::Escape($markerEnd) + '\r?\n?'
    [regex]::Replace($text, $pattern, "`n").TrimEnd()
}

if ($Uninstall) {
    foreach ($t in $targets) {
        if (-not (Test-Path $t)) { continue }
        $text = [IO.File]::ReadAllText($t)
        if ($text.Contains($markerStart)) {
            [IO.File]::WriteAllText($t, (Remove-LoaderBlock $text) + "`n")
            Write-Step "Removed loader from $t"
        }
    }
    Write-Host "Done. The folder $InstallPath was left in place - delete it if you like." -ForegroundColor Green
    return
}

# --- get the code -----------------------------------------------------------
$git = Get-Command git -ErrorAction SilentlyContinue
if (Test-Path (Join-Path $InstallPath '.git')) {
    if (-not $git) { throw "$InstallPath is a git clone but git is not installed." }
    Write-Step "Updating $InstallPath"
    git -C $InstallPath pull --ff-only
    if ($LASTEXITCODE -ne 0) { throw 'git pull failed - do you have local changes in the profile folder?' }
} elseif ($git) {
    if (Test-Path $InstallPath) {
        $backup = "$InstallPath.bak-$(Get-Date -Format yyyyMMdd-HHmmss)"
        Write-Step "Moving existing $InstallPath to $backup"
        Move-Item $InstallPath $backup
    }
    Write-Step "Cloning github.com/$Repo to $InstallPath"
    git clone --branch $Branch "https://github.com/$Repo.git" $InstallPath
    if ($LASTEXITCODE -ne 0) { throw 'git clone failed.' }
    if ($backup) {
        foreach ($keep in 'local.ps1', 'Functions/Local') {
            $src = Join-Path $backup $keep
            if (Test-Path $src) { Copy-Item $src (Join-Path $InstallPath $keep) -Recurse -Force; Write-Step "Kept your $keep" }
        }
    }
} else {
    Write-Step "git not found - downloading a zip instead (Update-Profile will re-run this installer)"
    $tmp = Join-Path ([IO.Path]::GetTempPath()) "pwsh-profile-$([guid]::NewGuid().ToString('N'))"
    $null = New-Item -ItemType Directory -Path $tmp
    $zip = Join-Path $tmp 'repo.zip'
    Invoke-WebRequest -Uri "https://github.com/$Repo/archive/refs/heads/$Branch.zip" -OutFile $zip -UseBasicParsing
    Expand-Archive -Path $zip -DestinationPath $tmp
    $src = Get-ChildItem $tmp -Directory | Select-Object -First 1
    $null = New-Item -ItemType Directory -Path $InstallPath -Force
    # Replace everything except your machine-local files
    Get-ChildItem $InstallPath -Force | Where-Object { $_.Name -notin 'local.ps1', 'Functions' } | Remove-Item -Recurse -Force
    $fnDir = Join-Path $InstallPath 'Functions'
    if (Test-Path $fnDir) { Get-ChildItem $fnDir -Force | Where-Object Name -ne 'Local' | Remove-Item -Recurse -Force }
    Copy-Item (Join-Path $src.FullName '*') $InstallPath -Recurse -Force
    Remove-Item $tmp -Recurse -Force
}

if ($isWin) { Get-ChildItem $InstallPath -Recurse -File -Filter *.ps1 | Unblock-File }

# --- wire up the profile(s) ---------------------------------------------------
$loader = Join-Path $InstallPath 'profile.ps1'
$block = @"
$markerStart
# Loads https://github.com/$Repo - edit machine-only settings in $(Join-Path $InstallPath 'local.ps1')
if (Test-Path '$($loader -replace "'", "''")') { . '$($loader -replace "'", "''")' }
$markerEnd
"@

foreach ($t in $targets) {
    $dir = Split-Path $t -Parent
    if (-not (Test-Path $dir)) { $null = New-Item -ItemType Directory -Path $dir -Force }
    $existing = if (Test-Path $t) { [IO.File]::ReadAllText($t) } else { '' }
    if ($existing.Contains($markerStart)) {
        $new = (Remove-LoaderBlock $existing) + "`n" + $block + "`n"
        if ($new.Trim() -eq $existing.Trim()) { Write-Step "Already set up: $t"; continue }
    } else {
        if ($existing) {
            Copy-Item $t "$t.bak-$(Get-Date -Format yyyyMMdd-HHmmss)"
            Write-Step "Backed up existing $t"
        }
        $new = $existing.TrimEnd() + "`n" + $block + "`n"
    }
    [IO.File]::WriteAllText($t, $new.TrimStart())
    Write-Step "Loader added to $t"
}

# --- execution policy (Windows) ------------------------------------------------
if ($isWin) {
    $policy = Get-ExecutionPolicy
    if ($policy -in 'Restricted', 'AllSigned', 'Undefined') {
        Write-Step "Execution policy is '$policy' - setting CurrentUser to RemoteSigned so the profile can run"
        try { Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force } catch { Write-Warning "Could not change execution policy: $_" }
    }
}

$local = Join-Path $InstallPath 'local.ps1'
if (-not (Test-Path $local)) { Copy-Item (Join-Path $InstallPath 'local.example.ps1') $local }

Write-Host ''
Write-Host 'pwsh-profile installed. Open a new terminal, then try:' -ForegroundColor Green
Write-Host '  pf          list every function and alias'
Write-Host '  ep -Local   edit settings for this machine only'
