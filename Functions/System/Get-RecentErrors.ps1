# Alias: errs
function Get-RecentErrors {
    <#
    .SYNOPSIS
        Latest Critical/Error events from the System and Application logs (Windows).
    .EXAMPLE
        errs
    .EXAMPLE
        Get-RecentErrors -Hours 2 -ComputerName srv01
    .EXAMPLE
        errs -Count 50 -IncludeWarnings | Out-GridView
    #>
    [CmdletBinding()]
    param(
        [int]$Count = 15,
        [int]$Hours,
        [string[]]$LogName = @('System', 'Application'),
        [switch]$IncludeWarnings,
        [string]$ComputerName
    )
    if (-not $global:PwshIsWindows) { throw 'Get-RecentErrors needs the Windows event log.' }

    $levels = @(1, 2)
    if ($IncludeWarnings) { $levels += 3 }
    $filter = @{ LogName = $LogName; Level = $levels }
    if ($Hours) { $filter.StartTime = (Get-Date).AddHours(-$Hours) }

    $p = @{ FilterHashtable = $filter; MaxEvents = $Count; ErrorAction = 'SilentlyContinue' }
    if ($ComputerName) { $p.ComputerName = $ComputerName }

    Get-WinEvent @p | Select-Object TimeCreated, LogName, LevelDisplayName, ProviderName, Id,
        @{ n = 'Message'; e = { ($_.Message -split "`r?`n")[0] } }
}
