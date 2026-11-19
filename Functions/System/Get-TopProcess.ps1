# Alias: topp
function Get-TopProcess {
    <#
    .SYNOPSIS
        Top processes by memory or CPU time.
    .EXAMPLE
        topp
    .EXAMPLE
        Get-TopProcess -By CPU -Top 5
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('Memory', 'CPU')][string]$By = 'Memory',
        [int]$Top = 10
    )
    $sort = if ($By -eq 'CPU') { 'CPU' } else { 'WorkingSet64' }
    Get-Process | Sort-Object $sort -Descending | Select-Object -First $Top Id, ProcessName,
        @{ n = 'MemMB'; e = { [Math]::Round($_.WorkingSet64 / 1MB, 0) } },
        @{ n = 'CPUs'; e = { [Math]::Round($_.CPU, 1) } },
        StartTime
}
