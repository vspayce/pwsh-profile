# Alias: ubd
function Unblock-Downloads {
    <#
    .SYNOPSIS
        Removes the "downloaded from the internet" block from files in your Downloads folder (Windows).
    .EXAMPLE
        ubd
    .EXAMPLE
        Unblock-Downloads -Path .\tools -Filter *.ps1
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$Path = (Join-Path $HOME 'Downloads'),
        [string]$Filter = '*'
    )
    if (-not $global:PwshIsWindows) { Write-Warning 'Only Windows marks downloaded files as blocked.'; return }
    $files = Get-ChildItem -LiteralPath $Path -Filter $Filter -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { Get-Item -LiteralPath $_.FullName -Stream Zone.Identifier -ErrorAction SilentlyContinue }
    foreach ($f in $files) {
        if ($PSCmdlet.ShouldProcess($f.FullName, 'Unblock')) { Unblock-File -LiteralPath $f.FullName }
    }
    Write-Host "Unblocked $(@($files).Count) file(s) in $Path." -ForegroundColor Green
}
