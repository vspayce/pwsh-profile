# Session basics. Loaded eagerly - keep this file cheap.
# Use global: scope for anything that must survive a reload from inside a function.

# Settings you can override in local.ps1, e.g. $PwshProfileConfig.ShowGitBranch = $false
$global:PwshProfileConfig = @{
    ShowGitBranch       = $true
    ShowDuration        = $true    # show how long the last command took...
    DurationThresholdMs = 2000     # ...when it took longer than this
    PromptChar          = '>'
    DirHistoryMax       = 50
    DeferredInit        = @('gh', 'zoxide')   # tools initialised after the first prompt, if installed
}

# Platform flags that also work on Windows PowerShell 5.1 (which has no $IsWindows)
$global:PwshIsWindows = [Environment]::OSVersion.Platform -eq 'Win32NT'
if ($global:PwshIsWindows) {
    $global:PwshIsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
} else {
    $global:PwshIsAdmin = [Environment]::UserName -eq 'root'
}

# Windows PowerShell 5.1 can default to old TLS versions - make sure 1.2 is on.
if ($PSVersionTable.PSEdition -ne 'Core') {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
}

# UTF-8 everywhere so native tools (git, winget, etc.) print correctly.
try {
    $global:OutputEncoding = [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
} catch { }

# Session directory history used by the prompt, 'dh' and 'j'
if ($null -eq $global:DirHistory) {
    $global:DirHistory = [System.Collections.Generic.List[string]]::new()
}
if ($null -eq $global:PwshProfileState) {
    $global:PwshProfileState = @{ LastHistoryId = -1 }
}
