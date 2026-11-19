# Alias: admin
function Start-Elevated {
    <#
    .SYNOPSIS
        Opens an elevated (Administrator) shell, optionally running a command in it.
    .DESCRIPTION
        Uses Windows Terminal when it is installed, otherwise a plain console window.
        The command is passed with -EncodedCommand, so quotes and $variables survive intact.
        On macOS/Linux it runs the command with sudo instead.
    .EXAMPLE
        admin
    .EXAMPLE
        admin Restart-Service Spooler
    .EXAMPLE
        admin 'Get-Service | Where-Object Status -eq "Stopped"'
    #>
    param([Parameter(ValueFromRemainingArguments)][string[]]$Command)

    $shell = (Get-Process -Id $PID).Path   # same edition you are running now
    $cmdText = $Command -join ' '

    if (-not $global:PwshIsWindows) {
        if ($cmdText) { sudo $shell -NoLogo -Command $cmdText } else { sudo $shell -NoLogo }
        return
    }

    $psArgs = @('-NoExit', '-NoLogo')
    if ($cmdText) {
        $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes("Set-Location -LiteralPath '$($PWD.ProviderPath -replace "'", "''")'; $cmdText"))
        $psArgs += @('-EncodedCommand', $enc)
    }

    if (Get-Command wt.exe -ErrorAction SilentlyContinue) {
        Start-Process wt.exe -Verb RunAs -ArgumentList (@('-d', '.', $shell) + $psArgs)
    } else {
        Start-Process $shell -Verb RunAs -ArgumentList $psArgs -WorkingDirectory $PWD.ProviderPath
    }
}
