# Alias: mac
function Convert-MacAddress {
    <#
    .SYNOPSIS
        Converts a MAC address between formats (colon, dash, Cisco dot, plain).
    .EXAMPLE
        mac 00-1A-2B-3C-4D-5E
        # Shows every format
    .EXAMPLE
        Convert-MacAddress 001a.2b3c.4d5e -Format Colon
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [string[]]$MacAddress,

        [ValidateSet('All', 'Colon', 'Dash', 'Cisco', 'Plain')]
        [string]$Format = 'All',

        [switch]$Lowercase
    )
    process {
        foreach ($m in $MacAddress) {
            $hex = ($m -replace '[^0-9A-Fa-f]', '')
            if ($hex.Length -ne 12) { Write-Error "'$m' is not a valid MAC address."; continue }
            $hex = if ($Lowercase) { $hex.ToLower() } else { $hex.ToUpper() }
            $pairs = 0..5 | ForEach-Object { $hex.Substring($_ * 2, 2) }
            $out = [ordered]@{
                Colon = $pairs -join ':'
                Dash  = $pairs -join '-'
                Cisco = ($hex.Substring(0, 4), $hex.Substring(4, 4), $hex.Substring(8, 4) -join '.').ToLower()
                Plain = $hex
            }
            if ($Format -eq 'All') { [PSCustomObject]$out } else { $out[$Format] }
        }
    }
}
