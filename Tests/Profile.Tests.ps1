#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeDiscovery {
    $root = Split-Path $PSScriptRoot -Parent
    $script:FunctionFiles = Get-ChildItem (Join-Path $root 'Functions') -Filter *.ps1 -Recurse -File |
        Where-Object { $_.FullName -notmatch '[\\/](Local|Private)[\\/]' } |
        ForEach-Object { @{ Name = $_.BaseName; Path = $_.FullName } }
    $script:AllScripts = Get-ChildItem $root -Filter *.ps1 -Recurse -File |
        Where-Object { $_.FullName -notmatch '[\\/]Local[\\/]' } |
        ForEach-Object { @{ Path = $_.FullName; Rel = $_.FullName.Substring($root.Length + 1) } }
}

Describe 'Every script parses' {
    It '<Rel> has no syntax errors' -ForEach $AllScripts {
        $errors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$errors)
        $errors | Should -BeNullOrEmpty
    }
    It '<Rel> is ASCII, or UTF-8 with a BOM (safe for Windows PowerShell 5.1)' -ForEach $AllScripts {
        $bytes = [IO.File]::ReadAllBytes($Path)
        $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
        if (-not $hasBom) { ($bytes | Where-Object { $_ -gt 127 }).Count | Should -Be 0 }
    }
}

Describe 'Function file conventions' {
    It '<Name>.ps1 defines exactly one top-level function named <Name>' -ForEach $FunctionFiles {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$null)
        $fns = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                $n.Parent.Parent -eq $ast }, $false)
        @($fns).Count | Should -Be 1
        $fns[0].Name | Should -Be $Name
    }
    It '<Name> has a .SYNOPSIS inside the function' -ForEach $FunctionFiles {
        . $Path
        (Get-Help $Name).Synopsis | Should -Not -BeNullOrEmpty
        (Get-Help $Name).Synopsis | Should -Not -Match '^\s*\S+\s*\[?$|^TODO'
    }
    It '<Name> loads through its stub without errors' -ForEach $FunctionFiles {
        . (Join-Path (Split-Path $PSScriptRoot -Parent) 'profile.ps1')
        { Import-ProfileFunction -Name $Name } | Should -Not -Throw
    }
}

Describe 'Loader' {
    BeforeAll {
        $root = Split-Path $PSScriptRoot -Parent
        . (Join-Path $root 'profile.ps1')
    }

    It 'registers every function file' {
        $expected = (Get-ChildItem (Join-Path $root 'Functions') -Filter *.ps1 -Recurse -File |
            Where-Object { $_.FullName -notmatch '[\\/](Local|Private)[\\/]' }).Count
        $PwshProfileFunctions.Count | Should -BeGreaterOrEqual $expected
    }

    It 'has no alias pointing at two functions' {
        $seen = @{}
        foreach ($f in $PwshProfileFunctions.Values) {
            foreach ($line in (Get-Content $f -TotalCount 12)) {
                if ($line -match '^\s*#\s*Alias(?:es)?(?:\((\w+)\))?\s*:\s*(.+)$') {
                    foreach ($a in ($Matches[2] -split '[,\s]+' | Where-Object { $_ })) {
                        $seen.ContainsKey($a) | Should -BeFalse -Because "alias '$a' is declared twice"
                        $seen[$a] = $f
                    }
                }
            }
        }
    }

    It 'creates a stub, then swaps in the real function on first call' {
        (Get-Item function:Convert-MacAddress).ScriptBlock.ToString() | Should -BeLike '*__PwshProfileStub__*'
        Convert-MacAddress -MacAddress '00-1A-2B-3C-4D-5E' -Format Colon | Should -Be '00:1A:2B:3C:4D:5E'
        (Get-Item function:Convert-MacAddress).ScriptBlock.ToString() | Should -Not -BeLike '*__PwshProfileStub__*'
    }

    It 'forwards pipeline input through the stub' {
        Invoke-ProfileReload *> $null    # fresh stubs
        $r = '001a.2b3c.4d5e', '00:1a:2b:3c:4d:5f' | Convert-MacAddress -Format Plain
        $r | Should -Be @('001A2B3C4D5E', '001A2B3C4D5F')
    }

    It 'forwards positional and switch arguments through the stub' {
        Invoke-ProfileReload *> $null
        $p = New-Password -Length 16 -Count 2 -NoSymbols
        $p.Count | Should -Be 2
        $p | ForEach-Object { $_.Length | Should -Be 16; $_ | Should -Match '^[A-Za-z0-9]+$' }
    }

    It 'aliases work before the function is loaded' {
        Invoke-ProfileReload *> $null
        (Get-Alias mac).Definition | Should -Be 'Convert-MacAddress'
        mac 001a2b3c4d5e -Format Dash | Should -Be '00-1A-2B-3C-4D-5E'
    }

    It 'prompt records directory history' {
        $start = Get-Location
        try {
            Set-Location ([IO.Path]::GetTempPath()); $null = prompt
            Set-Location $root; $null = prompt
            $DirHistory[0] | Should -Be (Get-Location).ProviderPath
            $DirHistory[1] | Should -Be ([IO.Path]::GetTempPath().TrimEnd('\', '/'))
            Set-LocationFromHistory 1
            (Get-Location).ProviderPath | Should -Be ([IO.Path]::GetTempPath().TrimEnd('\', '/'))
        } finally { Set-Location $start }
    }

    It 'prompt shows the git branch without calling git' {
        $tmp = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Path (Join-Path $tmp '.git/refs') -Force
        Set-Content -Path (Join-Path $tmp '.git/HEAD') -Value 'ref: refs/heads/feature/test'
        try { Get-PwshProfileGitBranch -Path $tmp | Should -Be 'feature/test' }
        finally { Remove-Item $tmp -Recurse -Force }
    }
}

Describe 'Functions (offline)' {
    BeforeAll { . (Join-Path (Split-Path $PSScriptRoot -Parent) 'profile.ps1') }

    It 'Base64 round-trips' {
        ConvertTo-Base64 'hello world' | ConvertFrom-Base64 | Should -Be 'hello world'
    }
    It 'Test-Port reports a closed port as closed' {
        (Test-Port -ComputerName 127.0.0.1 -Port 1 -TimeoutMs 300).Open | Should -BeFalse
    }
    It 'Get-Hash -Expected detects a match and a mismatch' {
        $f = New-TemporaryFile
        try {
            Set-Content $f 'abc' -NoNewline
            $h = Get-Hash $f
            Get-Hash $f -Expected $h 6> $null | Should -BeTrue
            Get-Hash $f -Expected ('0' * 64) 6> $null | Should -BeFalse
        } finally { Remove-Item $f }
    }
    It 'New-Password always includes each character class' {
        1..20 | ForEach-Object {
            $p = New-Password -Length 8
            $p | Should -MatchExactly '[A-Z]'
            $p | Should -MatchExactly '[a-z]'
            $p | Should -Match '[0-9]'
        }
    }
}
