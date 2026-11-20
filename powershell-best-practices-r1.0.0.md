# PowerShell Best Practices

**Guide version:** 1.0.0  
**Applies to:** PowerShell 7+ unless a project explicitly targets Windows PowerShell 5.1.  
**Purpose:** A practical standard for writing safe, readable, maintainable PowerShell and for AI agents contributing to PowerShell projects.

## Table of contents

1. [Principles](#principles)
2. [Repository and version awareness](#repository-and-version-awareness)
3. [Style and maintainability](#style-and-maintainability)
4. [Functions, parameters, and output](#functions-parameters-and-output)
5. [Errors and cleanup](#errors-and-cleanup)
6. [Security and safe operations](#security-and-safe-operations)
7. [Files, paths, and native commands](#files-paths-and-native-commands)
8. [Testing and quality](#testing-and-quality)
9. [Documentation and delivery](#documentation-and-delivery)
10. [PowerShell script header template](#powershell-script-header-template)
11. [Rules for AI agents](#rules-for-ai-agents)
12. [Quick checklist](#quick-checklist)

## Principles

- Prefer clear, predictable code over clever or compressed code.
- Make side effects visible. A function that changes the system should communicate that in its name, help, and output.
- Choose safe defaults, least privilege, and repeatable behavior.
- Preserve useful errors and context; do not silently continue after a failure that matters.
- Follow the conventions and compatibility requirements of the repository being changed.

## Repository and version awareness

- Check the repository's `AGENTS.md`, README, contribution guide, CI configuration, module manifest, and nearby code before editing.
- Determine the supported PowerShell version and operating systems from project configuration and documentation. Do not assume PowerShell 7 features are available to Windows PowerShell 5.1.
- Match established formatting, naming, and module patterns unless they conflict with safety or correctness.
- Keep a change focused on the requested behavior. Avoid unrelated cleanup and dependency changes.

## Style and maintainability

- Use descriptive names and approved PowerShell verbs for public functions (`Get-Thing`, `Set-Thing`, `Test-Thing`).
- Use consistent indentation and formatting; use the repository's formatter or `.editorconfig` when present.
- Keep functions focused. Extract repeated logic when it improves clarity, not simply to reduce line count.
- Keep a function small enough to understand in one pass, with no fixed line-count limit. Split it when it mixes responsibilities, has deeply nested logic, or is difficult to test as one unit. Avoid extracting tiny helpers when that makes the flow harder to follow.
- Use comments to explain intent, constraints, or non-obvious decisions. Do not narrate straightforward syntax.
- Write comments and help in plain language for the people who will use or maintain the code. Explain why a choice was made, important assumptions, side effects, and limitations; avoid restating what the code already says.
- Keep comments close to the code they explain and revise or remove them when behavior changes. Stale comments are worse than no comments.
- Prefer the call operator (`&`) with an executable path and argument array over constructing command text.
- Avoid aliases in scripts and modules (`%`, `?`, `ls`, `gc`); use full cmdlet names for readability and portability.
- Avoid global state and unnecessary profile dependencies. Scripts should work in a clean session.

## Functions, parameters, and output

- Use `[CmdletBinding()]` and a `param()` block for reusable functions and scripts with inputs.
- Declare useful parameter types and validation (`[ValidateSet()]`, `[ValidateRange()]`, `[ValidateNotNullOrEmpty()]`) at the boundary.
- Use parameter names that explain meaning. Add `Mandatory`, pipeline binding, and aliases only when the interface benefits from them.
- Return objects, not formatted display strings, from reusable functions. Reserve `Format-Table` and `Format-List` for the presentation layer.
- Keep success output intentional. Do not let incidental assignments, progress text, or debug messages become function results.
- Use `$null -eq $value` and `$null -ne $value` so comparison behavior is unambiguous.
- Use `Write-Verbose` for optional diagnostic detail, `Write-Warning` for recoverable concerns, and errors for failed operations.

## Errors and cleanup

- Know whether a command emits a non-terminating error or throws. Use `-ErrorAction Stop` when a `try`/`catch` must handle a cmdlet failure.
- Catch only errors you can meaningfully handle. Preserve the original exception and add context when rethrowing.
- Do not use empty `catch` blocks or broad suppression such as `SilentlyContinue` to hide failures.
- Use `finally` or `try`/`finally` to release resources and perform required cleanup, including when an operation fails.
- Validate preconditions early and provide actionable error messages that identify the operation and relevant input without exposing secrets.
- For native executables, inspect `$LASTEXITCODE`; PowerShell error preferences alone do not reliably indicate a native command's success.

## Security and safe operations

- Apply least privilege. Do not request elevation or broaden permissions unless the task requires it.
- Never commit, print, or log passwords, tokens, private keys, or other secrets. Use an approved secret store or secure credential mechanism.
- Treat user input, environment variables, filenames, and external command output as untrusted.
- Avoid `Invoke-Expression`. Do not build executable command strings from input; pass arguments as data.
- Quote and validate paths and external inputs. Be especially careful with wildcard expansion, relative paths, and paths supplied by another user or process.
- Before deleting, overwriting, changing permissions, installing software, or affecting remote systems, inspect the target and use a preview or confirmation mechanism where available.
- Prefer idempotent operations where practical: repeating a command should not create duplicate or unintended changes.
- Do not weaken execution policy, certificate checks, or security controls as a shortcut to make a command succeed.

## Files, paths, and native commands

- Use `Join-Path` and platform-aware APIs rather than hand-concatenating path separators.
- Specify text encoding when reading or writing files if compatibility matters; do not rely on environment-dependent defaults.
- Use `-LiteralPath` when a path must be treated literally rather than as a wildcard pattern.
- Check whether a destination exists and define overwrite behavior explicitly.
- Invoke native tools with an explicit executable and argument list. Handle spaces and special characters as arguments, not as command syntax.
- Capture and check native exit codes. If output is part of a data pipeline, account for native stdout and stderr behavior on the target PowerShell version.

## Testing and quality

- Use **Pester** for automated behavior tests, including unit and integration tests, mocking dependencies, and optional code coverage. Follow the repository's Pester version and configuration; test files commonly use the `*.Tests.ps1` naming pattern.
- Use **PSScriptAnalyzer** for static analysis of scripts and modules. Run the repository's configured rules and suppress a finding only when there is a clear, documented reason. Use `Invoke-Formatter` when formatting is part of the project's workflow.
- Use both tools together: Pester checks observed behavior, while PSScriptAnalyzer flags code quality and selected compatibility issues. Neither replaces running code in its supported PowerShell environments.
- See [PowerShell testing with Pester and PSScriptAnalyzer](powershell-testing-pester-psscriptanalyzer-r1.0.0.md) for setup, example commands, and practical workflows.
- Add or update focused tests for changed behavior when the task calls for tests or project practice requires them.
- Prefer isolated temporary directories and test doubles over changes to real services, user profiles, or production data.
- Exercise error paths and boundary inputs, not only the successful case.
- Run only checks that are relevant and available. Report exactly what ran and whether it passed; do not imply an unrun check succeeded.
- Do not install tools or dependencies implicitly. Follow project setup instructions and disclose when a check could not run.

## Documentation and delivery

- Add comment-based help to public scripts and functions when users need usage guidance: synopsis, description, parameters, examples, and notes as appropriate.
- Keep examples safe to copy. Mark destructive or environment-specific examples clearly and show required parameters.
- Document prerequisites, supported versions, side effects, and important limitations.
- Summarize behavior changes and compatibility impact in the project's expected changelog or release notes when applicable.
- In a handoff, state what changed, which checks ran, their results, and any known limitation.

## PowerShell script header template

Add a comment-based help header to scripts intended for reuse, distribution, or scheduled operation. Keep the metadata factual and update it when the script's behavior or interface changes. Omit fields that do not apply rather than leaving placeholders in a committed script.

```powershell
<#
.SYNOPSIS
    Short description of the script's main task.

.DESCRIPTION
    Explain what the script does, its important behavior, and any side effects.

.PARAMETER InputPath
    Describe the input and any constraints.

.PARAMETER WhatIf
    Describe preview behavior, if the script supports it.

.EXAMPLE
    .\Get-Report.ps1 -InputPath .\data.json
    Runs the report against the specified input.

.NOTES
    Name:        Get-Report.ps1
    Version:     1.0.0
    Purpose:     Generate a report from the supplied data.
    Author:      Team or maintainer
    Created:     YYYY-MM-DD
    Updated:     YYYY-MM-DD
    Requirements: PowerShell 7.0+
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $InputPath
)
```

The template is illustrative: document only parameters and capabilities the script actually implements. Include `.PARAMETER` entries for real parameters, examples that can be run safely, and the minimum supported PowerShell version when known. `SupportsShouldProcess` adds `-WhatIf` and `-Confirm`; use it only when the script's changes are implemented through `$PSCmdlet.ShouldProcess()` checks.

### Function help template

Put comment-based help immediately before a function's `param()` block. Document the public contract: what the function does, parameter meaning and constraints, output type, errors callers may need to handle, and safe examples. Internal helpers can use shorter help when their purpose is clear from the name and surrounding code.

```powershell
function Get-Report {
    <#
    .SYNOPSIS
        Gets a report for the supplied input.

    .DESCRIPTION
        Reads the input file and returns report records as PowerShell objects.
        It does not modify the input file.

    .PARAMETER InputPath
        Path to an existing input file.

    .OUTPUTS
        System.Management.Automation.PSCustomObject

    .EXAMPLE
        Get-Report -InputPath './data.json'
        Returns report records from the specified file.

    .NOTES
        Requires PowerShell 7.0 or later.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $InputPath
    )

    # Implementation goes here.
}
```

### Plain-language comments

- Use everyday wording and define specialized terms when readers may not know them.
- Describe the reason for a non-obvious choice or constraint. For example: `# Keep the original order because downstream reports use it.`
- Call out meaningful side effects, assumptions, workarounds, and security-sensitive behavior.
- Put usage guidance in comment-based help; use inline comments for local reasoning that would not fit naturally in the help.
- Avoid comments such as `# Increment counter` immediately above `$count++`. Prefer a clearer name or code when that removes the need for narration.
- Be specific and factual. Avoid vague notes such as `# Handle stuff` or TODOs without enough context to act on.
- Never put secrets or sensitive personal data in comments, examples, or help text.

## Rules for AI agents

AI agents working in a PowerShell repository should follow this sequence:

1. **Inspect first.** Read applicable agent instructions and project docs. Identify the target PowerShell version, operating systems, test commands, and local conventions.
2. **Understand the requested outcome.** Trace the relevant code path and callers before changing an interface or behavior. Ask for clarification only when a material requirement cannot be inferred.
3. **Plan a small change.** State the files and behavior likely to change. Keep the implementation scoped; do not refactor unrelated code.
4. **Edit safely.** Preserve user changes. Do not overwrite unrelated work, expose secrets, or run commands with external side effects unless they are necessary and authorized.
5. **Review the diff.** Look for accidental formatting churn, generated files, credentials, unsafe command construction, and compatibility issues.
6. **Verify proportionately.** Run the relevant existing checks when requested or appropriate. Never claim a test, lint, or runtime check passed unless it actually ran and passed.
7. **Report precisely.** Summarize the change, files affected, checks performed and outcomes, and any remaining limitation. Distinguish verified facts from assumptions.

Agent-specific coding rules:

- Prefer a minimal, understandable patch over speculative abstractions or broad rewrites.
- Follow repository guidance even when it differs from this general guide, unless doing so would create a clear security or correctness problem; explain any necessary deviation.
- Do not silently alter public parameter names, output types, exit behavior, or compatibility targets.
- Do not suppress errors merely to make automation appear successful.
- Treat commands that delete, overwrite, change permissions, install packages, or contact remote systems as consequential. Inspect their targets and expected effects before execution.
- Never invent test results, tool output, or repository facts. Say when verification was not performed.

## Quick checklist

- [ ] I checked project instructions, conventions, and supported PowerShell versions.
- [ ] Inputs are validated and outputs are intentional objects or documented results.
- [ ] Errors remain visible and carry useful context.
- [ ] Paths, external arguments, and secrets are handled safely.
- [ ] Consequential operations have explicit targets and expected effects.
- [ ] The patch is focused and does not overwrite unrelated changes.
- [ ] Relevant checks and their actual outcomes are reported accurately.
