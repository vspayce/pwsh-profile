<#
.SYNOPSIS
    Copies a curated set of functions from jonlabelle/pwsh-profile into this repo.
.DESCRIPTION
    Jon LaBelle's profile (MIT licensed) has a large library of well-tested functions.
    This script pulls the ones listed in $Map below, drops them into our category
    folders, and adds the header lines our loader needs:

        # Alias: netdiag                     <- taken from the file's own Set-Alias lines
        # Source: jonlabelle/pwsh-profile    <- so you can tell which files are upstream

    Re-run it any time to pick up his fixes. Files that came from upstream are
    overwritten; your own files are never touched.

    To bring in another function, add it to $Map (and any functions it calls).
.EXAMPLE
    ./tools/Sync-Upstream.ps1
.EXAMPLE
    ./tools/Sync-Upstream.ps1 -SourcePath ~/src/jonlabelle-pwsh-profile
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    # An existing clone of jonlabelle/pwsh-profile. If omitted, a fresh shallow clone is made.
    [string]$SourcePath
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent

# upstream "Category/Name"  ->  our category folder
$Map = [ordered]@{
    # --- Network & DNS ---
    'NetworkAndDns/ConvertTo-CidrNotation'     = 'Network'
    'NetworkAndDns/Get-DnsRecord'              = 'Network'
    'NetworkAndDns/Get-IPAddress'              = 'Network'
    'NetworkAndDns/Get-IPSubnet'               = 'Network'
    'NetworkAndDns/Get-NetworkMetric'          = 'Network'
    'NetworkAndDns/Get-NetworkProcess'         = 'Network'
    'NetworkAndDns/Get-NetworkRoute'           = 'Network'
    'NetworkAndDns/Get-PublicDnsServer'        = 'Network'
    'NetworkAndDns/Get-ReverseDns'             = 'Network'
    'NetworkAndDns/Get-Whois'                  = 'Network'
    'NetworkAndDns/Invoke-NetworkDiagnostics'  = 'Network'
    'NetworkAndDns/Invoke-Ping'                = 'Network'
    'NetworkAndDns/Resolve-GeoIP'              = 'Network'
    'NetworkAndDns/Send-TcpRequest'            = 'Network'
    'NetworkAndDns/Show-NetworkLatencyGraph'   = 'Network'
    'NetworkAndDns/Test-Bandwidth'             = 'Network'
    'NetworkAndDns/Test-DnsNameResolution'     = 'Network'
    'NetworkAndDns/Test-DnsPropagation'        = 'Network'
    'NetworkAndDns/Test-HttpResponse'          = 'Network'
    'NetworkAndDns/Test-TlsProtocol'           = 'Network'
    'NetworkAndDns/Trace-Route'                = 'Network'
    # --- Security ---
    'Security/ConvertFrom-JwtToken'            = 'Security'
    'Security/Get-CertificateInfo'             = 'Security'
    'Security/Protect-PathWithPassword'        = 'Security'
    'Security/Unprotect-PathWithPassword'      = 'Security'
    # --- Active Directory ---
    'ActiveDirectory/Invoke-GroupPolicyUpdate' = 'ActiveDirectory'
    'ActiveDirectory/Test-ADCredential'        = 'ActiveDirectory'
    'ActiveDirectory/Test-ADUserLocked'        = 'ActiveDirectory'
    # --- System ---
    'SystemAdministration/Get-PathPermission'         = 'System'
    'SystemAdministration/Set-PathPermission'         = 'System'
    'SystemAdministration/Get-SystemInfo'             = 'System'
    'SystemAdministration/Get-TlsSecurityProtocol'    = 'System'
    'SystemAdministration/Set-TlsSecurityProtocol'    = 'System'
    'SystemAdministration/Invoke-ElevatedCommand'     = 'System'
    'SystemAdministration/Show-SystemResourceMonitor' = 'System'
    'SystemAdministration/Start-KeepAlive'            = 'System'
    'SystemAdministration/Test-Admin'                 = 'System'
    'SystemAdministration/Test-PendingReboot'         = 'System'
    # --- Module management ---
    'ModuleManagement/Get-OutdatedModule'      = 'ModuleManagement'
    'ModuleManagement/Remove-OldModule'        = 'ModuleManagement'
    'ModuleManagement/Update-AllModule'        = 'ModuleManagement'
    # --- Files & utilities ---
    'Utilities/Convert-LineEnding'             = 'Utilities'
    'Utilities/ConvertTo-TimeZone'             = 'Utilities'
    'Utilities/Copy-Directory'                 = 'Utilities'
    'Utilities/Extract-Archive'                = 'Utilities'
    'Utilities/Format-Byte'                    = 'Utilities'
    'Utilities/Get-CommandAlias'               = 'Utilities'
    'Utilities/Get-EncodingFromName'           = 'Utilities'
    'Utilities/Get-FileEncoding'               = 'Utilities'
    'Utilities/Get-StringHash'                 = 'Utilities'
    'Utilities/New-SymbolicLink'               = 'Utilities'
    'Utilities/Remove-OldFile'                 = 'Utilities'
    'Utilities/Remove-SymbolicLink'            = 'Utilities'
    'Utilities/Replace-StringInFile'           = 'Utilities'
    'Utilities/Search-DelimitedFile'           = 'Utilities'
    'Utilities/Search-FileContent'             = 'Utilities'
    'Utilities/Set-FileEncoding'               = 'Utilities'
    'Utilities/Show-FileStorageMetrics'        = 'Utilities'
    'Utilities/Sync-Directory'                 = 'Utilities'
}

