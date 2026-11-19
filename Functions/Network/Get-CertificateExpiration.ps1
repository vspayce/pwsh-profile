# Alias: certexp
function Get-CertificateExpiration {
    <#
    .SYNOPSIS
        Connects to a TLS endpoint and reports when its certificate expires.
    .DESCRIPTION
        Works even if the certificate is expired or untrusted (it reports that
        instead of failing), so it is handy for auditing internal servers.
    .EXAMPLE
        certexp github.com
    .EXAMPLE
        'mail.contoso.com','vpn.contoso.com' | Get-CertificateExpiration | Sort-Object DaysLeft
    .EXAMPLE
        Get-CertificateExpiration ldap01 -Port 636
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [string[]]$ComputerName,

        [int]$Port = 443,
        [int]$TimeoutMs = 5000
    )
    process {
        foreach ($computer in $ComputerName) {
            $tcp = [System.Net.Sockets.TcpClient]::new()
            try {
                $ar = $tcp.BeginConnect($computer, $Port, $null, $null)
                if (-not $ar.AsyncWaitHandle.WaitOne($TimeoutMs, $false)) { throw "Timed out connecting to ${computer}:$Port" }
                $tcp.EndConnect($ar)

                $state = @{ Errors = 'None' }
                $callback = [System.Net.Security.RemoteCertificateValidationCallback] {
                    param($s, $c, $chain, $errors)
                    $state.Errors = $errors.ToString()
                    $true
                }.GetNewClosure()
                $ssl = [System.Net.Security.SslStream]::new($tcp.GetStream(), $false, $callback)
                try {
                    $ssl.AuthenticateAsClient($computer)
                    $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($ssl.RemoteCertificate)
                    [PSCustomObject]@{
                        ComputerName = $computer
                        Port         = $Port
                        Subject      = $cert.Subject
                        Issuer       = $cert.Issuer
                        NotAfter     = $cert.NotAfter
                        DaysLeft     = [int][Math]::Floor(($cert.NotAfter - (Get-Date)).TotalDays)
                        Valid        = $state.Errors -eq 'None'
                        Errors       = $state.Errors
                        Thumbprint   = $cert.Thumbprint
                    }
                } finally { $ssl.Dispose() }
            } catch {
                Write-Error "${computer}:$Port - $($_.Exception.Message)"
            } finally {
                $tcp.Dispose()
            }
        }
    }
}
