# Alias: j
function Set-LocationFromHistory {
    <#
    .SYNOPSIS
        Jump to a folder from 'dh' by number, or by part of its name.
    .EXAMPLE
        j 3
    .EXAMPLE
        j proj      # most recent folder whose path contains "proj"
    .EXAMPLE
        j           # back to the previous folder
    #>
    param([Parameter(Position = 0)][string]$Target = '1')

    $h = $global:DirHistory
    if ($Target -match '^\d+$') {
        $i = [int]$Target
        if ($i -lt $h.Count) { Set-Location -LiteralPath $h[$i]; return }
        Write-Warning "No entry [$i]. Run 'dh' to see valid numbers."
        return
    }
    # Prefer a match on the folder name itself, then anywhere in the path; skip the current folder
    $match = $h | Select-Object -Skip 1 | Where-Object { (Split-Path $_ -Leaf) -like "*$Target*" } | Select-Object -First 1
    if (-not $match) { $match = $h | Select-Object -Skip 1 | Where-Object { $_ -like "*$Target*" } | Select-Object -First 1 }
    if ($match) { Set-Location -LiteralPath $match } else { Write-Warning "Nothing in history matches '$Target'." }
}
