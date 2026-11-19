# Alias: ustat
function Get-UserStatus {
    <#
    .SYNOPSIS
        One-glance AD account health: enabled, locked, password expiry, last logon.
    .DESCRIPTION
        Shows when the password actually expires (not just when it was set).
        Use -Unlock to be offered an unlock if the account is locked out.
    .EXAMPLE
        ustat jsmith
    .EXAMPLE
        Get-UserStatus jsmith -Unlock
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('SamAccountName', 'User')]
        [string[]]$Identity,

        [switch]$Unlock,
        [string]$Server
    )
    begin {
        if (-not (Get-Command Get-ADUser -ErrorAction SilentlyContinue)) {
            throw 'The ActiveDirectory module (RSAT) is not installed.'
        }
        $props = 'Enabled', 'LockedOut', 'PasswordExpired', 'PasswordLastSet', 'PasswordNeverExpires',
                 'LastLogonDate', 'LastBadPasswordAttempt', 'badPwdCount', 'msDS-UserPasswordExpiryTimeComputed',
                 'Title', 'Department', 'Manager'
    }
    process {
        foreach ($id in $Identity) {
            $p = @{ Identity = $id; Properties = $props }
            if ($Server) { $p.Server = $Server }
            $u = Get-ADUser @p

            $expiry = $null
            $raw = $u.'msDS-UserPasswordExpiryTimeComputed'
            if ($raw -and $raw -gt 0 -and $raw -lt [long]::MaxValue) { $expiry = [DateTime]::FromFileTime($raw) }

            [PSCustomObject]@{
                Name            = $u.Name
                SamAccountName  = $u.SamAccountName
                Title           = $u.Title
                Department      = $u.Department
                Enabled         = $u.Enabled
                LockedOut       = $u.LockedOut
                BadPwdCount     = $u.badPwdCount
                LastBadPassword = $u.LastBadPasswordAttempt
                PasswordExpired = $u.PasswordExpired
                PasswordLastSet = $u.PasswordLastSet
                PasswordExpires = $(if ($u.PasswordNeverExpires) { 'Never' } else { $expiry })
                LastLogonDate   = $u.LastLogonDate
            }

            if ($Unlock -and $u.LockedOut -and $PSCmdlet.ShouldProcess($u.SamAccountName, 'Unlock AD account')) {
                $up = @{ Identity = $u }
                if ($Server) { $up.Server = $Server }
                Unlock-ADAccount @up
                Write-Host "Unlocked $($u.SamAccountName)." -ForegroundColor Green
            }
        }
    }
}
