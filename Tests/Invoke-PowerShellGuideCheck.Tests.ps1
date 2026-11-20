#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }, PSScriptAnalyzer

BeforeAll {
    $repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
    $checkScript = Join-Path $repoRoot 'Invoke-PowerShellGuideCheck.ps1'
}

Describe 'Invoke-PowerShellGuideCheck.ps1' {
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
        ($output | Out-String) | Should -Match 'GuideAvoidInvokeExpression|PSAvoidUsingInvokeExpression'
    }

    It 'reports possible array append inefficiency without failing the audit' {
        $fixture = Join-Path $TestDrive 'ArrayAppend.ps1'
        Set-Content -LiteralPath $fixture -Value '$items = @(); $items += 1' -Encoding utf8

        $output = & pwsh -NoProfile -NonInteractive -File $checkScript -Path $fixture 2>&1

        $LASTEXITCODE | Should -Be 0
        ($output | Out-String) | Should -Match 'GuideAvoidArrayAppend'
    }
}
