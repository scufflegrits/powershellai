# PowerShell Best Practices

**Guide version:** 1.0.1  
**Applies to:** PowerShell 7+ (cross-platform) unless a project explicitly targets Windows PowerShell 5.1.  
**Purpose:** A comprehensive, practical engineering standard for writing safe, readable, maintainable, and testable PowerShell scripts and modules, and for AI agents contributing to PowerShell repositories.

---

## Table of contents

1. [Principles](#1-principles)
2. [Repository, environment, and version awareness](#2-repository-environment-and-version-awareness)
3. [Style, formatting, and maintainability](#3-style-formatting-and-maintainability)
4. [Functions, parameters, and pipeline design](#4-functions-parameters-and-pipeline-design)
5. [Data structures, collections, and performance](#5-data-structures-collections-and-performance)
6. [Errors, logging, and resource cleanup](#6-errors-logging-and-resource-cleanup)
7. [Security and safe operations](#7-security-and-safe-operations)
8. [Files, paths, encoding, and native commands](#8-files-paths-encoding-and-native-commands)
9. [Modules, manifests, and project layout](#9-modules-manifests-and-project-layout)
10. [Testing and static analysis](#10-testing-and-static-analysis)
11. [Documentation and delivery](#11-documentation-and-delivery)
12. [Templates](#12-templates)
13. [Rules for AI agents](#13-rules-for-ai-agents)
14. [Quick checklist](#14-quick-checklist)

---

## 1. Principles

- **Clarity over cleverness:** Prefer explicit, readable, predictable code over compressed one-liners, obscure automatic variables, or golfed syntax.
- **Visible side effects:** Any function or script that modifies state (files, registry, network, services, cloud resources) must communicate that through approved verbs (`Set-`, `Remove-`, `New-`, `Update-`), comment-based help, verbose output, and `ShouldProcess` (`-WhatIf`/`-Confirm`) support.
- **Safe defaults & least privilege:** Require explicit opt-in for destructive actions, bind to narrow scopes, and request elevation only when strictly required.
- **Fail loudly with context:** Never swallow errors silently. Preserve original exceptions and attach actionable context (operation, target, relevant non-secret identifiers).
- **Idempotency:** Design state-changing operations so running them repeatedly converges on the desired state without duplicating artifacts or failing unnecessarily.
- **Repository conformity:** Honor the conventions, formatting rules, and compatibility targets of the existing codebase.

---

## 2. Repository, environment, and version awareness

- **Inspect project metadata first:** Check `AGENTS.md`, `README.md`, `CONTRIBUTING.md`, `.editorconfig`, `PSScriptAnalyzerSettings.psd1`, CI workflows (`.github/workflows/`, Azure Pipelines), and module manifests (`*.psd1`) before making edits.
- **Declare runtime requirements explicitly:** Use `#Requires` statements at the top of scripts to enforce minimum PowerShell editions/versions, required modules, or elevation rather than failing mid-execution:
  ```powershell
  #Requires -Version 7.2
  #Requires -Modules @{ ModuleName = 'Microsoft.PowerShell.SecretManagement'; ModuleVersion = '1.1.0' }
  ```
- **Respect PowerShell 5.1 vs. PowerShell 7+ differences:** Do not assume PowerShell 7+ syntax or cmdlet behavior works in Windows PowerShell 5.1 (`powershell.exe`). Key differences to account for when targeting dual compatibility:
  - **Operators:** Ternary (`$a ? $b : $c`), null-coalescing (`$a ?? $b`), null-conditional (`${a}?.Prop`), and pipeline chain operators (`&&`, `||`) are **PowerShell 7+ only**.
  - **Platform variables:** `$IsWindows`, `$IsLinux`, and `$IsMacOS` exist automatically in PowerShell 7+, but are undefined (`$null`) in Windows PowerShell 5.1. If supporting 5.1, check `$PSVersionTable.PSEdition -eq 'Desktop'` or `[System.Runtime.InteropServices.RuntimeInformation]`.
  - **Default encoding:** PowerShell 7+ defaults to UTF-8 without BOM across file cmdlets; Windows PowerShell 5.1 varies (`UTF-16LE` for `Out-File`/`>`, Windows-1252 for `Set-Content`). Always specify `-Encoding` explicitly.
  - **`ConvertFrom-Json`:** Defaults to `-Depth 2` in PS 5.1 (truncating nested objects) and `-Depth 1024` in PS 7+. Always pass `-Depth` explicitly when targeting PS 5.1.
- **Keep changes scoped:** Match established naming and layout patterns unless they introduce a bug or security flaw. Avoid unrelated refactoring or dependency upgrades.

---

## 3. Style, formatting, and maintainability

- **Approved verbs and PascalCase:** Name public functions using `Verb-Noun` with approved PowerShell verbs (`Get-Verb`) and singular nouns (`Get-ServiceAccount`, not `Get-ServiceAccounts`). Use `PascalCase` for functions, parameters, and exported variables; use `camelCase` for local variables.
- **No aliases in committed code:** Never use cmdlet or parameter aliases (`%`, `?`, `gci`, `ls`, `gc`, `select`, `where`, `ft`, `-ea`, `-ev`) in scripts, modules, or tests. Full names improve readability, searchability, and cross-platform consistency.
- **Use splatting for multi-parameter calls:** Whenever a command takes more than three parameters or builds arguments conditionally, use a hashtable and splatting (`@params`) instead of long lines or backtick (`` ` ``) line continuations.

  ```powershell
  # Avoid: backtick line continuations (fragile if trailing whitespace is added)
  Get-ChildItem -Path $SourceDir `
      -Filter '*.log' `
      -Recurse `
      -File

  # Prefer: splatting
  $searchParams = @{
      Path    = $SourceDir
      Filter  = '*.log'
      Recurse = $true
      File    = $true
  }
  Get-ChildItem @searchParams
  ```

- **Keep functions cohesive:** A function should do one clear job and be understandable in a single read. Split functions when they mix data retrieval with side effects, exceed two levels of nesting, or require complex setup to unit test. Avoid fragmenting logic into trivial 2-line wrappers that obscure execution flow.
- **Avoid global state and profile assumptions:** Never rely on `$global:` variables, interactive profile functions, or implicit current working directories (`.\`). Scripts must run deterministically in `pwsh -NoProfile`.
- **Consistent formatting:** Follow the repository's `PSScriptAnalyzerSettings.psd1` / `Invoke-Formatter` configuration (commonly OTBS — One True Brace Style, 4-space indentation, spaces around operators).

---

## 4. Functions, parameters, and pipeline design

### Advanced function structure
Always include `[CmdletBinding()]` and a `param()` block on reusable functions and entry-point scripts. This enables common parameters (`-Verbose`, `-Debug`, `-ErrorAction`, `-ErrorVariable`, `-InformationAction`) and strict parameter binding.

### Boundary validation
Validate inputs at the parameter boundary using built-in attributes rather than manual `if` checks inside the function body:
- `[ValidateNotNullOrEmpty()]` / `[ValidateNotNull()]`
- `[ValidateSet('Dev', 'Staging', 'Prod')]`
- `[ValidateRange(1, 65535)]`
- `[ValidatePattern('^[a-z0-9-]+$')]`
- `[ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]` (include an `ErrorMessage` property in PowerShell 7+ for clear user feedback).

### Pipeline support (`begin` / `process` / `end`)
If a function accepts pipeline input (`ValueFromPipeline` or `ValueFromPipelineByPropertyName`), structure it with `begin`, `process`, and `end` blocks so items stream one at a time without buffering the entire collection in memory:

```powershell
function Remove-StaleLog {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName')]
        [ValidateNotNullOrEmpty()]
        [string[]] $Path,

        [Parameter()]
        [ValidateRange(1, 3650)]
        [int] $RetentionDays = 30
    )

    begin {
        $cutoffDate = (Get-Date).AddDays(-$RetentionDays)
    }

    process {
        foreach ($itemPath in $Path) {
            if (-not (Test-Path -LiteralPath $itemPath -PathType Leaf)) {
                Write-Warning "File not found, skipping: $itemPath"
                continue
            }

            $file = Get-Item -LiteralPath $itemPath
            if ($file.LastWriteTime -lt $cutoffDate) {
                if ($PSCmdlet.ShouldProcess($file.FullName, "Delete log file older than $RetentionDays days")) {
                    Remove-Item -LiteralPath $file.FullName -Force
                }
            }
        }
    }
}
```
*Note: Iterating `foreach ($itemPath in $Path)` inside `process` allows the function to work seamlessly whether `$Path` is passed via pipeline (`Get-ChildItem | Remove-StaleLog`) or as a parameter array (`Remove-StaleLog -Path @('a.log', 'b.log')`).*

### Output discipline
- **Emit structured objects, not formatted text:** Return `[PSCustomObject]` or typed classes. Never use `Format-Table`, `Format-List`, or `Out-String` inside reusable functions—formatting destroys object properties and breaks downstream pipelines.
- **Keep the success stream clean:** Everything not captured or redirected in PowerShell falls into the success output stream (`1>`). Watch out for common leaks:
  - `[void]$list.Add($item)` or `$null = $list.Add($item)` (prefer `System.Collections.Generic.List[T]` or direct loop assignment).
  - `New-Item` / `mkdir` emits `DirectoryInfo`/`FileInfo` objects—assign to `$null = New-Item ...` if the caller does not expect them.
- **Use the right output stream:**
  - Success output (`Write-Output` or bare expression): Structured data objects only.
  - Operational status (`Write-Information` / `Write-Host` in PS 5+): User-facing status messages when running interactively.
  - Diagnostics (`Write-Verbose`): Detailed execution trace for troubleshooting (`-Verbose`).
  - Non-fatal anomalies (`Write-Warning`): Recoverable issues that merit operator attention.
- **Null and boolean comparisons:** Always place `$null` on the **left-hand side** of comparisons (`$null -eq $value`, `$null -ne $value`). When `$value` is an array, `$value -eq $null` filters the array for null elements instead of testing whether the variable itself is null.

---

## 5. Data structures, collections, and performance

- **Never use `+=` to build arrays in loops:** PowerShell arrays are fixed-size .NET arrays; `+=` allocates a brand-new array and copies all elements on every iteration ($O(n^2)$).
  ```powershell
  # Avoid: O(n^2) reallocation
  $results = @()
  foreach ($item in $items) {
      $results += Process-Item -InputObject $item
  }

  # Prefer 1: Direct assignment from loop/pipeline (idiomatic and fast)
  $results = foreach ($item in $items) {
      Process-Item -InputObject $item
  }

  # Prefer 2: Generic List when conditionally adding across multiple branches
  $results = [System.Collections.Generic.List[psobject]]::new()
  foreach ($item in $items) {
      if ($item.IsValid) {
          $results.Add((Process-Item -InputObject $item))
      }
  }
  ```
- **Use `[ordered]@{}` for `[PSCustomObject]` creation:**
  ```powershell
  [PSCustomObject]@{
      PSTypeName = 'Contoso.ServiceStatus'
      Name       = $service.Name
      State      = $service.Status
      CheckedAt  = [datetime]::UtcNow
  }
  ```
- **Use `[System.Text.StringBuilder]` for large string concatenation** inside loops rather than repeated `$str += ...`.
- **Prefer `[hashtable]` or `[System.Collections.Generic.HashSet[string]]`** for repeated membership lookups (`$lookup.ContainsKey($id)`) instead of `-contains` / `-in` against large arrays.

---

## 6. Errors, logging, and resource cleanup

- **Distinguish terminating vs. non-terminating errors:**
  - Most cmdlets emit **non-terminating** errors by default, which **will not enter a `catch` block** unless `-ErrorAction Stop` is specified (or `$ErrorActionPreference = 'Stop'` is set).
  - Use `-ErrorAction Stop` on individual commands inside `try` blocks when failure should abort the operation.
- **Catch specific exception types and preserve context:**
  ```powershell
  try {
      $raw = Get-Content -LiteralPath $ConfigPath -Raw -Encoding utf8 -ErrorAction Stop
      $config = $raw | ConvertFrom-Json -ErrorAction Stop
  }
  catch [System.IO.FileNotFoundException], [System.Management.Automation.ItemNotFoundException] {
      throw [System.IO.FileNotFoundException]::new("Configuration file not found at '$ConfigPath'.", $ConfigPath, $_.Exception)
  }
  catch [System.ArgumentException] {
      throw "Invalid JSON syntax in configuration file '$ConfigPath': $($_.Exception.Message)"
  }
  ```
- **Use `$PSCmdlet.ThrowTerminatingError()` inside advanced functions** when you want an error to terminate the pipeline while still respecting the caller's `-ErrorAction` preference and populating a structured `ErrorRecord` (`ErrorId`, `ErrorCategory`, `TargetObject`).
- **Never use empty `catch {}` blocks or blanket `-ErrorAction SilentlyContinue`:** If an error is expected and intentionally ignored (e.g., probing whether an optional registry key exists), document *why* in a comment and narrow `-ErrorAction Ignore` to that single cmdlet.
- **Always clean up resources in `finally`:** Close file streams, dispose .NET objects (`IDisposable`), remove temporary files, and restore modified environment/location state (`Push-Location` / `Pop-Location`) inside a `finally` block so cleanup executes even on exceptions or `Ctrl+C`.

---

## 7. Security and safe operations

- **Never use `Invoke-Expression` (`iex`):** It evaluates arbitrary strings as code and is the primary vector for command injection. Pass arguments as structured parameters, hashtables, or argument arrays.
- **Protect secrets at all times:**
  - Never hardcode passwords, API keys, tokens, connection strings, or private keys in scripts, defaults, comments, or tests.
  - Accept credentials via `[PSCredential]` or `[SecureString]` (or retrieve them at runtime via `Microsoft.PowerShell.SecretManagement` / environment-injected secret stores).
  - Never log or write `$Credential.GetNetworkCredential().Password` or `[Runtime.InteropServices.Marshal]` plaintext strings to verbose, debug, warning, or error streams.
- **Treat all external data as untrusted:** Validate and sanitize user inputs, filenames, environment variables, API responses, and git/command outputs before using them in file paths, queries, or process invocations.
- **Implement `ShouldProcess` for state-changing operations:**
  - Add `[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]` (or `'Medium'`) on functions that create, modify, or delete resources.
  - Wrap the actual mutation in `if ($PSCmdlet.ShouldProcess($target, $action)) { ... }` so `-WhatIf` and `-Confirm` work reliably.
  - Do **not** set `SupportsShouldProcess = $true` on read-only `Get-*` or `Test-*` functions.
- **Avoid path traversal and wildcard injection:**
  - Always use `-LiteralPath` instead of `-Path` when handling user-supplied or literal file paths so characters like `[` and `]` are not interpreted as wildcard character classes.
  - When joining untrusted relative paths to a base directory, resolve the canonical full path (`[System.IO.Path]::GetFullPath(...)`) and verify it starts with the expected base directory.
- **Do not bypass security controls:** Never add `Set-ExecutionPolicy Unrestricted`, TLS certificate validation bypasses (`-SkipCertificateCheck`), or firewall disablement as workarounds in reusable code.

---

## 8. Files, paths, encoding, and native commands

- **Construct paths with `Join-Path`:** Never concatenate paths with string interpolation (`"$dir\$file"`). In PowerShell 7+, `Join-Path` accepts multiple child segments (`Join-Path $Root 'config' 'app.json'`).
- **Specify encoding explicitly:**
  - For cross-platform / modern UTF-8 without BOM: `-Encoding utf8` in PowerShell 7+, or `[System.Text.UTF8Encoding]::new($false)` with `[System.IO.File]::WriteAllText()` if supporting Windows PowerShell 5.1.
  - When writing files consumed by legacy Windows tools that require a BOM, use `-Encoding utf8BOM` (PS 7+) or `-Encoding utf8` (PS 5.1).
- **Invoke native executables safely:**
  - Pass arguments as an array rather than a single concatenated string so PowerShell handles quoting cleanly:
    ```powershell
    $gitArgs = @('commit', '-m', $CommitMessage, '--', $FilePath)
    $output = & git @gitArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "git commit failed (exit code $LASTEXITCODE): $($output -join [Environment]::NewLine)"
    }
    ```
  - Always inspect `$LASTEXITCODE` immediately after invoking a native binary. Native executables do not throw PowerShell exceptions on non-zero exit codes, and `$?` can be misleading when stderr (`2>&1`) is redirected.
  - Note PowerShell 7.3+ `$PSNativeCommandUseErrorActionPreference`: when enabled, non-zero native exit codes generate PowerShell errors, but checking `$LASTEXITCODE` explicitly remains portable across all versions.

---

## 9. Modules, manifests, and project layout

For anything beyond a single standalone script, organize code as a proper PowerShell module:

```text
MyModule/
├── MyModule.psd1              # Module manifest (version, exports, requirements)
├── MyModule.psm1              # Root module loader
├── Public/                    # Exported functions (one function per file, matching name)
│   ├── Get-Widget.ps1
│   └── Set-Widget.ps1
├── Private/                   # Internal helper functions (not exported)
│   └── Resolve-WidgetConfig.ps1
├── Classes/                   # PowerShell classes/enums (if used)
├── Tests/                     # Pester test suites
│   ├── Unit/
│   │   └── Get-Widget.Tests.ps1
│   └── Integration/
├── PSScriptAnalyzerSettings.psd1
└── README.md
```

- **Explicitly declare exports in `.psd1`:** Never leave `FunctionsToExport = '*'` in production module manifests. List exported function names explicitly so PowerShell module auto-loading works without importing the module first and internal helpers stay private.
- **Resolve paths relative to `$PSScriptRoot`:** Inside `.psm1` and scripts, load sibling files using `Join-Path -Path $PSScriptRoot -ChildPath 'Public'` rather than `Get-Location` or `.\`.

---

## 10. Testing and static analysis

- **Static analysis with PSScriptAnalyzer:**
  - Run `Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./PSScriptAnalyzerSettings.psd1` before considering work complete.
  - Fix warnings rather than suppressing them. When suppression is genuinely justified (e.g., `PSAvoidUsingConvertToSecureStringWithPlainText` inside a test fixture), scope `[Diagnostics.CodeAnalysis.SuppressMessageAttribute()]` to the narrowest function/parameter and include a `Justification` property.
- **Automated testing with Pester (v5+):**
  - Place tests in `*.Tests.ps1` files mirroring the source structure.
  - Follow Pester v5 scoping rules: place setup in `BeforeAll` / `BeforeEach` blocks, never bare code inside `Describe` / `Context` blocks outside lifecycle hooks.
  - Test **happy paths, boundary inputs, and error conditions** (e.g., missing files, invalid parameter values, non-zero native exit codes, `-WhatIf` behavior).
  - Mock external dependencies (`Mock Invoke-RestMethod { ... }`, `Mock Remove-Item { ... }`) and use Pester's `$TestDrive` for isolated temporary file operations.
- **Honest verification reporting:**
  - Run only checks available in the environment. Never install modules or tools implicitly without approval.
  - Report the exact commands executed and their actual pass/fail counts; explicitly disclose if tests or linting could not run.
- See [PowerShell testing with Pester and PSScriptAnalyzer](powershell-testing-pester-psscriptanalyzer-r1.0.0.md) for detailed configuration and examples.

---

## 11. Documentation and delivery

- **Comment-based help on all public commands:** Include `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER` (for every parameter), `.INPUTS`, `.OUTPUTS`, `.EXAMPLE` (at least one runnable example), and `.NOTES` (minimum PowerShell version, prerequisites, side effects).
- **Safe, copy-pasteable examples:** Never use real hostnames, IP addresses, usernames, or secrets in examples. Use RFC 2606 domains (`example.com`), RFC 5737 documentation IPs (`192.0.2.0/24`), and clearly mark destructive examples.
- **Maintain a changelog:** Document breaking changes (renamed parameters, altered output properties, raised minimum PowerShell versions), new features, and bug fixes following Keep a Changelog / SemVer conventions.

---

## 12. Templates

### Script header template

```powershell
#Requires -Version 7.0

<#
.SYNOPSIS
    Generates a compliance summary report from JSON audit logs.

.DESCRIPTION
    Reads JSON audit files from the specified input directory, validates schema
    fields, and writes a consolidated summary JSON file to the output path.
    Existing output files are overwritten only when -Force is specified.

.PARAMETER InputDirectory
    Path to the directory containing *.json audit log files.

.PARAMETER OutputPath
    Destination file path for the consolidated report.

.PARAMETER Force
    Overwrites OutputPath if it already exists.

.EXAMPLE
    .\Export-AuditSummary.ps1 -InputDirectory '.\logs' -OutputPath '.\out\summary.json'
    Processes all JSON logs in .\logs and writes the report to .\out\summary.json.

.EXAMPLE
    .\Export-AuditSummary.ps1 -InputDirectory '.\logs' -OutputPath '.\out\summary.json' -WhatIf
    Previews the report generation without writing to disk.

.NOTES
    Version:      1.0.0
    Author:       Platform Engineering
    Created:      2026-01-15
    Updated:      2026-01-15
    Requirements: PowerShell 7.0+
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string] $InputDirectory,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $OutputPath,

    [Parameter()]
    [switch] $Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Implementation goes here.
```

### Module function template

```powershell
function Get-ServiceEndpoint {
    <#
    .SYNOPSIS
        Retrieves configured service endpoints from a manifest file.

    .DESCRIPTION
        Parses a JSON endpoint manifest and returns normalized endpoint objects.
        Does not modify any files or network state.

    .PARAMETER ManifestPath
        Literal path to the JSON manifest file.

    .PARAMETER Environment
        Optional environment filter ('Dev', 'Staging', or 'Prod').

    .INPUTS
        System.String

    .OUTPUTS
        System.Management.Automation.PSCustomObject

    .EXAMPLE
        Get-ServiceEndpoint -ManifestPath './endpoints.json' -Environment 'Prod'
        Returns all production service endpoints defined in endpoints.json.

    .NOTES
        Requires PowerShell 7.0 or later.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName')]
        [ValidateNotNullOrEmpty()]
        [string] $ManifestPath,

        [Parameter()]
        [ValidateSet('Dev', 'Staging', 'Prod')]
        [string] $Environment
    )

    process {
        if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
            $errRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.IO.FileNotFoundException]::new("Manifest file not found: '$ManifestPath'", $ManifestPath),
                'ManifestNotFound',
                [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                $ManifestPath
            )
            $PSCmdlet.ThrowTerminatingError($errRecord)
        }

        $raw = Get-Content -LiteralPath $ManifestPath -Raw -Encoding utf8 -ErrorAction Stop
        $manifest = $raw | ConvertFrom-Json -ErrorAction Stop

        foreach ($entry in $manifest.Endpoints) {
            if ($PSBoundParameters.ContainsKey('Environment') -and $entry.Environment -ne $Environment) {
                continue
            }

            [PSCustomObject]@{
                PSTypeName  = 'ServiceEndpointInfo'
                Name        = $entry.Name
                Uri         = [uri]$entry.Uri
                Environment = $entry.Environment
            }
        }
    }
}
```

### Inline comment guidelines

- Explain **why**, not **what**: `# Sort descending so the newest token is evaluated first during rotation.`
- Call out non-obvious constraints, upstream API quirks, side effects, and security assumptions.
- Never leave vague comments (`# Fix later`, `# Handle edge case`) or commented-out dead code in committed files.
- Never place credentials, internal tokens, or PII in comments or help examples.

---

## 13. Rules for AI agents

AI agents working in a PowerShell repository must follow this workflow:

1. **Inspect first:** Read `AGENTS.md`, `README.md`, `.editorconfig`, `PSScriptAnalyzerSettings.psd1`, module manifests, and CI configs. Confirm target PowerShell version(s), OS platforms, and test commands before editing.
2. **Trace before changing:** Inspect callers, parameter sets, output types, and downstream consumers before modifying an interface. Ask for clarification only when a material requirement cannot be resolved from the repo.
3. **Plan a minimal diff:** Identify the exact files and behaviors to change. Do not refactor unrelated code, reformat untouched files, or alter module manifests unnecessarily.
4. **Edit safely:** Preserve existing user work. Never commit secrets, weaken security settings, or execute destructive/remote commands without explicit authorization.
5. **Audit the diff:** Verify there are no cmdlet aliases, unquoted paths, `Invoke-Expression` calls, `+=` array loops, `$value -eq $null` inversions, PS 7-only syntax in PS 5.1 targets, or accidental formatting churn.
6. **Verify proportionately:** Run `Invoke-ScriptAnalyzer` and Pester tests when available in the environment. Never fabricate test output or claim an unrun check passed.
7. **Report precisely:** Summarize what changed, which files were modified, the exact verification commands run and their outcomes, and any remaining limitations or assumptions.

### Agent guardrails

- **No silent contract breaks:** Never rename public parameters, remove aliases, change output object property names, or alter exit codes without explicit instruction.
- **No error suppression to fake green runs:** Do not add `-ErrorAction SilentlyContinue` or empty `catch` blocks to make failing tests or scripts appear successful.
- **Respect repository overrides:** If local repository guidelines conflict with this general standard, follow the repository's documented standard unless doing so introduces a security vulnerability or data-loss bug—and explicitly note the deviation.

---

## 14. Quick checklist

- [ ] Target PowerShell version(s), OS support, and `#Requires` statements match project requirements.
- [ ] Public functions use `[CmdletBinding()]`, approved `Verb-Noun` names, parameter validation, and full cmdlet names (zero aliases).
- [ ] Functions return structured objects (`[PSCustomObject]`), keep the success stream clean, and place `$null` on the left of comparisons.
- [ ] Collections avoid `+=` inside loops; multi-parameter calls use splatting (`@params`).
- [ ] Errors use `-ErrorAction Stop` inside `try`/`catch`, preserve exception context, and clean up resources in `finally`.
- [ ] State-changing commands implement `SupportsShouldProcess` (`-WhatIf`/`-Confirm`) and use `-LiteralPath` with `Join-Path`.
- [ ] Native commands receive argument arrays and have `$LASTEXITCODE` checked immediately.
- [ ] Secrets are never hardcoded, logged, or committed; `Invoke-Expression` is never used.
- [ ] Comment-based help, Pester tests, and `PSScriptAnalyzer` checks are updated and verified.