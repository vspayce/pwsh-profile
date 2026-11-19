function Update-Profile {
    <#
    .SYNOPSIS
        Pulls the latest profile from GitHub and reloads it.
    .DESCRIPTION
        Uses git when the profile was cloned; otherwise re-runs the installer.
        Your local.ps1 and Functions\Local are never touched.
    .EXAMPLE
        Update-Profile
    .EXAMPLE
        Update-Profile -CheckOnly
    #>
    param([switch]$CheckOnly)
    $root = $global:PwshProfileRoot
    if ((Test-Path (Join-Path $root '.git')) -and (Get-Command git -ErrorAction SilentlyContinue)) {
        git -C $root fetch --quiet
        $behind = [int](git -C $root rev-list --count 'HEAD..@{u}' 2>$null)
        if ($behind -eq 0) { Write-Host 'Profile is up to date.' -ForegroundColor Green; return }
        Write-Host "$behind new commit(s):" -ForegroundColor Yellow
        git -C $root log --oneline 'HEAD..@{u}'
        if ($CheckOnly) { return }
        git -C $root pull --ff-only --quiet
        if ($LASTEXITCODE -ne 0) { Write-Error 'git pull failed - do you have uncommitted changes in the profile folder?'; return }
    } else {
        if ($CheckOnly) { Write-Warning 'Not a git clone - cannot check without downloading.'; return }
        & (Join-Path $root 'install.ps1') -InstallPath $root
    }
    Invoke-ProfileReload
}
