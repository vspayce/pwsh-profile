# Alias: weather
function Get-Weather {
    <#
    .SYNOPSIS
        Weather in the terminal from wttr.in.
    .DESCRIPTION
        With no location, wttr.in guesses from your IP. Set a default in local.ps1:
            $PwshProfileConfig.WeatherLocation = 'Seattle'
    .EXAMPLE
        weather
    .EXAMPLE
        weather Tokyo -Short
    #>
    param(
        [Parameter(Position = 0)][string]$Location = $global:PwshProfileConfig.WeatherLocation,
        [switch]$Short,
        [switch]$Metric
    )
    $loc = [uri]::EscapeDataString("$Location")
    $q = @()
    if ($Short) { $q += 'format=3' } else { $q += '0' }   # 0 = current conditions only
    $q += if ($Metric) { 'm' } else { 'u' }
    (Invoke-WebRequest -Uri "https://wttr.in/${loc}?$($q -join '&')" -UserAgent 'curl' -UseBasicParsing -TimeoutSec 10).Content
}
