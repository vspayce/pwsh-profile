# Alias: ep
function Edit-Profile {
    <#
    .SYNOPSIS
        Opens the profile repo in your editor (VS Code if installed), or one function's file.
    .EXAMPLE
        ep                 # whole repo
    .EXAMPLE
        ep Test-Port       # just that function's file
    .EXAMPLE
        ep -Local          # your machine-only local.ps1
    #>
    param(
        [Parameter(Position = 0)][string]$Function,
        [switch]$Local
    )
    $target = $global:PwshProfileRoot
    if ($Local) {
        $target = Join-Path $global:PwshProfileRoot 'local.ps1'
        if (-not (Test-Path $target)) {
            Copy-Item (Join-Path $global:PwshProfileRoot 'local.example.ps1') $target
        }
    } elseif ($Function) {
        $name = if ($global:PwshProfileAliases[$Function]) { $global:PwshProfileAliases[$Function] } else { $Function }
        $target = $global:PwshProfileFunctions[$name]
        if (-not $target) { Write-Error "'$Function' is not a profile function."; return }
    }

    if (Get-Command code -ErrorAction SilentlyContinue) { code $target }
    elseif ($env:EDITOR) { & $env:EDITOR $target }
    elseif ($global:PwshIsWindows) { if (Test-Path $target -PathType Container) { explorer.exe $target } else { notepad.exe $target } }
    else { Write-Host $target }
}