# Upstream aliases we do not want (they clash with ours or with common commands)
$SkipAliases = @('which', 'New-Password', 'update', 'upgrade')

# --- get the source ------------------------------------------------------------------
$cleanup = $null
if (-not $SourcePath) {
    $SourcePath = Join-Path ([IO.Path]::GetTempPath()) "jonlabelle-pwsh-profile-$([guid]::NewGuid().ToString('N'))"
    git clone --quiet --depth 1 https://github.com/jonlabelle/pwsh-profile.git $SourcePath
    if ($LASTEXITCODE -ne 0) { throw 'git clone of jonlabelle/pwsh-profile failed.' }
    $cleanup = $SourcePath
}
$commit = (git -C $SourcePath rev-parse --short HEAD 2>$null)
if (-not $commit) { $commit = 'unknown' }

$utf8Bom = [Text.UTF8Encoding]::new($true)
$count = 0
foreach ($entry in $Map.GetEnumerator()) {
    $src = Join-Path $SourcePath "Functions/$($entry.Key).ps1"
    if (-not (Test-Path $src)) { Write-Warning "Not found upstream (renamed or removed?): $($entry.Key)"; continue }
    $name = Split-Path $entry.Key -Leaf
    $destDir = Join-Path $repoRoot "Functions/$($entry.Value)"
    $dest = Join-Path $destDir "$name.ps1"

    # Never overwrite one of our own files that happens to share a name
    if ((Test-Path $dest) -and -not (Select-String -Path $dest -Pattern '^# Source: jonlabelle/pwsh-profile' -Quiet)) {
        Write-Warning "Skipping $name - a non-upstream file with that name already exists."
        continue
    }

    $text = [IO.File]::ReadAllText($src)

    # Collect the aliases the file sets for its own function
    $aliases = [regex]::Matches($text, "Set-Alias\s+-Name\s+'([^']+)'\s+-Value\s+'$([regex]::Escape($name))'") |
        ForEach-Object { $_.Groups[1].Value } |
        Where-Object { $_ -notin $SkipAliases } |
        Select-Object -Unique

    $header = [Text.StringBuilder]::new()
    if ($aliases) { $null = $header.AppendLine("# Alias: $($aliases -join ', ')") }
    $null = $header.AppendLine("# Source: jonlabelle/pwsh-profile@$commit (MIT, Copyright (c) Jon LaBelle) - Functions/$($entry.Key).ps1")
    $null = $header.AppendLine('# Synced by tools/Sync-Upstream.ps1 - edit upstream or remove this file from the sync list before changing it.')
    $out = $header.ToString() + $text.TrimStart([char]0xFEFF)

    if ($PSCmdlet.ShouldProcess($dest, "Sync $name")) {
        $null = New-Item -ItemType Directory -Path $destDir -Force
        # Windows PowerShell 5.1 reads BOM-less files as ANSI, so non-ASCII files get a UTF-8 BOM
        if ($out -match '[^\u0000-\u007F]') { [IO.File]::WriteAllText($dest, $out, $utf8Bom) }
        else { [IO.File]::WriteAllText($dest, $out) }
        $count++
    }
}

# Keep the upstream license next to the code
$license = Join-Path $SourcePath 'LICENSE'
if (Test-Path $license) {
    $notice = "# Third-party notices`n`nFiles whose header says ``# Source: jonlabelle/pwsh-profile`` are copied from`nhttps://github.com/jonlabelle/pwsh-profile (commit $commit) under the MIT License:`n`n``````text`n$([IO.File]::ReadAllText($license).Trim())`n```````n"
    [IO.File]::WriteAllText((Join-Path $repoRoot 'THIRD-PARTY-NOTICES.md'), $notice)
}

if ($cleanup) { Remove-Item $cleanup -Recurse -Force -ErrorAction SilentlyContinue }
Write-Host "Synced $count function(s) from jonlabelle/pwsh-profile@$commit." -ForegroundColor Green
Write-Host 'Run "reload" (or open a new shell) to pick them up.'
