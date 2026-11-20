<!--
Copy the section below into the consuming repository's AGENTS.md (or CLAUDE.md),
then replace v1.1.0 with the release you want to pin. Delete this comment.
-->

## PowerShell standards

PowerShell code in this repository follows the PowerShell engineering guides, pinned to release `v1.1.0`:

- [PowerShell Best Practices](https://github.com/scufflegrits/powershellai/blob/v1.1.0/powershell-best-practices.md): the main standard. AI agents must follow **§13 Rules for AI agents**.
- [Pester testing guide](https://github.com/scufflegrits/powershellai/blob/v1.1.0/powershell-pester-testing.md)
- [PSScriptAnalyzer guide](https://github.com/scufflegrits/powershellai/blob/v1.1.0/powershell-psscriptanalyzer.md)

Read the best-practices guide before writing or reviewing PowerShell here. Where this repository's own documented conventions differ from the guide, follow this repository and note the deviation.

### Checks

CI runs the guide checker (PSScriptAnalyzer plus supplemental checks) through the reusable workflow `scufflegrits/powershellai/.github/workflows/powershell-guide-check.yml@v1.1.0`. To run the same checks locally, use PSScriptAnalyzer 1.24.0 and Pester 5.7.1:

```powershell
Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./PSScriptAnalyzerSettings.psd1
Invoke-Pester -Path ./Tests -Output Detailed
```

Omit `-Settings` if this repository has no settings file. The supplemental checks need [`Invoke-PowerShellGuideCheck.ps1`](https://github.com/scufflegrits/powershellai/blob/v1.1.0/Invoke-PowerShellGuideCheck.ps1) from the same release; CI runs it automatically. Do not install tools without approval, and never report a check as passing unless you ran it.
