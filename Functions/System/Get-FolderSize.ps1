# Alias(Windows): du
function Get-FolderSize {
    <#
    .SYNOPSIS
        Size of each subfolder, biggest first - find what is filling a disk.
    .EXAMPLE
        du C:\Users -Top 10
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)][string]$Path = '.',
        [int]$Top = 20
    )
    $root = (Resolve-Path -LiteralPath $Path).ProviderPath
    Get-ChildItem -LiteralPath $root -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
        $bytes = (Get-ChildItem -LiteralPath $_.FullName -Recurse -File -Force -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum).Sum
        [PSCustomObject]@{ Folder = $_.Name; SizeMB = [Math]::Round([double]$bytes / 1MB, 1); Path = $_.FullName }
    } | Sort-Object SizeMB -Descending | Select-Object -First $Top
}
