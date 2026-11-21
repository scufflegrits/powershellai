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

    It 'reports <Expected> array findings for <Case>' -ForEach @(
        @{
            Case     = 'an array and counter in sibling functions'
            Source   = 'function Get-Items { $items = @(); $items }; function Get-Total { $items = 0; foreach ($n in 1..3) { $items += $n }; $items }'
            Expected = 0
        }
        @{
            Case     = 'a script array and function-local counter'
            Source   = '$items = @(); function Get-Total { $items = 0; foreach ($n in 1..3) { $items += $n }; $items }'
            Expected = 0
        }
        @{
            Case     = 'a function array and script-level counter'
            Source   = 'function Get-Items { $items = @(); $items }; $items = 0; foreach ($n in 1..3) { $items += $n }'
            Expected = 0
        }
        @{
            Case     = 'an outer array and nested function counter'
            Source   = 'function Get-Items { $items = @(); function Get-Total { $items = 0; foreach ($n in 1..3) { $items += $n }; $items }; $items }'
            Expected = 0
        }
        @{
            Case     = 'a function defined inside a loop without its own loop'
            Source   = 'foreach ($n in 1..3) { function Get-Items { $items = @(); $items += 1; $items } }'
            Expected = 0
        }
        @{
            Case     = 'an array loop inside a function'
            Source   = 'function Get-Items { $items = @(); foreach ($n in 1..3) { $items += $n }; $items }'
            Expected = 1
        }
        @{
            Case     = 'a function array loop beside an unrelated counter loop'
            Source   = 'function Get-Items { $items = @(); foreach ($n in 1..3) { $items += $n }; $items }; function Get-Total { $items = 0; foreach ($n in 1..3) { $items += $n }; $items }'
            Expected = 1
        }
    ) {
        $fixture = Join-Path $TestDrive 'FunctionScopes.ps1'
        Set-Content -LiteralPath $fixture -Value $Source -Encoding utf8

        $output = & pwsh -NoProfile -NonInteractive -File $checkScript -Path $fixture -Severity Information 2>&1

        $LASTEXITCODE | Should -Be 0
        @($output | Select-String -SimpleMatch 'GuideAvoidArrayAppend').Count | Should -Be $Expected
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

    It 'uses the nearest settings for a <TargetKind> target' -ForEach @(
        @{ TargetKind = 'file' }
        @{ TargetKind = 'directory' }
    ) {
        $projectRoot = Join-Path $TestDrive 'nearest-project'
        $sourceDirectory = Join-Path $projectRoot 'src'
        $null = New-Item -ItemType Directory -Path $sourceDirectory -Force
        $null = New-Item -ItemType Directory -Path (Join-Path $projectRoot '.git') -Force
        $rootSettings = Join-Path $projectRoot 'PSScriptAnalyzerSettings.psd1'
        $nearestSettings = Join-Path $sourceDirectory 'PSScriptAnalyzerSettings.psd1'
        Set-Content -LiteralPath $rootSettings -Value "@{ IncludeRules = @('PSAvoidUsingInvokeExpression') }" -Encoding utf8
        Set-Content -LiteralPath $nearestSettings -Value "@{ ExcludeRules = @('PSAvoidUsingInvokeExpression') }" -Encoding utf8
        $fixture = Join-Path $sourceDirectory 'UsesIex.ps1'
        Set-Content -LiteralPath $fixture -Value "Invoke-Expression 'Get-Date'" -Encoding utf8
        $target = if ($TargetKind -eq 'file') { $fixture } else { $sourceDirectory }

        $output = & pwsh -NoProfile -NonInteractive -File $checkScript -Path $target 2>&1

        $LASTEXITCODE | Should -Be 0
        ($output | Out-String) | Should -Match ([regex]::Escape($nearestSettings))
        ($output | Out-String) | Should -Not -Match 'PSAvoidUsingInvokeExpression'
    }

    It 'uses explicit settings instead of the nearest settings' {
        $projectRoot = Join-Path $TestDrive 'explicit-project'
        $null = New-Item -ItemType Directory -Path $projectRoot
        $nearestSettings = Join-Path $projectRoot 'PSScriptAnalyzerSettings.psd1'
        $explicitSettings = Join-Path $TestDrive 'ExplicitSettings.psd1'
        Set-Content -LiteralPath $nearestSettings -Value "@{ ExcludeRules = @('PSAvoidUsingInvokeExpression') }" -Encoding utf8
        Set-Content -LiteralPath $explicitSettings -Value "@{ IncludeRules = @('PSAvoidUsingInvokeExpression') }" -Encoding utf8
        $fixture = Join-Path $projectRoot 'UsesIex.ps1'
        Set-Content -LiteralPath $fixture -Value "Invoke-Expression 'Get-Date'" -Encoding utf8

        $output = & pwsh -NoProfile -NonInteractive -File $checkScript -Path $fixture -Settings $explicitSettings 2>&1

        $LASTEXITCODE | Should -Be 1
        ($output | Out-String) | Should -Match ([regex]::Escape($explicitSettings))
        ($output | Out-String) | Should -Match 'PSAvoidUsingInvokeExpression'
    }

    It 'ignores settings above a repository with a .git <MarkerKind>' -ForEach @(
        @{ MarkerKind = 'directory' }
        @{ MarkerKind = 'file' }
    ) {
        $parentDirectory = Join-Path $TestDrive "outside-repository-$MarkerKind"
        $projectRoot = Join-Path $parentDirectory 'project'
        $sourceDirectory = Join-Path $projectRoot 'src'
        $null = New-Item -ItemType Directory -Path $sourceDirectory -Force
        $marker = Join-Path $projectRoot '.git'
        if ($MarkerKind -eq 'directory') {
            $null = New-Item -ItemType Directory -Path $marker
        } else {
            Set-Content -LiteralPath $marker -Value 'gitdir: ../worktree-metadata' -Encoding utf8
        }
        Set-Content -LiteralPath (Join-Path $parentDirectory 'PSScriptAnalyzerSettings.psd1') -Value "@{ ExcludeRules = @('PSAvoidUsingInvokeExpression') }" -Encoding utf8
        $fixture = Join-Path $sourceDirectory 'UsesIex.ps1'
        Set-Content -LiteralPath $fixture -Value "Invoke-Expression 'Get-Date'" -Encoding utf8

        $output = & pwsh -NoProfile -NonInteractive -File $checkScript -Path $fixture 2>&1

        $LASTEXITCODE | Should -Be 1
        ($output | Out-String) | Should -Match 'using PSScriptAnalyzer default rules'
        ($output | Out-String) | Should -Match 'PSAvoidUsingInvokeExpression'
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
