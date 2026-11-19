# Alias: hash
function Get-Hash {
    <#
    .SYNOPSIS
        File hash in one line, optionally checked against the hash from a vendor's download page.
    .EXAMPLE
        hash .\installer.msi
    .EXAMPLE
        hash .\installer.msi -Expected 3F2A...   # prints MATCH / MISMATCH
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName')]
        [string]$Path,

        [Parameter(Position = 1)]
        [string]$Expected,

        [ValidateSet('SHA256', 'SHA1', 'SHA384', 'SHA512', 'MD5')]
        [string]$Algorithm = 'SHA256'
    )
    process {
        $h = (Get-FileHash -LiteralPath $Path -Algorithm $Algorithm).Hash
        if ($Expected) {
            $ok = $h -eq ($Expected.Trim() -replace '\s', '')
            if ($ok) { Write-Host "MATCH  $Algorithm $h" -ForegroundColor Green }
            else     { Write-Host "MISMATCH`n  file:     $h`n  expected: $Expected" -ForegroundColor Red }
            return $ok
        }
        $h
    }
}
