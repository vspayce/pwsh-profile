# Prompt: [ADMIN] ~/path (git-branch) 3.4s
#         >
# Also records every folder you visit into $DirHistory (see 'dh' and 'j'),
# sets the window title, and tells Windows Terminal the current folder so
# "Duplicate tab" opens in the same place.

function global:Get-PwshProfileGitBranch {
    param([string]$Path)
    # Walk up looking for .git without running git.exe (keeps the prompt instant)
    $dir = $Path
    while ($dir) {
        $git = [IO.Path]::Combine($dir, '.git')
        if ([IO.Directory]::Exists($git)) { $head = [IO.Path]::Combine($git, 'HEAD'); break }
        if ([IO.File]::Exists($git)) {
            # Worktree / submodule: ".git" is a file pointing at the real git dir
            $line = [IO.File]::ReadAllText($git).Trim()
            if ($line -match '^gitdir:\s*(.+)$') {
                $gd = $Matches[1]
                if (-not [IO.Path]::IsPathRooted($gd)) { $gd = [IO.Path]::Combine($dir, $gd) }
                $head = [IO.Path]::Combine($gd, 'HEAD')
            }
            break
        }
        $dir = [IO.Path]::GetDirectoryName($dir)
    }
    if (-not $head -or -not [IO.File]::Exists($head)) { return $null }
    $ref = [IO.File]::ReadAllText($head).Trim()
    if ($ref -match '^ref:\s*refs/heads/(.+)$') { return $Matches[1] }
    if ($ref.Length -ge 7) { return $ref.Substring(0, 7) }   # detached HEAD
    return $null
}

function global:prompt {
    $lastOk = $?
    $e   = [char]27
    $cfg = $global:PwshProfileConfig
    $loc = $ExecutionContext.SessionState.Path.CurrentLocation
    $isFs = $loc.Provider.Name -eq 'FileSystem'
    $fsPath = if ($isFs) { $loc.ProviderPath } else { $loc.Path }

    # --- directory history ---
    if ($isFs -and ($global:DirHistory.Count -eq 0 -or $global:DirHistory[0] -ne $fsPath)) {
        $null = $global:DirHistory.Remove($fsPath)
        $global:DirHistory.Insert(0, $fsPath)
        $max = if ($cfg.DirHistoryMax) { $cfg.DirHistoryMax } else { 50 }
        while ($global:DirHistory.Count -gt $max) { $global:DirHistory.RemoveAt($global:DirHistory.Count - 1) }
    }

    # --- pieces ---
    $display = $loc.Path
    if ($isFs -and $HOME -and $fsPath.StartsWith($HOME, [StringComparison]::OrdinalIgnoreCase)) {
        $display = '~' + $fsPath.Substring($HOME.Length)
    }

    $sb = [Text.StringBuilder]::new()
    if ($global:PwshIsAdmin) { $null = $sb.Append("$e[41;97m ADMIN $e[0m ") }
    if ($env:SSH_CONNECTION -or $PSSenderInfo) {
        $null = $sb.Append("$e[35m$([Environment]::UserName)@$([Environment]::MachineName)$e[0m ")
    }
    $null = $sb.Append("$e[36m$display$e[0m")

    if ($cfg.ShowGitBranch -and $isFs) {
        $branch = Get-PwshProfileGitBranch -Path $fsPath
        if ($branch) { $null = $sb.Append(" $e[33m($branch)$e[0m") }
    }

    if ($cfg.ShowDuration) {
        $h = Get-History -Count 1
        if ($h -and $h.Id -ne $global:PwshProfileState.LastHistoryId) {
            $global:PwshProfileState.LastHistoryId = $h.Id
            $ms = ($h.EndExecutionTime - $h.StartExecutionTime).TotalMilliseconds
            if ($ms -ge $cfg.DurationThresholdMs) {
                $txt = if ($ms -ge 60000) { '{0:N1}m' -f ($ms / 60000) } else { '{0:N1}s' -f ($ms / 1000) }
                $null = $sb.Append(" $e[90m$txt$e[0m")
            }
        }
    }

    # --- window title ---
    try {
        $leaf = if ($isFs) { Split-Path -Leaf $fsPath } else { $loc.Path }
        if (-not $leaf) { $leaf = $fsPath }
        $Host.UI.RawUI.WindowTitle = $(if ($global:PwshIsAdmin) { "[Admin] $leaf" } else { $leaf })
    } catch { }

    # --- Windows Terminal: remember cwd for "Duplicate tab" / split pane ---
    if ($env:WT_SESSION -and $isFs) { $null = $sb.Append("$e]9;9;`"$fsPath`"$e\") }

    # --- second line ---
    $charColor = if ($lastOk) { '32' } else { '31' }
    $nest = '>' * $NestedPromptLevel
    $null = $sb.Append("`n$e[${charColor}m$($cfg.PromptChar)$nest$e[0m ")
    $sb.ToString()
}
