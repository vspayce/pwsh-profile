# Alias(Windows): touch
function New-File {
    <#
    .SYNOPSIS
        Creates an empty file, or updates its timestamp if it exists (like 'touch').
    .EXAMPLE
        touch notes.txt
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory, Position = 0, ValueFromRemainingArguments)][string[]]$Path)
    foreach ($p in $Path) {
        if (Test-Path -LiteralPath $p) {
            (Get-Item -LiteralPath $p).LastWriteTime = Get-Date
        } else {
            $null = New-Item -ItemType File -Path $p -Force
        }
    }
}
