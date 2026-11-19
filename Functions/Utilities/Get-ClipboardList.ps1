# Alias: cliplist
function Get-ClipboardList {
    <#
    .SYNOPSIS
        Turns a pasted list (from Excel, email, a ticket...) into a clean array.
    .DESCRIPTION
        Copy a column of computer names or usernames, then run 'cliplist'. Blank lines,
        surrounding spaces and duplicates are removed. Splits on new lines, commas, semicolons and tabs.
    .EXAMPLE
        cliplist | Test-Port -Port 3389
    .EXAMPLE
        $users = cliplist; $users | Get-UserStatus
    #>
    param([switch]$KeepDuplicates)
    $raw = Get-Clipboard -Raw
    if (-not $raw) { Write-Warning 'Clipboard is empty.'; return }
    $items = $raw -split '[\r\n,;\t]+' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    if ($KeepDuplicates) { $items } else { $items | Select-Object -Unique }
}
