# Alias: reload
function Invoke-ProfileReload {
    <#
    .SYNOPSIS
        Reloads the profile in the current session - picks up new and edited function files.
    .EXAMPLE
        reload
    #>
    param()
    $sw = [Diagnostics.Stopwatch]::StartNew()
    . (Join-Path $global:PwshProfileRoot 'profile.ps1')
    Write-Host ("Profile reloaded ({0} functions, {1} ms)." -f $global:PwshProfileFunctions.Count, $sw.ElapsedMilliseconds) -ForegroundColor Cyan
}
