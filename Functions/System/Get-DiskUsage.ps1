# Alias(Windows): df
function Get-DiskUsage {
    <#
    .SYNOPSIS
        Free/used space for every drive, like 'df -h'.
    .EXAMPLE
        df
    #>
    [CmdletBinding()]
    param()
    foreach ($d in [IO.DriveInfo]::GetDrives()) {
        if (-not $d.IsReady -or $d.TotalSize -eq 0) { continue }
        if (-not $global:PwshIsWindows -and $d.DriveType -notin 'Fixed', 'Network', 'Removable') { continue }
        $used = $d.TotalSize - $d.AvailableFreeSpace
        [PSCustomObject]@{
            Drive  = $d.Name
            Label  = $d.VolumeLabel
            Type   = $d.DriveType
            SizeGB = [Math]::Round($d.TotalSize / 1GB, 1)
            UsedGB = [Math]::Round($used / 1GB, 1)
            FreeGB = [Math]::Round($d.AvailableFreeSpace / 1GB, 1)
            UsePct = [Math]::Round(100 * $used / $d.TotalSize, 0)
        }
    }
}
