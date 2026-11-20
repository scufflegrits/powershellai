# PowerShell Engineering Guides and Tools

This repository provides practical standards for writing, reviewing, testing, and maintaining PowerShell scripts and modules. It includes focused guides, reusable AI prompts, and a checker for a mechanically verifiable subset of the recommendations.

## Start here

1. Read [PowerShell Best Practices r1.0.7](powershell-best-practices-r1.0.7.md).
2. Use the [Pester testing guide](powershell-pester-testing-r1.0.0.md) and [PSScriptAnalyzer guide](powershell-psscriptanalyzer-r1.0.0.md) for verification practices.
3. For AI-assisted work, combine [shared prompt instructions](prompt-common.md) with either the [script review prompt](prompt-review.md) or [script creation prompt](prompt-create.md).
4. Run the guide checker and Pester tests using the commands below.

## Guides and tools

- [PowerShell Best Practices r1.0.7](powershell-best-practices-r1.0.7.md) — scripting, modules, security, testing, documentation, and AI-agent practices.
- [Pester testing guide](powershell-pester-testing-r1.0.0.md) — Pester v5 test design, mocks, discovery, TestDrive, coverage, and CI.
- [PSScriptAnalyzer guide](powershell-psscriptanalyzer-r1.0.0.md) — analyzer configuration, compatibility checks, formatting, suppressions, and CI.
- [Guide check script](Invoke-PowerShellGuideCheck.ps1) — runs PSScriptAnalyzer and supplemental AST checks.
- [Shared AI prompt](prompt-common.md) — agent coordination, safety, verification, Mermaid diagrams, and reporting.
- [AI script review prompt](prompt-review.md) — review an existing script, typically supplied under `input/`.
- [AI script creation prompt](prompt-create.md) — design and create a script from requirements.
- [Combined testing and analysis index](powershell-testing-pester-psscriptanalyzer-r1.0.7.md) — links to the two focused guides.

## Requirements

- PowerShell 7 or later.
- PSScriptAnalyzer for static analysis and the guide checker.
- Pester 5 for the repository's Pester tests.

Install tools only through the setup method approved for your environment. The checker does not install modules.

## Run static checks

From the repository root, run:

```powershell
./Invoke-PowerShellGuideCheck.ps1 -Path .
```

The checker uses `PSScriptAnalyzerSettings.psd1` when it exists in the current directory. It exits nonzero for errors and warnings; informational findings require review. Static checks cannot determine whether a design fits its threat model or fully verifies runtime behavior.

## Run tests

From the repository root:

```powershell
Invoke-Pester -Path ./Tests -Output Detailed
```

The tests invoke the checker in a child `pwsh` process and require PSScriptAnalyzer to be available to that process.

## Repository layout

- `input/` — place scripts here when using the review prompt.
- `Tests/` — Pester tests for the guide checker.
- `99_Archive/` — older guide revisions retained for reference.
- `PSScriptAnalyzerSettings.psd1` — shared static-analysis settings.
- `CHANGELOG.md` — notable guide and tool changes.

The prompts are templates; fill in task requirements and constraints before use. The review prompt should not modify a script unless the requested task authorizes updates.
