# Alias: b64
function ConvertTo-Base64 {
    <#
    .SYNOPSIS
        Encodes text (UTF-8) or a file to Base64.
    .EXAMPLE
        b64 'hello world'
    .EXAMPLE
        ConvertTo-Base64 -Path .\cert.pfx
    #>
    [CmdletBinding(DefaultParameterSetName = 'Text')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ParameterSetName = 'Text')][string]$Text,
        [Parameter(Mandatory, ParameterSetName = 'File')][string]$Path
    )
    process {
        $bytes = if ($PSCmdlet.ParameterSetName -eq 'File') {
            [IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $Path).ProviderPath)
        } else { [Text.Encoding]::UTF8.GetBytes($Text) }
        [Convert]::ToBase64String($bytes)
    }
}
