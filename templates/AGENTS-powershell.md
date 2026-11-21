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

CI runs the guide checker (PSScriptAnalyzer plus supplemental checks) through the reusable workflow `scufflegrits/powershellai/.github/workflows/powershell-guide-check.yml@v1.1.0`. Local checks require PowerShell 7 and PSScriptAnalyzer 1.24.0, plus Pester 5.7.1 when CI runs tests. Install missing modules only through an approved setup process; the [repository README](https://github.com/scufflegrits/powershellai/blob/v1.1.0/README.md) has the pinned install commands.

Run the following in PowerShell from the consuming repository's root. It downloads the checker from the same release as CI into a temporary directory outside the repository, so the checker does not analyze its own downloaded copy. Keep `$guideVersion`, the workflow reference, and the guide links on the same release when upgrading.

```powershell
$guideVersion = 'v1.1.0'
$guideTools = Join-Path ([System.IO.Path]::GetTempPath()) "powershellai-$guideVersion"
$null = New-Item -ItemType Directory -Path $guideTools -Force -ErrorAction Stop
$guideChecker = Join-Path $guideTools 'Invoke-PowerShellGuideCheck.ps1'
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/scufflegrits/powershellai/$guideVersion/Invoke-PowerShellGuideCheck.ps1" -OutFile $guideChecker -ErrorAction Stop

pwsh -NoProfile -NonInteractive -Command {
    param($checker)
    Import-Module PSScriptAnalyzer -RequiredVersion 1.24.0 -ErrorAction Stop
    & $checker -Path .
    exit $LASTEXITCODE
} -args $guideChecker
if ($LASTEXITCODE -ne 0) {
    throw 'PowerShell guide checks failed.'
}
```

The checker discovers the nearest `PSScriptAnalyzerSettings.psd1`, stopping at the repository root, just as CI does. If CI overrides `path`, `settings`, or `severity`, pass matching `-Path`, `-Settings`, or `-Severity` arguments to the checker above. Informational findings require `-Severity Error,Warning,Information`; the default is `Error,Warning`.

If CI runs Pester, run this next, using the same test path as its `pester-path` input. Omit it when CI skips Pester. The child process returns a failing exit code when tests fail, matching CI.

```powershell
pwsh -NoProfile -NonInteractive -Command {
    Import-Module Pester -RequiredVersion 5.7.1 -ErrorAction Stop
    $configuration = New-PesterConfiguration
    $configuration.Run.Path = './Tests'
    $configuration.Run.Exit = $true
    $configuration.Output.Verbosity = 'Detailed'
    Invoke-Pester -Configuration $configuration
}
if ($LASTEXITCODE -ne 0) {
    throw 'Pester tests failed.'
}
```

Never report a check as passing unless you ran it.
