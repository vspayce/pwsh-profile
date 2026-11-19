# Alias: pf
function Show-ProfileFunction {
    <#
    .SYNOPSIS
        Lists every profile function with its aliases, category and one-line description.
    .DESCRIPTION
        Reads the .SYNOPSIS straight from each file, so nothing has to be loaded.
    .EXAMPLE
        pf
    .EXAMPLE
        pf dns          # search names, aliases and descriptions
    .EXAMPLE
        pf -Category ActiveDirectory
    #>
    param(
        [Parameter(Position = 0)][string]$Search,
        [string]$Category
    )
    $aliasMap = @{}
    foreach ($kv in $global:PwshProfileAliases.GetEnumerator()) {
        $aliasMap[$kv.Value] = @($aliasMap[$kv.Value]) + $kv.Key | Where-Object { $_ }
    }
    $fnRoot = Join-Path $global:PwshProfileRoot 'Functions'
    $rows = foreach ($kv in $global:PwshProfileFunctions.GetEnumerator()) {
        $text = [IO.File]::ReadAllText($kv.Value)
        $syn = if ($text -match '(?s)\.SYNOPSIS\s*\r?\n\s*(.+?)\r?\n') { $Matches[1].Trim() } else { '' }
        $rel = $kv.Value.Substring($fnRoot.Length).TrimStart('\', '/')
        [PSCustomObject]@{
            Category    = ($rel -split '[\\/]')[0]
            Name        = $kv.Key
            Alias       = (@($aliasMap[$kv.Key]) | Sort-Object) -join ', '
            Description = $syn
        }
    }
    if ($Category) { $rows = $rows | Where-Object Category -like "$Category*" }
    if ($Search) { $rows = $rows | Where-Object { "$($_.Name) $($_.Alias) $($_.Description)" -like "*$Search*" } }
    $rows | Sort-Object Category, Name | Format-Table -AutoSize -Wrap
}
