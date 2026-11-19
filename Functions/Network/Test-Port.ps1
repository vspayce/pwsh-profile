# Alias: tp
function Test-Port {
    <#
    .SYNOPSIS
        Fast TCP port check for one or more hosts and ports.
    .DESCRIPTION
        Much faster than Test-NetConnection when checking several ports, and works on
        Windows, macOS and Linux.
    .EXAMPLE
        Test-Port dc01 389,636,3268
    .EXAMPLE
        'web01','web02' | Test-Port -Port 443 -TimeoutMs 500
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Host', 'CN', 'Name')]
        [string[]]$ComputerName,

        [Parameter(Mandatory, Position = 1)]
        [int[]]$Port,

        [int]$TimeoutMs = 1000
    )
    process {
        foreach ($computer in $ComputerName) {
            foreach ($p in $Port) {
                $tcp = [System.Net.Sockets.TcpClient]::new()
                $sw = [Diagnostics.Stopwatch]::StartNew()
                $open = $false
                try {
                    $ar = $tcp.BeginConnect($computer, $p, $null, $null)
                    if ($ar.AsyncWaitHandle.WaitOne($TimeoutMs, $false)) {
                        $tcp.EndConnect($ar)
                        $open = $tcp.Connected
                    }
                } catch {
                    $open = $false
                } finally {
                    $sw.Stop()
                    $tcp.Dispose()
                }
                [PSCustomObject]@{
                    ComputerName = $computer
                    Port         = $p
                    Open         = $open
                    TimeMs       = [int]$sw.ElapsedMilliseconds
                }
            }
        }
    }
}
