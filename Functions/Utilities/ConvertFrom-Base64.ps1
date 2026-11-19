# Alias: unb64
function ConvertFrom-Base64 {
    <#
    .SYNOPSIS
        Decodes Base64 to text (UTF-8), or to a file with -OutFile.
    .EXAMPLE
        unb64 aGVsbG8gd29ybGQ=
    .EXAMPLE
        Get-Content blob.txt -Raw | ConvertFrom-Base64 -OutFile .\cert.pfx
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)][string]$Base64,
        [string]$OutFile
    )
    process {
        $bytes = [Convert]::FromBase64String($Base64.Trim())
        if ($OutFile) {
            [IO.File]::WriteAllBytes($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutFile), $bytes)
        } else {
            [Text.Encoding]::UTF8.GetString($bytes)
        }
    }
}
