function Measure-ProfileLoad {
    <#
    .SYNOPSIS
        Measures how many milliseconds this profile adds to shell startup.
    .EXAMPLE
        Measure-ProfileLoad
    .EXAMPLE
        Measure-ProfileLoad -Runs 20
    #>
    param([int]$Runs = 10)
    $shell = (Get-Process -Id $PID).Path
    $loader = Join-Path $global:PwshProfileRoot 'profile.ps1'
    $bare = 0; $withProfile = 0
    for ($i = 1; $i -le $Runs; $i++) {
        Write-Progress -Activity 'Measuring startup' -Status "Run $i of $Runs" -PercentComplete (100 * $i / $Runs)
        $bare        += (Measure-Command { & $shell -NoProfile -NoLogo -Command '1' | Out-Null }).TotalMilliseconds
        $withProfile += (Measure-Command { & $shell -NoProfile -NoLogo -Command ". '$loader'; 1" | Out-Null }).TotalMilliseconds
    }
    Write-Progress -Activity 'Measuring startup' -Completed
    [PSCustomObject]@{
        Runs          = $Runs
        NoProfileMs   = [int]($bare / $Runs)
        WithProfileMs = [int]($withProfile / $Runs)
        ProfileCostMs = [int](($withProfile - $bare) / $Runs)
        Functions     = $global:PwshProfileFunctions.Count
    }
}
