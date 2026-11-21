#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Pester lifecycle variables are used across BeforeAll, BeforeEach, and It blocks.'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSReviewUnusedParameter', '',
    Justification = 'Pester uses ScriptPath in BeforeAll during its Run phase.'
)]
param(
    [string] $ScriptPath = (Join-Path (Split-Path $PSScriptRoot -Parent) 'after/Get-LogSummary.ps1')
)

BeforeAll {
    $scriptUnderTest = (Resolve-Path -LiteralPath $ScriptPath -ErrorAction Stop).Path
}

Describe 'Get-LogSummary behavior' {
    BeforeEach {
        $sampleDirectory = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Path $sampleDirectory
    }

    It 'returns one summary object for <Count> log files' -ForEach @(
        @{ Count = 0 }
        @{ Count = 1 }
        @{ Count = 3 }
    ) {
        for ($index = 0; $index -lt $Count; $index++) {
            Set-Content -LiteralPath (Join-Path $sampleDirectory "app-$index.log") -Value 'sample' -Encoding utf8
        }

        $results = @(& $scriptUnderTest -Path $sampleDirectory)

        $results | Should -HaveCount 1
        $results[0].Path | Should -Be $sampleDirectory
        $results[0].LogCount | Should -Be $Count
    }

    It 'ignores non-log files and logs in subdirectories' {
        Set-Content -LiteralPath (Join-Path $sampleDirectory 'notes.txt') -Value 'sample' -Encoding utf8
        $nestedDirectory = Join-Path $sampleDirectory 'nested'
        $null = New-Item -ItemType Directory -Path $nestedDirectory
        Set-Content -LiteralPath (Join-Path $nestedDirectory 'nested.log') -Value 'sample' -Encoding utf8

        (& $scriptUnderTest -Path $sampleDirectory).LogCount | Should -Be 0
    }

    It 'counts files but excludes directories named with a .log suffix' {
        Set-Content -LiteralPath (Join-Path $sampleDirectory 'app.log') -Value 'sample' -Encoding utf8
        $null = New-Item -ItemType Directory -Path (Join-Path $sampleDirectory 'archive.log')

        (& $scriptUnderTest -Path $sampleDirectory).LogCount | Should -Be 1
    }

    It 'treats brackets and spaces in the directory path literally' {
        $literalDirectory = Join-Path $sampleDirectory 'logs [sample]'
        $null = New-Item -ItemType Directory -Path $literalDirectory
        Set-Content -LiteralPath (Join-Path $literalDirectory 'app.log') -Value 'sample' -Encoding utf8

        (& $scriptUnderTest -Path $literalDirectory).LogCount | Should -Be 1
    }

    It 'rejects a missing directory with a terminating error' {
        $missingDirectory = Join-Path $sampleDirectory 'missing'

        { & $scriptUnderTest -Path $missingDirectory } | Should -Throw
    }

    It 'rejects a file supplied as the directory' {
        $file = Join-Path $sampleDirectory 'app.log'
        Set-Content -LiteralPath $file -Value 'sample' -Encoding utf8

        { & $scriptUnderTest -Path $file } | Should -Throw '*Path must be a directory*'
    }
}
