# Alias(Windows): which
function Get-CommandPath {
    <#
    .SYNOPSIS
        Shows where a command comes from: exe path, alias target, function file, or cmdlet module.
    .EXAMPLE
        which git
    .EXAMPLE
        which uptime    # -> alias for Show-Uptime, defined in this profile
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory, Position = 0, ValueFromPipeline)][string[]]$Name)
    process {
        foreach ($n in $Name) {
            foreach ($c in (Get-Command $n -All -ErrorAction SilentlyContinue)) {
                $where = switch ($c.CommandType) {
                    'Application' { $c.Source }
                    'Alias'       { "-> $($c.Definition)" }
                    'Function'    {
                        if ($global:PwshProfileFunctions -and $global:PwshProfileFunctions[$c.Name]) { $global:PwshProfileFunctions[$c.Name] }
                        elseif ($c.ScriptBlock.File) { $c.ScriptBlock.File }
                        else { $c.Source }
                    }
                    default       { $c.Source }
                }
                [PSCustomObject]@{ Name = $c.Name; Type = $c.CommandType; Source = $where }
            }
        }
    }
}
