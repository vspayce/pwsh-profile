# Alias: copygroups
function Copy-ADGroupMembership {
    <#
    .SYNOPSIS
        Copies group memberships from one AD user to another ("make them like Bob").
    .DESCRIPTION
        Only adds groups the target is missing. Supports -WhatIf so you can preview
        first. Use -Filter to copy only matching groups.
    .EXAMPLE
        Copy-ADGroupMembership -From bsmith -To jdoe -WhatIf
    .EXAMPLE
        copygroups bsmith jdoe -Filter 'APP-*'
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory, Position = 0)][string]$From,
        [Parameter(Mandatory, Position = 1)][string]$To,
        [string]$Filter = '*',
        [string]$Server
    )
    if (-not (Get-Command Get-ADUser -ErrorAction SilentlyContinue)) {
        throw 'The ActiveDirectory module (RSAT) is not installed.'
    }
    $sp = @{}
    if ($Server) { $sp.Server = $Server }

    $source = Get-ADUser -Identity $From -Properties MemberOf @sp
    $target = Get-ADUser -Identity $To -Properties MemberOf @sp
    $have = @{}
    foreach ($g in $target.MemberOf) { $have[$g] = $true }

    foreach ($dn in $source.MemberOf) {
        $name = ($dn -split ',')[0] -replace '^CN='
        if ($name -notlike $Filter) { continue }
        if ($have[$dn]) {
            [PSCustomObject]@{ Group = $name; Result = 'AlreadyMember' }
            continue
        }
        if ($PSCmdlet.ShouldProcess($target.SamAccountName, "Add to '$name'")) {
            try {
                Add-ADGroupMember -Identity $dn -Members $target @sp -ErrorAction Stop
                [PSCustomObject]@{ Group = $name; Result = 'Added' }
            } catch {
                [PSCustomObject]@{ Group = $name; Result = "Failed: $($_.Exception.Message)" }
            }
        }
    }
}
