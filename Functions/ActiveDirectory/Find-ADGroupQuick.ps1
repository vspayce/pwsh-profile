# Alias: seg
function Find-ADGroupQuick {
    <#
    .SYNOPSIS
        Fuzzy AD group search across name, account name and description.
    .EXAMPLE
        seg vpn
    .EXAMPLE
        seg finance -MemberCount
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Search,

        [switch]$MemberCount,
        [string]$Server
    )
    if (-not (Get-Command Get-ADGroup -ErrorAction SilentlyContinue)) {
        throw 'The ActiveDirectory module (RSAT) is not installed.'
    }
    $s = $Search.Replace("'", "''")
    $props = @('Description', 'ManagedBy')
    if ($MemberCount) { $props += 'Members' }
    $p = @{ Filter = "Name -like '*$s*' -or SamAccountName -like '*$s*' -or Description -like '*$s*'"; Properties = $props }
    if ($Server) { $p.Server = $Server }

    Get-ADGroup @p | Sort-Object Name | ForEach-Object {
        $o = [ordered]@{
            Name          = $_.Name
            Scope         = $_.GroupScope
            Category      = $_.GroupCategory
            ManagedBy     = $(if ($_.ManagedBy) { ($_.ManagedBy -split ',')[0] -replace '^CN=' })
            Description   = $_.Description
        }
        if ($MemberCount) { $o.Members = @($_.Members).Count }
        [PSCustomObject]$o
    }
}
