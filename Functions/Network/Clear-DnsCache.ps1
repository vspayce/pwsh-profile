# Alias: flushdns
function Clear-DnsCache {
    <#
    .SYNOPSIS
        Flushes the DNS resolver cache on Windows, macOS or Linux.
    .EXAMPLE
        flushdns
    #>
    [CmdletBinding()]
    param()

    if ($global:PwshIsWindows) {
        Clear-DnsClientCache
    } elseif ($IsMacOS) {
        sudo dscacheutil -flushcache
        sudo killall -HUP mDNSResponder
    } elseif (Get-Command resolvectl -ErrorAction SilentlyContinue) {
        sudo resolvectl flush-caches
    } else {
        Write-Warning 'No supported DNS cache found (systemd-resolved not present).'
        return
    }
    Write-Host 'DNS cache cleared.' -ForegroundColor Green
}
