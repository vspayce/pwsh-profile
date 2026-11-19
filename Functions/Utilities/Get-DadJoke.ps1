# Alias: joke
function Get-DadJoke {
    <#
    .SYNOPSIS
        A random dad joke from icanhazdadjoke.com. Add 'joke' to local.ps1 for one on every new shell.
    .EXAMPLE
        joke
    #>
    param()
    try {
        (Invoke-RestMethod -Uri 'https://icanhazdadjoke.com/' -Headers @{ Accept = 'application/json' } -TimeoutSec 3).joke
    } catch { Write-Warning 'No joke today - icanhazdadjoke.com did not answer.' }
}
