# Alias: dp
function Get-DinoPass {
    <#
    .SYNOPSIS
        A kid-friendly, easy-to-say password from dinopass.com (e.g. "silly-dino47"), copied to the clipboard.
    .DESCRIPTION
        Great for temporary passwords you have to read out over the phone. DinoPass was built
        for schools, so "simple" ones are memorable rather than strong; use -Strong for
        something better, or New-Password (genpass) for real secrets.

        If dinopass.com can't be reached, you get a local New-Password result instead.
    .EXAMPLE
        dp
    .EXAMPLE
        dp -Strong
    .EXAMPLE
        dp -Count 5 -NoCopy     # five to choose from
    #>
    [CmdletBinding()]
    param(
        [switch]$Strong,
        [ValidateRange(1, 20)][int]$Count = 1,
        [switch]$NoCopy
    )
    $kind = if ($Strong) { 'strong' } else { 'simple' }
    $results = for ($i = 0; $i -lt $Count; $i++) {
        try {
            $p = Invoke-RestMethod -Uri "https://www.dinopass.com/password/$kind" -TimeoutSec 5 -ErrorAction Stop
            ([string]$p).Trim()
        } catch {
            if ($i -eq 0) { Write-Warning "dinopass.com didn't answer ($($_.Exception.Message)); using a local password instead." }
            New-Password -Length $(if ($Strong) { 16 } else { 12 }) -NoSymbols:(-not $Strong)
        }
    }
    if (-not $NoCopy) {
        try {
            $results | Select-Object -First 1 | Set-Clipboard -ErrorAction Stop
            Write-Host 'Copied to clipboard.' -ForegroundColor Green
        } catch { Write-Verbose "Clipboard not available: $_" }
    }
    $results
}
