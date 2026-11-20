# PowerShell Engineering Guides

This repository contains practical PowerShell standards, focused testing and static-analysis guides, and a script that checks a mechanically verifiable subset of those recommendations.

## Guides and tools

- [PowerShell Best Practices r1.0.7](powershell-best-practices-r1.0.7.md) — scripting, modules, security, testing, documentation, and AI-agent practices.
- [Pester testing guide](powershell-pester-testing-r1.0.0.md) — Pester v5 test design, mocks, discovery, TestDrive, coverage, and CI.
- [PSScriptAnalyzer guide](powershell-psscriptanalyzer-r1.0.0.md) — analyzer configuration, compatibility checks, formatting, suppressions, and CI.
- [Guide check script](Invoke-PowerShellGuideCheck.ps1) — runs PSScriptAnalyzer and supplemental AST checks.
- [Combined testing and analysis index](powershell-testing-pester-psscriptanalyzer-r1.0.7.md) — links to the two focused guides.

## Run the guide checks

Requirements: PowerShell 7+ and PSScriptAnalyzer installed through the environment's approved setup process.

```powershell
./Invoke-PowerShellGuideCheck.ps1 -Path .
```

If present, `PSScriptAnalyzerSettings.psd1` in the current directory is used automatically. Findings are a static aid; use Pester and review semantic requirements such as threat-model fit, test quality, and complete side-effect coverage.

## Run the guide-check tests

Requirements: PowerShell 7+, Pester 5, and PSScriptAnalyzer.

```powershell
Invoke-Pester -Path ./Tests -Output Detailed
```

Older guide revisions are kept in [`99_Archive/`](99_Archive/).
