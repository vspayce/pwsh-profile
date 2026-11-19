# Alias: genpass
function New-Password {
    <#
    .SYNOPSIS
        Generates strong random passwords locally (no website involved) and can copy one to the clipboard.
    .EXAMPLE
        genpass
    .EXAMPLE
        genpass -Length 24 -Copy
    .EXAMPLE
        New-Password -Count 5 -NoSymbols
    #>
    [CmdletBinding()]
    param(
        [ValidateRange(8, 256)][int]$Length = 20,
        [int]$Count = 1,
        [switch]$NoSymbols,
        [switch]$Copy
    )
    # Look-alike characters (0/O, 1/l/I) are left out so passwords are easy to read aloud
    $sets = @('ABCDEFGHJKLMNPQRSTUVWXYZ', 'abcdefghijkmnopqrstuvwxyz', '23456789')
    if (-not $NoSymbols) { $sets += '!@#$%^&*-_=+?' }
    $all = -join $sets

    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    $buf = [byte[]]::new(4)
    $next = {
        param([int]$max)
        # Rejection sampling avoids modulo bias
        $limit = [uint32]::MaxValue - ([uint32]::MaxValue % $max)
        do { $rng.GetBytes($buf); $v = [BitConverter]::ToUInt32($buf, 0) } while ($v -ge $limit)
        [int]($v % $max)
    }

    $results = for ($n = 0; $n -lt $Count; $n++) {
        # one character from each set guarantees complexity rules are met
        $chars = [Collections.Generic.List[char]]::new()
        foreach ($s in $sets) { $chars.Add($s[(& $next $s.Length)]) }
        while ($chars.Count -lt $Length) { $chars.Add($all[(& $next $all.Length)]) }
        for ($i = $chars.Count - 1; $i -gt 0; $i--) {   # Fisher-Yates shuffle
            $j = & $next ($i + 1)
            $t = $chars[$i]; $chars[$i] = $chars[$j]; $chars[$j] = $t
        }
        -join $chars
    }
    $rng.Dispose()

    if ($Copy) {
        $results | Select-Object -First 1 | Set-Clipboard
        Write-Host 'Copied to clipboard.' -ForegroundColor Green
    }
    $results
}
