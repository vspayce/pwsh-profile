# Alias: mkcd
function Enter-NewDirectory {
    <#
    .SYNOPSIS
        Creates a folder (and any parents) and moves into it.
    .EXAMPLE
        mkcd C:\temp\logs\today
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory, Position = 0)][string]$Path)
    $null = New-Item -ItemType Directory -Path $Path -Force
    Set-Location -LiteralPath $Path
}
