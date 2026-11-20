#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }, PSScriptAnalyzer

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Variables assigned in Pester BeforeAll are used in It and AfterAll blocks, which the analyzer cannot see across.'
)]
param()

BeforeAll {
    $repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
    $checkScript = Join-Path $repoRoot 'Invoke-PowerShellGuideCheck.ps1'
    $originalXdgCacheHome = $env:XDG_CACHE_HOME
}

AfterAll {
    if ($null -eq $originalXdgCacheHome) {
        Remove-Item -LiteralPath Env:XDG_CACHE_HOME -ErrorAction Ignore
    } else {
        $env:XDG_CACHE_HOME = $originalXdgCacheHome
    }
}

Describe 'Invoke-PowerShellGuideCheck.ps1' {
    BeforeEach {
        # Keep child pwsh processes from writing PowerShell caches outside the test sandbox.
        # Pester v5 does not allow BeforeEach at the file root, so it lives inside Describe.
        $env:XDG_CACHE_HOME = Join-Path $TestDrive 'powershell-cache'
    }

    It 'accepts clean PowerShell source' {
        $fixture = Join-Path $TestDrive 'Clean.ps1'
        Set-Content -LiteralPath $fixture -Value '# clean fixture' -Encoding utf8

        & pwsh -NoProfile -NonInteractive -File $checkScript -Path $fixture

        $LASTEXITCODE | Should -Be 0
    }

    It 'fails and identifies Invoke-Expression' {
        $fixture = Join-Path $TestDrive 'Unsafe.ps1'
        Set-Content -LiteralPath $fixture -Value "Invoke-Expression 'Get-Date'" -Encoding utf8

        $output = & pwsh -NoProfile -NonInteractive -File $checkScript -Path $fixture 2>&1

        $LASTEXITCODE | Should -Be 1
        ($output | Out-String) | Should -Match 'PSAvoidUsingInvokeExpression'
    }

    It 'reports array appends inside a loop without failing the audit' {
        $fixture = Join-Path $TestDrive 'ArrayAppend.ps1'
        Set-Content -LiteralPath $fixture -Value '$items = @(); foreach ($n in 1..3) { $items += $n }' -Encoding utf8

        $output = & pwsh -NoProfile -NonInteractive -File $checkScript -Path $fixture -Severity Information 2>&1

        $LASTEXITCODE | Should -Be 0
        ($output | Out-String) | Should -Match 'GuideAvoidArrayAppend'
    }

    It 'reports array appends inside a ForEach-Object script block' {
        $fixture = Join-Path $TestDrive 'PipelineAppend.ps1'
        Set-Content -LiteralPath $fixture -Value '$items = @(); 1..3 | ForEach-Object { $items += $_ }' -Encoding utf8

        $output = & pwsh -NoProfile -NonInteractive -File $checkScript -Path $fixture -Severity Information 2>&1

        $LASTEXITCODE | Should -Be 0
        ($output | Out-String) | Should -Match 'GuideAvoidArrayAppend'
    }

    It 'does not report += on counters, strings, or appends outside a loop' {
        $fixture = Join-Path $TestDrive 'NotArrayAppend.ps1'
        $source = @(
            '$count = 0; foreach ($n in 1..3) { $count += $n }'
            '$text = ''''; while ($text.Length -lt 3) { $text += ''x'' }'
            '$items = @(); $items += 1'
        )
        Set-Content -LiteralPath $fixture -Value $source -Encoding utf8

        $output = & pwsh -NoProfile -NonInteractive -File $checkScript -Path $fixture -Severity Information 2>&1

        $LASTEXITCODE | Should -Be 0
        ($output | Out-String) | Should -Not -Match 'GuideAvoidArrayAppend'
    }

    It 'omits informational guide findings at the default severity' {
        $fixture = Join-Path $TestDrive 'ArrayAppendDefault.ps1'
        Set-Content -LiteralPath $fixture -Value '$items = @(); foreach ($n in 1..3) { $items += $n }' -Encoding utf8

        $output = & pwsh -NoProfile -NonInteractive -File $checkScript -Path $fixture 2>&1

        $LASTEXITCODE | Should -Be 0
        ($output | Out-String) | Should -Not -Match 'GuideAvoidArrayAppend'
    }

    It 'finds the settings file by walking up from the target path' {
        $projectRoot = Join-Path $TestDrive 'project'
        $sourceDirectory = Join-Path $projectRoot 'src'
        $null = New-Item -ItemType Directory -Path $sourceDirectory -Force
        $null = New-Item -ItemType Directory -Path (Join-Path $projectRoot '.git') -Force
        Set-Content -LiteralPath (Join-Path $projectRoot 'PSScriptAnalyzerSettings.psd1') -Value "@{ ExcludeRules = @('PSAvoidUsingInvokeExpression') }" -Encoding utf8
        $fixture = Join-Path $sourceDirectory 'UsesIex.ps1'
        Set-Content -LiteralPath $fixture -Value "Invoke-Expression 'Get-Date'" -Encoding utf8

        # Run from an unrelated directory to prove discovery does not depend on the caller's location.
        Push-Location -LiteralPath $TestDrive
        try {
            $output = & pwsh -NoProfile -NonInteractive -File $checkScript -Path $fixture 2>&1
        } finally {
            Pop-Location
        }

        $LASTEXITCODE | Should -Be 0
        ($output | Out-String) | Should -Match ([regex]::Escape((Join-Path $projectRoot 'PSScriptAnalyzerSettings.psd1')))
    }

    It 'applies the repository formatting rules' {
        $fixture = Join-Path $TestDrive 'BadFormat.ps1'
        $source = @(
            'if ($true)'
            '{'
            '  Write-Output 1'
            '}'
        )
        Set-Content -LiteralPath $fixture -Value $source -Encoding utf8

        $output = & pwsh -NoProfile -NonInteractive -File $checkScript -Path $fixture -Settings (Join-Path $repoRoot 'PSScriptAnalyzerSettings.psd1') 2>&1

        $LASTEXITCODE | Should -Be 1
        ($output | Out-String) | Should -Match 'PSPlaceOpenBrace'
        ($output | Out-String) | Should -Match 'PSUseConsistentIndentation'
    }

    It 'fails with a useful error for a missing path' {
        $missingPath = Join-Path $TestDrive 'does-not-exist.ps1'

        $output = & pwsh -NoProfile -NonInteractive -File $checkScript -Path $missingPath 2>&1

        $LASTEXITCODE | Should -Be 1
        ($output | Out-String) | Should -Match 'Cannot find path|cannot find path'
    }

    It 'reports PowerShell parser errors and exits nonzero' {
        $fixture = Join-Path $TestDrive 'InvalidSyntax.ps1'
        Set-Content -LiteralPath $fixture -Value 'if (' -Encoding utf8

        $output = & pwsh -NoProfile -NonInteractive -File $checkScript -Path $fixture 2>&1

        $LASTEXITCODE | Should -Be 1
        ($output | Out-String) | Should -Match 'GuideParseError'
    }

    It 'warns and exits successfully when a directory contains no PowerShell files' {
        $emptyDirectory = Join-Path $TestDrive 'empty'
        $null = New-Item -ItemType Directory -Path $emptyDirectory

        $output = & pwsh -NoProfile -NonInteractive -File $checkScript -Path $emptyDirectory 2>&1

        $LASTEXITCODE | Should -Be 0
        ($output | Out-String) | Should -Match 'No PowerShell source files found'
    }
}
