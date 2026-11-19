# Alias: newfn
function New-ProfileFunction {
    <#
    .SYNOPSIS
        Creates a new function file from a template, registers it, and opens it for editing.
    .DESCRIPTION
        Use -Local for helpers that should stay on this machine only (Functions\Local is gitignored).
    .EXAMPLE
        New-ProfileFunction Get-PrinterQueue -Category System -Alias pq
    .EXAMPLE
        newfn Connect-HomeLab -Local
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidatePattern('^[A-Za-z]+-[A-Za-z0-9]+$')]
        [string]$Name,

        [string]$Category = 'Utilities',
        [string[]]$Alias,
        [string]$Synopsis = 'TODO: one-line description.',
        [switch]$Local
    )
    $verb = $Name.Split('-')[0]
    if (-not (Get-Verb -Verb $verb)) { Write-Warning "'$verb' is not an approved PowerShell verb (see Get-Verb)." }

    $folder = if ($Local) { 'Local' } else { $Category }
    $dir = Join-Path (Join-Path $global:PwshProfileRoot 'Functions') $folder
    $path = Join-Path $dir "$Name.ps1"
    if (Test-Path $path) { Write-Error "$path already exists."; return }
    $null = New-Item -ItemType Directory -Path $dir -Force

    $header = if ($Alias) { "# Alias: $($Alias -join ', ')`n" } else { '' }
    $body = @"
${header}function $Name {
    <#
    .SYNOPSIS
        $Synopsis
    .EXAMPLE
        $Name
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]`$Name
    )

}
"@
    [IO.File]::WriteAllText($path, $body.Replace("`r`n", "`n"))
    Write-Host "Created $path" -ForegroundColor Green
    Invoke-ProfileReload
    Edit-Profile -Function $Name
}
