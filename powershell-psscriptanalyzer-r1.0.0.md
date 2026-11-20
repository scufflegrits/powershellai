# PowerShell Static Analysis with PSScriptAnalyzer

**Guide version:** 1.0.0  
**Purpose:** A practical guide to configuring, running, and maintaining static analysis for PowerShell scripts and modules.

## Table of contents

1. [Role and limits](#role-and-limits)
2. [Inspect project setup](#inspect-project-setup)
3. [Run PSScriptAnalyzer](#run-psscriptanalyzer)
4. [Configure rules](#configure-rules)
5. [Check compatibility](#check-compatibility)
6. [Formatting and suppressions](#formatting-and-suppressions)
7. [CI and agent workflow](#ci-and-agent-workflow)
8. [Example quality test](#example-quality-test)
9. [References](#references)

## Role and limits

PSScriptAnalyzer inspects PowerShell source using static rules. It can report patterns such as aliases, unapproved verbs, unused variables, unsafe command construction, and selected compatibility problems. It does not execute the code, so it cannot prove runtime correctness or replace Pester and target-environment validation.

## Inspect project setup

Before running analysis, inspect repository instructions, CI workflows, and any `PSScriptAnalyzerSettings.psd1` or documented lint task. Use the repository's pinned analyzer version and settings so local and CI results agree. Do not install tools or update dependencies implicitly.

## Run PSScriptAnalyzer

When the repository provides settings, pass them explicitly:

```powershell
Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./PSScriptAnalyzerSettings.psd1
```

Without project settings, run the default rules and review at least errors and warnings:

```powershell
Invoke-ScriptAnalyzer -Path . -Recurse -Severity Error, Warning
```

To make findings fail a CI step, check the result and report findings:

```powershell
$findings = @(
    Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./PSScriptAnalyzerSettings.psd1 -Severity Error, Warning
)

if ($findings.Count -gt 0) {
    $findings | Format-Table -AutoSize
    throw "PSScriptAnalyzer reported $($findings.Count) finding(s)."
}
```

When no settings file exists, omit `-Settings`. Configure the CI severity gate to match the project's policy; a zero-warning policy may require gradual adoption for an existing codebase.

## Configure rules

Keep a settings file under version control to make local and CI analysis consistent. Start with the repository's conventions and enable only rules the team intends to enforce. For example:

```powershell
@{
    Severity = @('Error', 'Warning')
    Rules    = @{
        PSUseApprovedVerbs = @{
            Enable = $true
        }
        PSAvoidUsingCmdletAliases = @{
            Enable = $true
        }
    }
}
```

Rule names and configuration options depend on the installed PSScriptAnalyzer version. Validate settings with that version and use official rule documentation when tuning behavior.

## Check compatibility

For projects supporting multiple PowerShell versions or operating systems, configure the compatibility rules in `PSScriptAnalyzerSettings.psd1`:

- `PSUseCompatibleSyntax` checks syntax against target PowerShell versions.
- `PSUseCompatibleCommands` checks command availability and compatibility in target environments.
- `PSUseCompatibleTypes` checks .NET type and API availability.

Set target versions and platform profiles to match the actual support contract. These checks are static indicators; run tests in the supported environments for runtime confirmation.

## Formatting and suppressions

### Formatting

`Invoke-Formatter` formats source according to analyzer settings. Use it when formatting is part of the repository workflow. Avoid reformatting untouched files during focused changes, and inspect the diff before accepting formatter output.

```powershell
$source = Get-Content -LiteralPath './src/Get-Thing.ps1' -Raw
$formatted = Invoke-Formatter -ScriptDefinition $source
$formatted
```

### Suppressions

Fix valid findings where practical. If a finding is a false positive or conflicts with an intentional design constraint, use a narrow suppression with a clear justification. Avoid file-wide or global suppressions unless necessary and documented.

```powershell
function Convert-TestCredential {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingConvertToSecureStringWithPlainText',
        '',
        Justification = 'Uses a dummy value in an isolated test fixture.'
    )]
    param()

    # Test-only implementation.
}
```

Confirm suppression syntax and scope against the installed analyzer version. Never use suppressions to hide real security issues or to make CI appear green.

## CI and agent workflow

1. Inspect the repository's analyzer settings and CI entry point.
2. Run analysis on modified files first, then on the configured project scope when appropriate.
3. Fix valid findings; document narrowly scoped exceptions.
4. Report the PSScriptAnalyzer version, exact command, finding count/severities, and any checks that could not run.

PSScriptAnalyzer reports findings; it does not provide test pass/fail counts. Pair static analysis with Pester tests for behavior verification.

## Example quality test

Pester can check module metadata and run static analysis as a quality gate. Keep this check consistent with the repository's standalone analyzer task so rule settings and target scope do not drift.

```powershell
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }, PSScriptAnalyzer

BeforeAll {
    $repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
    $manifestPath = Join-Path $repoRoot 'MyModule.psd1'
    $settingsPath = Join-Path $repoRoot 'PSScriptAnalyzerSettings.psd1'
}

Describe 'Module quality' {
    It 'has a valid manifest and explicit function exports' {
        $manifest = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop
        $manifest | Should -Not -BeNullOrEmpty

        $rawManifest = Import-PowerShellDataFile -Path $manifestPath
        $rawManifest.FunctionsToExport | Should -Not -Contain '*'
    }

    It 'has no Error or Warning findings' {
        $analyzerParams = @{
            Path     = $repoRoot
            Recurse  = $true
            Severity = @('Error', 'Warning')
        }
        if (Test-Path -LiteralPath $settingsPath -PathType Leaf) {
            $analyzerParams['Settings'] = $settingsPath
        }

        $findings = @(Invoke-ScriptAnalyzer @analyzerParams)
        $details = ($findings | ForEach-Object {
            "$($_.ScriptName):$($_.Line) [$($_.RuleName)] $($_.Message)"
        }) -join [Environment]::NewLine
        $findings | Should -BeNullOrEmpty -Because $details
    }
}
```

## References

- [Microsoft: PSScriptAnalyzer module](https://learn.microsoft.com/en-us/powershell/module/psscriptanalyzer/)
- [Microsoft: Using PSScriptAnalyzer](https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/using-scriptanalyzer?view=ps-modules)
- [PSScriptAnalyzer repository and rule documentation](https://github.com/PowerShell/PSScriptAnalyzer)
- [PowerShell compatibility rules](https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/using-scriptanalyzer?view=ps-modules#check-powershell-version-compatibility)
