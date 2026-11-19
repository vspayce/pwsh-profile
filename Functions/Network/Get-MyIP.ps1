# Alias: myip
function Get-MyIP {
    <#
    .SYNOPSIS
        Shows your local IPv4 address(es) and your public IP.
    .DESCRIPTION
        Uses .NET network interfaces so it works on Windows, macOS and Linux.
        Skips loopback, link-local (169.254.x.x) and virtual adapters.
    .EXAMPLE
        myip
    .EXAMPLE
        Get-MyIP -LocalOnly
    #>
    [CmdletBinding()]
    param([switch]$LocalOnly)

    $local = foreach ($nic in [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()) {
        if ($nic.OperationalStatus -ne 'Up') { continue }
        if ($nic.NetworkInterfaceType -eq 'Loopback') { continue }
        if ($nic.Name -match 'vEthernet|VirtualBox|VMware|docker|veth|br-|utun|Loopback') { continue }
        foreach ($addr in $nic.GetIPProperties().UnicastAddresses) {
            $ip = $addr.Address
            if ($ip.AddressFamily -ne 'InterNetwork') { continue }
            if ($ip.ToString() -like '169.254.*') { continue }
            [PSCustomObject]@{ Interface = $nic.Name; IP = $ip.ToString() }
        }
    }

    $public = $null
    if (-not $LocalOnly) {
        try {
            $public = (Invoke-RestMethod -Uri 'https://api.ipify.org?format=json' -TimeoutSec 3).ip
        } catch {
            Write-Warning "Could not reach api.ipify.org: $($_.Exception.Message)"
        }
    }

    [PSCustomObject]@{
        LocalIP    = ($local.IP -join ', ')
        Interfaces = ($local | ForEach-Object { "$($_.Interface)=$($_.IP)" }) -join '; '
        PublicIP   = $public
    }
}
