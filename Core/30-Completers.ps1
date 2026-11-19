# Tab completion for native tools.
# Completers only run when you press Tab, so registering them costs nothing.

Register-ArgumentCompleter -Native -CommandName winget -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
    [Console]::InputEncoding = [Console]::OutputEncoding = $OutputEncoding = [Text.UTF8Encoding]::new()
    $word = $wordToComplete.Replace('"', '""')
    $ast  = $commandAst.ToString().Replace('"', '""')
    winget complete --word="$word" --commandline "$ast" --position $cursorPosition | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}

Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
    dotnet complete --position $cursorPosition "$commandAst" | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}

# Tools whose init scripts are slow (they spawn a process) are run once, right
# after the first prompt appears, so they never delay startup.
function global:Invoke-PwshProfileDeferredInit {
    param([string[]]$Tool = $global:PwshProfileConfig.DeferredInit)
    foreach ($t in $Tool) {
        if (-not (Get-Command $t -CommandType Application -ErrorAction SilentlyContinue)) { continue }
        $script = switch ($t) {
            'gh'     { gh completion -s powershell | Out-String }
            'zoxide' { zoxide init powershell | Out-String }
            default  { $null }
        }
        if (-not $script) { continue }
        # These scripts assume they run at top level. Make their helper functions
        # global so completers can still find them after this function returns.
        $script = [regex]::Replace($script, '(?m)^(function|filter)\s+(?!global:|script:)', '$1 global:')
        try { Invoke-Expression $script } catch { Write-Warning "pwsh-profile: $t init failed: $_" }
    }
}

# Work that can wait until after the first prompt is drawn
function global:Invoke-PwshProfileIdleWork {
    # Underline directories in Get-ChildItem output (PowerShell 7.2+). $PSStyle is
    # slow to create the first time, so this is not done during startup.
    if ($PSStyle -and $PSStyle.FileInfo -and -not $PSStyle.FileInfo.Directory.Contains($PSStyle.Underline)) {
        $PSStyle.FileInfo.Directory = $PSStyle.FileInfo.Directory + $PSStyle.Underline
    }
    if ($global:PwshProfileConfig.DeferredInit) { Invoke-PwshProfileDeferredInit }
}

if ($Host.Name -eq 'ConsoleHost' -and [Environment]::UserInteractive) {
    $null = Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -MaxTriggerCount 1 -Action {
        Invoke-PwshProfileIdleWork
    }
} else {
    Invoke-PwshProfileIdleWork
}
