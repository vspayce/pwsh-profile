<#
    pwsh-profile loader
    -------------------
    Dot-source this file from $PROFILE (install.ps1 adds the line for you).

    How it stays fast:
      * Core\*.ps1 is small and loaded eagerly (prompt, PSReadLine, completers).
      * Every file in Functions\<Category>\Verb-Noun.ps1 is NOT loaded at startup.
        A tiny stub with the same name is created instead. The first time you
        call it, the stub dot-sources the real file, swaps itself out, and runs it.
      * Aliases are read from a "# Alias:" comment near the top of each file, so
        they work before the function is loaded.

    Everything here writes to global scope on purpose, so the loader can be
    re-run from inside a function (see 'reload' / Invoke-ProfileReload).

    Set $env:PWSH_PROFILE_EAGER = '1' to load every function up front (useful if
    you want parameter tab-completion for profile functions immediately).
    Set $env:PWSH_PROFILE_TIMING = '1' to print how long each step takes.
#>

$__ppSw = [Diagnostics.Stopwatch]::StartNew()
$__ppTiming = $env:PWSH_PROFILE_TIMING -eq '1'

$global:PwshProfileRoot      = $PSScriptRoot
$global:PwshProfileFunctions = @{}   # function name -> file path
$global:PwshProfileAliases   = @{}   # alias -> function name

# --- Lazy loader ---------------------------------------------------------------
function global:Import-ProfileFunction {
    <#
    .SYNOPSIS
        Loads one or more lazily-registered profile functions now.
    .EXAMPLE
        Import-ProfileFunction Test-Port, Get-MyIP
    .EXAMPLE
        Import-ProfileFunction -All
    #>
    [CmdletBinding(DefaultParameterSetName = 'Name')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ParameterSetName = 'Name')]
        [string[]]$Name,

        [Parameter(Mandatory, ParameterSetName = 'All')]
        [switch]$All
    )
    process {
        if ($All) { $Name = @($global:PwshProfileFunctions.Keys) }
        foreach ($n in $Name) {
            $path = $global:PwshProfileFunctions[$n]
            if (-not $path) { Write-Error "'$n' is not a pwsh-profile function."; continue }

            # Dot-source into this scope, then promote the real function to global.
            . $path
            $fn = Get-Item -LiteralPath "function:$n" -ErrorAction SilentlyContinue
            if (-not $fn -or $fn.ScriptBlock.ToString() -like '*__PwshProfileStub__*') {
                throw "pwsh-profile: '$path' did not define a function named '$n'."
            }
            Set-Item -LiteralPath "function:global:$n" -Value $fn.ScriptBlock -Force
        }
    }
}

$__ppStubTemplate = @'
# __PwshProfileStub__ (replaced by the real function on first use)
Import-ProfileFunction -Name '{0}'
if ($MyInvocation.ExpectingInput) {{ $input | & '{0}' @args }} else {{ & '{0}' @args }}
'@

# --- Core (eager) ------------------------------------------------------------------
$__ppCore = Join-Path $PSScriptRoot 'Core'
if ([IO.Directory]::Exists($__ppCore)) {
    foreach ($__ppFile in ([IO.Directory]::GetFiles($__ppCore, '*.ps1') | Sort-Object)) {
        $__ppT = $__ppSw.ElapsedMilliseconds
        try { . $__ppFile } catch { Write-Warning "pwsh-profile: $([IO.Path]::GetFileName($__ppFile)) failed: $_" }
        if ($__ppTiming) { Write-Host ('  {0,-24}{1,5} ms' -f [IO.Path]::GetFileName($__ppFile), ($__ppSw.ElapsedMilliseconds - $__ppT)) -ForegroundColor DarkGray }
    }
}
$__ppT = $__ppSw.ElapsedMilliseconds

# --- Functions (lazy) ------------------------------------------------------------
$__ppFnDir = Join-Path $PSScriptRoot 'Functions'
$__ppStubs = [Text.StringBuilder]::new()
$__ppAliasCmds = [Text.StringBuilder]::new()
if ([IO.Directory]::Exists($__ppFnDir)) {
    foreach ($__ppFile in [IO.Directory]::EnumerateFiles($__ppFnDir, '*.ps1', [IO.SearchOption]::AllDirectories)) {
        $__ppName = [IO.Path]::GetFileNameWithoutExtension($__ppFile)
        if ($__ppName.StartsWith('_') -or $__ppFile -match '[\\/]Private[\\/]') { continue }
        if ($__ppName -notmatch '^[\w-]+$') { Write-Warning "pwsh-profile: skipping oddly named file $__ppFile"; continue }

        $global:PwshProfileFunctions[$__ppName] = $__ppFile
        $null = $__ppStubs.AppendLine("function global:$__ppName {").AppendLine(($__ppStubTemplate -f $__ppName)).AppendLine('}')

        # Header comments (before the 'function' line):
        #   # Alias: a, b             -> everywhere
        #   # Alias(Windows): df, du  -> Windows only, so native tools on macOS/Linux are not hidden
        $__ppReader = [IO.StreamReader]::new($__ppFile)
        try {
            for ($__ppI = 0; $__ppI -lt 12; $__ppI++) {
                $__ppLine = $__ppReader.ReadLine()
                if ($null -eq $__ppLine -or $__ppLine -match '^\s*function\s') { break }
                if ($__ppLine -match '^\s*#\s*Alias(?:es)?(?:\((\w+)\))?\s*:\s*(.+)$') {
                    if ($Matches[1] -eq 'Windows' -and -not $global:PwshIsWindows) { continue }
                    foreach ($__ppAlias in ($Matches[2] -split '[,\s]+')) {
                        if ($__ppAlias -notmatch '^[\w.-]+$') { continue }
                        $global:PwshProfileAliases[$__ppAlias] = $__ppName
                        $null = $__ppAliasCmds.AppendLine("Set-Alias -Name '$__ppAlias' -Value '$__ppName' -Scope Global -Force -ErrorAction SilentlyContinue")
                    }
                }
            }
        } finally { $__ppReader.Dispose() }
    }
}
# Define every stub and alias in one compiled block (faster than one command per function)
. ([scriptblock]::Create($__ppStubs.ToString() + $__ppAliasCmds.ToString()))

if ($__ppTiming) { Write-Host ('  {0,-24}{1,5} ms' -f "stubs ($($global:PwshProfileFunctions.Count) functions)", ($__ppSw.ElapsedMilliseconds - $__ppT)) -ForegroundColor DarkGray }
if ($env:PWSH_PROFILE_EAGER -eq '1') { Import-ProfileFunction -All }

# --- Machine-local overrides (gitignored) ------------------------------------------
$__ppLocal = Join-Path $PSScriptRoot 'local.ps1'
if ([IO.File]::Exists($__ppLocal)) {
    try { . $__ppLocal } catch { Write-Warning "pwsh-profile: local.ps1 failed: $_" }
}

if ($__ppTiming) { Write-Host ('  {0,-24}{1,5} ms' -f 'TOTAL', $__ppSw.ElapsedMilliseconds) -ForegroundColor DarkGray }
Remove-Variable -Name __pp* -ErrorAction SilentlyContinue
