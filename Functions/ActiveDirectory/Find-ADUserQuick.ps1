# Alias: seu
function Find-ADUserQuick {
    <#
    .SYNOPSIS
        Fuzzy AD user search across name, display name, username, email and description.
    .EXAMPLE
        seu smith
    .EXAMPLE
        seu "help desk" -IncludeDisabled
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Search,

        [switch]$IncludeDisabled,
        [string]$Server
    )
    if (-not (Get-Command Get-ADUser -ErrorAction SilentlyContinue)) {
        throw 'The ActiveDirectory module (RSAT) is not installed.'
    }
    $s = $Search.Replace("'", "''")
    $filter = "Name -like '*$s*' -or DisplayName -like '*$s*' -or SamAccountName -like '*$s*' -or mail -like '*$s*' -or Description -like '*$s*'"
    $p = @{ Filter = $filter; Properties = 'DisplayName', 'mail', 'Title', 'Department', 'Description', 'Enabled', 'LockedOut', 'Manager' }
    if ($Server) { $p.Server = $Server }

    Get-ADUser @p |
        Where-Object { $IncludeDisabled -or $_.Enabled } |
        Sort-Object DisplayName |
        Select-Object DisplayName, SamAccountName, mail, Title, Department, Enabled, LockedOut,
            @{ n = 'Manager'; e = { if ($_.Manager) { ($_.Manager -split ',')[0] -replace '^CN=' } } },
            Description
}
