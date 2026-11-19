# Alias: dh
function Show-DirectoryHistory {
    <#
    .SYNOPSIS
        Numbered list of folders you have visited this session (most recent first).
    .DESCRIPTION
        The prompt records every folder change - cd, pushd, cd -, scripts - into
        $DirHistory. Jump back with 'j <number>' or 'j <part of name>'.
    .EXAMPLE
        dh
    .EXAMPLE
        dh logs     # only entries containing "logs"
    #>
    param([Parameter(Position = 0)][string]$Filter)
    for ($i = 0; $i -lt $global:DirHistory.Count; $i++) {
        $d = $global:DirHistory[$i]
        if ($Filter -and $d -notlike "*$Filter*") { continue }
        $color = if ($i -eq 0) { 'DarkGray' } else { 'Cyan' }
        Write-Host ('[{0,2}] {1}' -f $i, $d) -ForegroundColor $color
    }
}
