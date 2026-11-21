# Worked review: count log files safely

This example follows one small script from a review request to a verified correction.
Both versions only read directory entries; the tests create their sample files in
Pester's temporary `$TestDrive`. No credentials or services are needed.

## 1. Define the task

The script must accept one existing directory and return one object with `Path`
(the path as supplied) and `LogCount`. It must count only `*.log` files directly
inside that directory, ignore directories and nested files, treat brackets in
paths literally, and stop with an error for a missing path or a file path.

Use [prompt-common.md](../../prompt-common.md) together with
[prompt-review.md](../../prompt-review.md). Fill the review prompt with:

> Review `examples/worked-review/before/Get-LogSummary.ps1` against the PowerShell
> guides. Use the requirements above as acceptance criteria. Target PowerShell 7
> on Linux and Windows. Report findings with evidence before making changes.
> Keep the `Path` and `LogCount` output properties. If corrections are authorized,
> save the corrected version separately and verify it with Pester and the guide checker.

The small-task workflow applies: one review and a separate verification pass.
The checked-in correction shows what an authorized update produces.

## 2. Review the original

Read [the original script](before/Get-LogSummary.ps1). Its key operation is:

```powershell
$logs = @(Get-ChildItem -Path $Path -Filter '*.log')
```

The findings are behavioral defects, not formatting preferences:

| Severity | Finding and evidence | Correction |
|---|---|---|
| Warning | Without `-File`, a directory named `archive.log` is counted as a log file. One log file plus that directory produces `2`. | Restrict enumeration to files. |
| Warning | `-Path` interprets brackets as wildcard syntax. A directory named `logs [sample]` containing one log can produce a count of `0`. | Use `-LiteralPath`. |
| Warning | A missing directory produces a non-terminating error under normal error preferences, then the script still returns a summary. | Make failures terminating. |
| Warning | A file path is accepted even though the input contract requires a directory. | Validate that the resolved item is a directory. |

Both versions pass the repository's default static checks. That result does not
prove the original satisfies its requirements: these defects need behavior tests.

## 3. Compare the correction

Read [the corrected script](after/Get-LogSummary.ps1). It resolves the input with
`Get-Item -LiteralPath`, rejects non-directory items, and enumerates with
`Get-ChildItem -LiteralPath ... -File -ErrorAction Stop`. It preserves the two
output properties and does not recurse. `@(...)` keeps counting consistent for
zero, one, or several files.

There is no `ShouldProcess` / `-WhatIf` support because this script does not modify
state. No diagram is needed for this short sequence of operations.

## 4. Run the checks

Use PowerShell 7 with PSScriptAnalyzer 1.24.0 and Pester 5.7.1 installed through
the [documented setup process](../../README.md#requirements). Run these commands
from the repository root.

First, run the static checks on both scripts and the tests:

```powershell
./Invoke-PowerShellGuideCheck.ps1 -Path ./examples/worked-review
```

Expected: no findings, exit code `0`.

Next, run the same eight tests against the original:

```powershell
Import-Module Pester -RequiredVersion 5.7.1 -ErrorAction Stop
$testPath = './examples/worked-review/Tests/Get-LogSummary.Tests.ps1'
$beforePath = (Resolve-Path -LiteralPath './examples/worked-review/before/Get-LogSummary.ps1').Path
$container = New-PesterContainer -Path $testPath -Data @{ ScriptPath = $beforePath }
Invoke-Pester -Container $container -Output Detailed
```

Expected with normal PowerShell error preferences: **4 passed, 4 failed**. These
failures reproduce the four findings. They are intentional for the original.

Finally, run the tests without an override; they select the corrected script:

```powershell
Invoke-Pester -Path ./examples/worked-review/Tests -Output Detailed
```

Expected: **8 passed, 0 failed**. The tests cover empty, single-file, and multiple-file
directories; unrelated and nested files; directories ending in `.log`; literal
paths; and invalid inputs. Read [the tests](Tests/Get-LogSummary.Tests.ps1) to see
the assertions. CI discovers these tests and checks the corrected script on Ubuntu
and Windows; it does not intentionally run the failing original test configuration.

The tests do not simulate permission failures or concurrent filesystem changes.
Passing them demonstrates the listed cases, not every possible operating condition.
