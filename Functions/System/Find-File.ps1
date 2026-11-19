# Alias: ff
function Find-File {
    <#
    .SYNOPSIS
        Recursively finds files whose name matches a pattern.
    .EXAMPLE
        ff *.log
    .EXAMPLE
        ff web.config -Path C:\inetpub
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)][string]$Name,
        [Parameter(Position = 1)][string]$Path = '.'
    )
    if ($Name -notmatch '[\*\?]') { $Name = "*$Name*" }
    Get-ChildItem -LiteralPath $Path -Filter $Name -Recurse -File -Force -ErrorAction SilentlyContinue |
        Select-Object LastWriteTime, @{ n = 'SizeKB'; e = { [Math]::Round($_.Length / 1KB, 1) } }, FullName
}
