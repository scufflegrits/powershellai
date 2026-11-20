# PowerShell Testing with Pester and PSScriptAnalyzer

**Guide version:** 1.0.0  
**Purpose:** A practical guide to checking PowerShell behavior with Pester and checking PowerShell code quality with PSScriptAnalyzer.

## Table of contents

1. [How the tools fit together](#how-the-tools-fit-together)
2. [Check the project first](#check-the-project-first)
3. [Pester](#pester)
4. [PSScriptAnalyzer](#psscriptanalyzer)
5. [A repeatable workflow](#a-repeatable-workflow)
6. [Using the tools in CI](#using-the-tools-in-ci)
7. [Common mistakes](#common-mistakes)
8. [References](#references)

## How the tools fit together

Pester executes tests to check behavior. It supports assertions, mocks, and test result and coverage output. PSScriptAnalyzer inspects PowerShell source against static analysis rules and can format code. Static analysis cannot prove runtime behavior, and tests cannot guarantee that every quality or compatibility issue has been found. Use the tools together, then run the code in the PowerShell versions and operating systems the project supports.

## Check the project first

Before installing or running tools:

- Read repository instructions and existing test or CI configuration.
- Check the supported PowerShell editions and versions (`$PSVersionTable`). Pester and analyzer versions have their own requirements; select versions compatible with the project.
- Use the version already pinned or required by the project. Avoid changing dependencies simply to match the latest release.
- Prefer an isolated development environment and avoid changing machine-wide modules unless the project directs you to.

Check what is available in the current session:

```powershell
$PSVersionTable.PSVersion
Get-Module -ListAvailable Pester, PSScriptAnalyzer |
    Select-Object Name, Version, Path
```

Install only if needed and authorized by the project's setup process. For example, a current-user install with PowerShellGet is:

```powershell
Install-Module -Name Pester -Scope CurrentUser
Install-Module -Name PSScriptAnalyzer -Scope CurrentUser
```

Follow the tools' official installation instructions if the project uses PSResourceGet or another package-management workflow.

## Pester

Pester is a test framework for PowerShell. Tests are typically stored in `*.Tests.ps1` files and use `Describe`, `Context`, and `It` blocks with assertions. Mocks can isolate a unit from external commands or services.

### Example test

Given this function in `Get-Greeting.ps1`:

```powershell
function Get-Greeting {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name
    )

    "Hello, $Name!"
}
```

Create `Get-Greeting.Tests.ps1`:

```powershell
BeforeAll {
    . "$PSScriptRoot/Get-Greeting.ps1"
}

Describe 'Get-Greeting' {
    It 'greets the supplied name' {
        Get-Greeting -Name 'Ada' | Should -Be 'Hello, Ada!'
    }

    It 'rejects an empty name' {
        { Get-Greeting -Name '' } | Should -Throw
    }
}
```

Pester syntax can differ across major versions. Use the assertion syntax supported by the project's pinned version and consult its matching documentation.

### Run tests

Run the repository's configured command when available. For an ad hoc run:

```powershell
Invoke-Pester
```

To run a particular test file:

```powershell
Invoke-Pester -Path ./tests/Get-Greeting.Tests.ps1
```

Pester 6 supports configuration objects and can emit CI-friendly output. For example, check the installed version's documentation before using version-specific parameters or result formats.

### Test design guidance

- Test observable outcomes and important edge cases, not private implementation details that may change without changing behavior.
- Keep unit tests isolated and deterministic. Mock external commands, network calls, clocks, and other dependencies where appropriate.
- Use temporary directories for file tests and clean them up even when assertions fail.
- Keep integration tests clearly identified; they may require credentials, services, network access, or a particular environment.
- Treat coverage as a signal for untested code paths, not proof of correctness.
- Avoid making tests destructive or dependent on a developer's personal profile or machine state.

## PSScriptAnalyzer

PSScriptAnalyzer is a static code checker for PowerShell scripts and modules. `Invoke-ScriptAnalyzer` reports rule findings; `Get-ScriptAnalyzerRule` lists available rules; `Invoke-Formatter` formats source according to settings. Rules and output can vary by analyzer version and configuration.

### Analyze a file or module

```powershell
Invoke-ScriptAnalyzer -Path ./src/Get-Greeting.ps1
Invoke-ScriptAnalyzer -Path ./src/MyModule
```

Run it against the project scope used by the repository, not just the file changed. For CI, make analyzer findings fail the job according to the project's severity policy and analyzer version.

### Select rules and formatting

Prefer a checked-in settings file so local and CI runs use the same rules. Example `PSScriptAnalyzerSettings.psd1`:

```powershell
@{
    Severity = @('Error', 'Warning')
    Rules    = @{
        PSUseApprovedVerbs = @{
            Enable = $true
        }
    }
}
```

Then use it consistently:

```powershell
Invoke-ScriptAnalyzer -Path ./src -Settings ./PSScriptAnalyzerSettings.psd1
```

Formatting should be reviewed like any other source change. Preview or capture formatter output before replacing files, and inspect the diff to avoid unrelated churn. Example for one file:

```powershell
$path = './src/Get-Greeting.ps1'
$source = Get-Content -LiteralPath $path -Raw
$formatted = Invoke-Formatter -ScriptDefinition $source
$formatted
```

To save formatter output, use the repository's expected encoding and newline conventions, then review the resulting diff.

### Handle findings

- Fix valid findings at the source where practical.
- Review whether a rule applies to the project's compatibility target and conventions.
- Use a narrow, documented suppression only when a finding is a deliberate exception. Do not suppress a rule broadly just to get a clean run.
- Keep settings and suppressions under version control so CI and contributors agree.

## A repeatable workflow

1. Read the project instructions and identify the pinned tool versions and commands.
2. Run the focused Pester tests before or after the change to understand behavior and catch regressions.
3. Run PSScriptAnalyzer with the project's settings over the affected scope.
4. Fix meaningful failures and rerun the relevant commands.
5. Run the wider test suite and supported PowerShell environments when the change warrants it.
6. Review the diff, including formatter changes, test fixtures, and generated result files.
7. Report commands run and outcomes accurately. State when a tool or environment was unavailable.

Example local sequence (replace paths with the repository's actual layout):

```powershell
Invoke-Pester -Path ./tests
Invoke-ScriptAnalyzer -Path ./src -Settings ./PSScriptAnalyzerSettings.psd1
```

## Using the tools in CI

- Pin tool versions or use the versions declared by the repository so results do not unexpectedly shift.
- Run Pester and PSScriptAnalyzer in separate, clearly named CI steps for understandable failures.
- Fail the build on test failures and on analyzer findings according to an explicit severity policy.
- Publish test results and coverage only when configured; avoid committing generated reports unless the project requires them.
- Test on each supported PowerShell edition and operating system when cross-platform compatibility is part of the contract.
- Keep credentials out of test output and use protected CI secrets only for integration tests that need them.

## Common mistakes

- Assuming Pester syntax or parameters are identical across major versions.
- Treating a passing analyzer run as proof that a script works.
- Treating passing tests or high coverage as proof that behavior is safe in production.
- Using mocks so extensively that tests no longer verify meaningful behavior.
- Relying on current directory, personal profile, network availability, or machine-specific state without making those requirements explicit.
- Running a formatter over the whole repository without reviewing the diff.
- Suppressing analyzer findings without explaining why the exception is safe.

## References

- [Pester Quick Start](https://pester.dev/docs/quick-start/)
- [Pester installation and compatibility](https://pester.dev/docs/introduction/installation)
- [Pester `Invoke-Pester` command](https://pester.dev/docs/commands/invoke-pester/)
- [Microsoft: PSScriptAnalyzer module](https://learn.microsoft.com/en-us/powershell/module/psscriptanalyzer/)
- [Microsoft: Using PSScriptAnalyzer](https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/using-scriptanalyzer?view=ps-modules)
