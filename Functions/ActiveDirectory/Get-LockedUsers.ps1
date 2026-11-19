# Alias: locked
function Get-LockedUsers {
    <#
    .SYNOPSIS
        Lists every locked-out AD account with its last bad password time.
    .DESCRIPTION
        Requires the ActiveDirectory module (RSAT). The module only loads the first
        time you run this, so it does not slow down your shell startup.
    .EXAMPLE
        locked
    .EXAMPLE
        Get-LockedUsers | Unlock-ADAccount -Confirm
    #>
    [CmdletBinding()]
    param([string]$Server)

    if (-not (Get-Command Search-ADAccount -ErrorAction SilentlyContinue)) {
        throw 'The ActiveDirectory module (RSAT) is not installed.'
    }
    $sp = @{}
    if ($Server) { $sp.Server = $Server }

    Search-ADAccount -LockedOut -UsersOnly @sp |
        Get-ADUser -Properties LockedOut, LastBadPasswordAttempt, badPwdCount, Department @sp |
        Sort-Object LastBadPasswordAttempt -Descending |
        Select-Object Name, SamAccountName, Department, LockedOut, badPwdCount, LastBadPasswordAttempt, DistinguishedName
}
