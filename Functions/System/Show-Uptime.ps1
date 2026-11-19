# Alias(Windows): uptime
function Show-Uptime {
    <#
    .SYNOPSIS
        Last boot time and uptime, like the Linux 'uptime' command. Works on remote Windows hosts too.
    .EXAMPLE
        uptime
    .EXAMPLE
        uptime -ComputerName srv01, srv02
    #>
    [CmdletBinding()]
    param([string[]]$ComputerName)

    if ($ComputerName) {
        foreach ($c in $ComputerName) {
            try {
                $boot = (Get-CimInstance -ClassName Win32_OperatingSystem -ComputerName $c -ErrorAction Stop).LastBootUpTime
                $span = (Get-Date) - $boot
                [PSCustomObject]@{ ComputerName = $c; LastBoot = $boot; Uptime = '{0}d {1}h {2}m' -f $span.Days, $span.Hours, $span.Minutes }
            } catch { Write-Error "${c}: $($_.Exception.Message)" }
        }
        return
    }

    if ($global:PwshIsWindows) {
        $boot = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
        $span = (Get-Date) - $boot
    } else {
        $span = Get-Uptime        # built into PowerShell 6.1+
        $boot = (Get-Date) - $span
    }
    [PSCustomObject]@{
        ComputerName = [Environment]::MachineName
        LastBoot     = $boot
        Uptime       = '{0}d {1}h {2}m' -f $span.Days, $span.Hours, $span.Minutes
    }
}
