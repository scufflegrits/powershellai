# PowerShell Best Practices

**Guide version:** 1.0.7

**Applies to:** PowerShell 7+ (cross-platform) unless a project explicitly targets Windows PowerShell 5.1.

**Purpose:** A comprehensive, practical engineering standard for writing safe, readable, maintainable, and testable PowerShell scripts and modules, and for AI agents contributing to PowerShell repositories.

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
14. [Guide versioning, sources, and maintenance](#14-guide-versioning-sources-and-maintenance)
15. [Quick checklist](#15-quick-checklist)

## 1. Principles

- **Clarity over cleverness:** Prefer explicit, readable, predictable code over compressed one-liners, obscure automatic variables, or golfed syntax.
- **Visible side effects:** Any function or script that modifies state (files, registry, network, services, cloud resources) should communicate that through approved verbs (`Set-`, `Remove-`, `New-`, `Update-`), comment-based help, verbose output, and `ShouldProcess` (`-WhatIf`/`-Confirm`) support where operators benefit from preview/confirmation.
- **Safe defaults & least privilege:** Require explicit opt-in for destructive or overwriting actions, bind to narrow scopes, and request elevation only when strictly required.
- **Fail loudly with context:** Never swallow errors silently. Preserve original exceptions and attach actionable context (operation, target, relevant non-secret identifiers).
- **Idempotency:** Design state-changing operations so running them repeatedly converges on the desired state without duplicating artifacts or failing unnecessarily.
- **Repository conformity:** Honor the conventions, formatting rules, and compatibility targets of the existing codebase.

## 2. Repository, environment, and version awareness

- **Inspect project metadata first:** Check `AGENTS.md`, `README.md`, `CONTRIBUTING.md`, `.editorconfig`, `PSScriptAnalyzerSettings.psd1`, CI workflows (`.github/workflows/`, Azure Pipelines), and module manifests (`*.psd1`) before making edits.
- **Declare supported `#Requires` directives early:** Place `#Requires` statements at the very top of entry-point scripts (above comment-based help) to enforce the specific preconditions `#Requires` supports—PowerShell version (`-Version`), edition (`-PSEdition`), modules (`-Modules`), assembly/snap-in dependencies, or elevation (`-RunAsAdministrator`). Because `#Requires` only validates those documented forms, pair it with explicit runtime checks for OS platform, external binaries, or environment configuration, and verify `#Requires` syntax against your target PowerShell version:

  ```powershell
  #Requires -Version 7.2
  #Requires -Modules Microsoft.PowerShell.SecretManagement
  ```

  *(Note: Hashtable module specifications such as `@{ ModuleName = '...'; ModuleVersion = '...' }` in `#Requires -Modules` were introduced in PowerShell 5.0; always verify version support when targeting older environments or using minimum/maximum version keys.)*

- **Respect PowerShell 5.1 vs. PowerShell 7+ differences:** Do not assume PowerShell 7+ syntax or cmdlet behavior works in Windows PowerShell 5.1 (`powershell.exe`). Key differences to account for when targeting dual compatibility:
  - **Operators:** Ternary (`$a ? $b : $c`), null-coalescing (`$a ?? $b`), null-conditional (`${a}?.Prop`), and pipeline chain operators (`&&`, `||`) are **PowerShell 7+ only**.
  - **Platform variables:** `$IsWindows`, `$IsLinux`, and `$IsMacOS` exist automatically in PowerShell 6.0+/7+, but are undefined (`$null`) in Windows PowerShell 5.1. If supporting 5.1, check `$PSVersionTable.PSEdition -eq 'Desktop'` or `[System.Runtime.InteropServices.RuntimeInformation]`.
  - **Default file encodings:** PowerShell 6+ defaults text output to UTF-8 without BOM, but read behavior and individual cmdlets can differ. In Windows PowerShell 5.1, defaults vary by cmdlet: `Set-Content`/`Add-Content` use the system active code page (`Default`, e.g., Windows-1252), `Out-File` and redirection (`>`, `>>`) use UTF-16LE (`Unicode`), and `Export-Csv` uses ASCII. Always pass `-Encoding` explicitly when file portability matters (see Microsoft Learn: *about_Character_Encoding*).
  - **JSON depth behavior:** `ConvertTo-Json` defaults to `-Depth 2` across PowerShell versions and can truncate deeply nested objects when input exceeds that depth; PowerShell 7.1+ emits a warning when the input object exceeds the specified `-Depth` (see Microsoft Learn: *ConvertTo-Json*). `ConvertFrom-Json` added `-Depth` in PowerShell 6.2 (defaulting to `1024`); Windows PowerShell 5.1 `ConvertFrom-Json` does not have a `-Depth` parameter.
  - **Parameter & cmdlet enhancements:** Features such as `[ValidateScript(..., ErrorMessage = '...')]` (PowerShell 6.0+) and multi-segment `Join-Path -Path $a -ChildPath $b, $c` (PowerShell 6.0+) are not available in Windows PowerShell 5.1.

- **Account for remoting and serialization boundaries:** Commands executed over `Invoke-Command` (WinRM, SSH, or PSSessions) serialize objects across a boundary. Complex live .NET objects may become deserialized snapshots (`Deserialized.<TypeName>`) with methods stripped, and nested depth or type fidelity can differ from local in-process calls. Return plain, self-contained data objects (`[PSCustomObject]` with primitive/string/`[uri]`/`[datetime]` fields) when crossing remoting boundaries.
- **Keep changes scoped:** Match established naming and layout patterns unless they introduce a bug or security flaw. Avoid unrelated refactoring or dependency upgrades.

## 3. Style, formatting, and maintainability

- **Approved verbs and PascalCase:** Name public functions using `Verb-Noun` with approved PowerShell verbs (`Get-Verb`) and singular nouns (`Get-ServiceAccount`, not `Get-ServiceAccounts`). Use `PascalCase` for functions, parameters, and exported variables; use `camelCase` for local variables.
- **Avoid aliases in committed code:** Do not use cmdlet or parameter aliases (`%`, `?`, `gci`, `ls`, `gc`, `select`, `where`, `ft`, `-ea`, `-ev`) in committed production scripts, modules, or tests. Full names improve readability, searchability, and cross-platform consistency. *Exceptions:* Well-known DSL keywords that are technically aliases in test frameworks or build tools (such as Pester's `BeforeAll`/`It` or InvokeBuild tasks), documented parameter aliases (`[Alias('FullName')]`) for pipeline compatibility, and standard pipeline aliases (`%`, `?`, `Where-Object`/`ForEach-Object` shorthand) when used intentionally in interactive commands or concise documentation/examples where brevity aids clarity.
- **Use splatting when calls become wide or conditional:** Use a hashtable and splatting (`@params`) whenever a command has many parameters, builds arguments conditionally, or would otherwise require backtick (`` ` ``) line continuations. For short, single-line invocations with 3–4 brief parameters, inline arguments remain cleaner and easier to read than an extra hashtable block.

  ```powershell
  # Avoid: backtick line continuations (fragile if trailing whitespace is added)
  Get-ChildItem -Path $SourceDir `
      -Filter '*.log' `
      -Recurse `
      -File

  # Prefer: splatting for multi-parameter or conditional calls
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
- **Use `Set-StrictMode` deliberately:** `Set-StrictMode -Version Latest` helps catch uninitialized variables, missing object properties, and out-of-bounds array indices in standalone scripts or test runners, but be aware it will throw on optional/absent properties on `[PSCustomObject]` or deserialized payloads unless checked safely (e.g., `$obj.PSObject.Properties['OptionalProp']`). Avoid injecting `Set-StrictMode` globally inside shared module `.psm1` files if doing so could alter caller or legacy helper expectations in unexpected ways.
- **Consistent formatting:** Follow the repository's `PSScriptAnalyzerSettings.psd1` / `Invoke-Formatter` configuration (commonly OTBS — One True Brace Style, 4-space indentation, spaces around operators).

## 4. Functions, parameters, and pipeline design

### Advanced function structure

Prefer `[CmdletBinding()]` and a typed `param()` block for public functions, reusable helpers, and entry-point scripts so callers get common parameters (`-Verbose`, `-Debug`, `-ErrorAction`, `-ErrorVariable`, `-InformationAction`) and strict parameter binding (rejecting unknown positional arguments). Consider `PositionalBinding = $false` on functions or scripts with many parameters where accidental positional binding could cause subtle errors. *Exceptions:* Trivial, non-exported internal helpers with 0–1 simple arguments, Pester test helpers, or simple scriptblocks (`Where-Object { ... }`) do not require `[CmdletBinding()]` when it adds boilerplate without benefit.

### Parameter sets

When a function or script supports mutually exclusive parameter combinations (for example, looking up a resource by `-Id` versus `-Name`, or selecting `-Path` versus `-LiteralPath`), declare explicit `ParameterSetName` attributes on the relevant `[Parameter(...)]` entries, set `DefaultParameterSetName` on `[CmdletBinding()]`, and branch on `$PSCmdlet.ParameterSetName`:

```powershell
function Get-DeploymentTarget {
    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByName')]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $Id,

        [Parameter()]
        [ValidateSet('Dev', 'Staging', 'Prod')]
        [string] $Environment = 'Prod'
    )

    switch ($PSCmdlet.ParameterSetName) {
        'ByName' { "Resolving target '$Name' in $Environment" }
        'ById'   { "Resolving target ID '$Id' in $Environment" }
    }
}
```

### Boundary validation

Validate inputs at the parameter boundary using built-in attributes rather than manual `if` checks inside the function body:

- `[ValidateNotNullOrEmpty()]` / `[ValidateNotNull()]`
- `[ValidateSet('Dev', 'Staging', 'Prod')]`
- `[ValidateRange(1, 65535)]`
- `[ValidatePattern('^[a-z0-9-]+$')]`
- `[ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]` *(In PowerShell 6.0+/7+, you may add `ErrorMessage = '...'` for clearer user feedback; omit `ErrorMessage` if targeting Windows PowerShell 5.1.)*

### Pipeline support (`begin` / `process` / `end`)

When a function accepts pipeline input (`ValueFromPipeline` or `ValueFromPipelineByPropertyName`) and processes items incrementally, use `begin`, `process`, and `end` blocks so items stream one at a time without buffering the entire collection in memory. *(Exception: If an operation inherently requires the full collection before acting—such as sorting, deduplicating across all inputs, or batching into a single bulk API payload—collect items in `process` and execute the batch in `end`, or accept a collection parameter directly without pipeline streaming.)*

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
- **Keep the success stream clean:** Everything not captured or redirected in PowerShell falls into the success output stream (`1>`). Watch out for unintended output leaks such as `New-Item` or `mkdir` emitting `DirectoryInfo`/`FileInfo` objects when the caller does not expect them—assign to `$null = New-Item ...` when suppressing unwanted command output.
- **Account for collection unrolling:** PowerShell unrolls arrays/collections sent to the pipeline by default. If a function may return zero, one, or many items and callers expect an array even when 0 or 1 item is returned (or when strict collection indexing is used), wrap the call site or return value intentionally (e.g., `@(Get-ServiceEndpoint ...)`), and remember that `Write-Output -NoEnumerate` prevents unrolling when passing a collection as a single pipeline item.
- **Suppress return values from `.NET` methods intentionally:** Calling methods such as `[void]$list.Add($item)` or `$null = $list.Add($item)` suppresses return values (like the integer index returned by `ArrayList.Add()`). Use `[void]` or `$null =` deliberately to discard unwanted return values, and prefer `System.Collections.Generic.List[T]` (whose `.Add()` returns `void`) or direct loop assignment when building collections.
- **Use the right output stream:**
  - Success output (`Write-Output` or bare expression): Structured data objects only.
  - Operational status (`Write-Information` / `Write-Host` in PS 5+): User-facing status messages when running interactively. Avoid `Write-Host` inside library/module functions when callers may capture or redirect output; prefer `Write-Verbose` or `Write-Information` so stream behavior stays predictable.
  - Diagnostics (`Write-Verbose`): Detailed execution trace for troubleshooting (`-Verbose`).
  - Non-fatal anomalies (`Write-Warning`): Recoverable issues that merit operator attention.
- **Null and boolean comparisons:** Always place `$null` on the **left-hand side** of comparisons (`$null -eq $value`, `$null -ne $value`). When `$value` is an array, `$value -eq $null` filters the array for null elements instead of testing whether the variable itself is null.

## 5. Data structures, collections, and performance

- **Avoid `+=` to build arrays in loops:** PowerShell arrays are fixed-size .NET arrays; `+=` allocates a brand-new array and copies all elements on every iteration ($O(n^2)$).

  ```powershell
  # Avoid: O(n^2) reallocation
  $results = @()
  foreach ($item in $items) {
      $results += Invoke-ItemProcessing -InputObject $item
  }

  # Prefer 1: Direct assignment from loop/pipeline (idiomatic and fast)
  $results = foreach ($item in $items) {
      Invoke-ItemProcessing -InputObject $item
  }

  # Prefer 2: Generic List when conditionally adding across multiple branches
  $results = [System.Collections.Generic.List[psobject]]::new()
  foreach ($item in $items) {
      if ($item.IsValid) {
          $results.Add((Invoke-ItemProcessing -InputObject $item))
      }
  }
  ```

- **Assign custom `PSTypeName` properly on `[PSCustomObject]`:** Do **not** include a `PSTypeName` key inside `[PSCustomObject]@{ ... }`—PowerShell treats it as an ordinary note property rather than inserting it into `PSTypeNames`. Instead, insert the type name into `PSTypeNames` after construction:

  ```powershell
  $status = [PSCustomObject]@{
      Name      = $service.Name
      State     = $service.Status
      CheckedAt = [datetime]::UtcNow
  }
  $status.PSTypeNames.Insert(0, 'Contoso.ServiceStatus')
  $status
  ```

- **Use `[System.Text.StringBuilder]` for large string concatenation** inside loops rather than repeated `$str += ...`.
- **Prefer `[hashtable]` or `[System.Collections.Generic.HashSet[string]]`** for repeated membership lookups (`$lookup.ContainsKey($id)`) instead of `-contains` / `-in` against large arrays.

## 6. Errors, logging, and resource cleanup

- **Distinguish terminating vs. non-terminating errors:**
  - Most cmdlets emit **non-terminating** errors by default, which **will not enter a `catch` block** unless `-ErrorAction Stop` is specified (or `$ErrorActionPreference = 'Stop'` is set).
  - Use `-ErrorAction Stop` on individual commands inside `try` blocks when failure should abort the operation.

- **Catch specific exception types when reliable, and preserve context:**

  ```powershell
  try {
      $raw = Get-Content -LiteralPath $ConfigPath -Raw -Encoding utf8 -ErrorAction Stop
      $config = $raw | ConvertFrom-Json -ErrorAction Stop
  }
  catch [System.IO.FileNotFoundException], [System.Management.Automation.ItemNotFoundException] {
      # Pass $ConfigPath as FileName and attach $_.Exception as InnerException so callers retain file and exception context.
      $wrappedEx = [System.IO.FileNotFoundException]::new("Configuration file not found at '$ConfigPath'.", $ConfigPath, $_.Exception)
      $errRecord = [System.Management.Automation.ErrorRecord]::new(
          $wrappedEx,
          'ConfigFileNotFound',
          [System.Management.Automation.ErrorCategory]::ObjectNotFound,
          $ConfigPath
      )
      $PSCmdlet.ThrowTerminatingError($errRecord)
  }
  catch {
      # Because underlying read or JSON parse exceptions vary across PowerShell versions and serializers,
      # use a general load-failure identifier and preserve $_.Exception as InnerException rather than flattening to a string.
      $wrappedEx = [System.InvalidOperationException]::new("Failed to load configuration from '$ConfigPath'.", $_.Exception)
      $errRecord = [System.Management.Automation.ErrorRecord]::new(
          $wrappedEx,
          'ConfigurationLoadFailed',
          [System.Management.Automation.ErrorCategory]::ReadError,
          $ConfigPath
      )
      $PSCmdlet.ThrowTerminatingError($errRecord)
  }
  ```

- **Use `$PSCmdlet.ThrowTerminatingError()` inside advanced functions** when you want an error to terminate the pipeline while still respecting the caller's `-ErrorAction` preference and populating a structured `ErrorRecord` (`ErrorId`, `ErrorCategory`, `TargetObject`). When a caller already has sufficient context from the original error, `throw` (bare rethrow) preserves the original `ErrorRecord` and stack trace intact.
- **Ensure deterministic non-zero exit codes in CI / automation scripts:** When launched with `pwsh -NonInteractive -File .\script.ps1`, an unhandled terminating error normally gives the PowerShell process a non-zero exit code. `$LASTEXITCODE` is different: it records the exit status of the last native executable and may be unset if no native executable has run. If a script catches and handles a fatal error but still needs to fail the CI job, explicitly exit with a non-zero status code (for example, `exit 1`) after cleanup.
- **Never use empty `catch {}` blocks or blanket `-ErrorAction SilentlyContinue`:** If an error is expected and intentionally ignored (e.g., probing whether an optional registry key exists), document *why* in a comment and narrow `-ErrorAction Ignore` to that single cmdlet.
- **Always clean up resources in `finally`:** Close file streams, dispose .NET objects (`IDisposable`), remove temporary files, and restore modified environment/location state (`Push-Location` / `Pop-Location`) inside a `finally` block so cleanup executes even on exceptions or `Ctrl+C`.

## 7. Security and safe operations

- **Never use `Invoke-Expression` (`iex`):** It evaluates arbitrary strings as code and is the primary vector for command injection. Pass arguments as structured parameters, hashtables, or argument arrays.
- **Protect secrets at all times:**
  - Never hardcode passwords, API keys, tokens, connection strings, or private keys in scripts, defaults, comments, or tests.
  - Accept credentials via `[PSCredential]` or `[SecureString]` (or retrieve them at runtime via `Microsoft.PowerShell.SecretManagement` / environment-injected secret stores).
  - Never log or write `$Credential.GetNetworkCredential().Password` or `[Runtime.InteropServices.Marshal]` plaintext strings to verbose, debug, warning, or error streams.
- **Treat all external data as untrusted:** Validate and sanitize user inputs, filenames, environment variables, API responses, and git/command outputs before using them in file paths, queries, or process invocations.
- **Implement `ShouldProcess` where preview and confirmation add safety:**
  - Add `[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]` (or `'Medium'`) on public functions that create, modify, or delete external or persistent state (files, infrastructure, accounts, configuration).
  - Wrap every state-changing action in `if ($PSCmdlet.ShouldProcess($target, $action)) { ... }` (using distinct target/action descriptions when creating parent directories vs. writing a file) so `-WhatIf` and `-Confirm` preview and gate all mutations.
  - *Exceptions:* Do **not** set `SupportsShouldProcess = $true` on read-only `Get-*` or `Test-*` functions, or on pure in-memory data transformations (`ConvertTo-*`, `Format-*`). Small internal private helpers called inside an already-guarded `ShouldProcess` block also do not need redundant `ShouldProcess` checks.
- **Prevent wildcard injection, path traversal, and symlink escapes:**
  - Use `-LiteralPath` instead of `-Path` when handling user-supplied or literal file paths so characters like `[` and `]` are not interpreted as wildcard character classes.
  - **Canonicalize and resolve links when validating untrusted paths:** `-LiteralPath` prevents wildcard expansion, **not** directory traversal (`..\`), symlinked/junctioned ancestor directories, or case-sensitivity mismatches across filesystems. Do not rely on a partial or platform-naïve path check for untrusted input; when your threat model requires constraining paths to a trusted root, canonicalize the root and candidate paths, walk/resolve link targets across path segments (noting `ResolveLinkTarget()` requires .NET 6+ / PowerShell 7.2+ and filesystem case-sensitivity rules depend on both OS and mount/filesystem configuration), and compare against the canonical root boundary.
- **Account for overwrite races and `-Force` / `-Overwrite` semantics:**
  - Across PowerShell cmdlets, `-Force` has inconsistent semantics (for some cmdlets it overwrites read-only/existing files; for others it creates missing parent directories or bypasses prompts). Using a dedicated `-Overwrite` switch—or clearly documenting how `-Force` interacts with existing targets and `$PSCmdlet.ShouldProcess()`—avoids conflating generic force semantics with explicit overwrite consent.
  - A `Test-Path` followed by a write check is suitable for ordinary single-process scripts, **not** concurrent or high-security workflows where another process may create or replace the target between the check and the write. For concurrent or sensitive workflows, use atomic file creation/replacement APIs (such as creating a temporary file and atomically moving/replacing it via `[System.IO.File]::Move(..., $true)` or `[System.IO.File]::Replace(...)` where supported).
- **Do not bypass security controls:** Never add `Set-ExecutionPolicy Unrestricted`, TLS certificate validation bypasses (`-SkipCertificateCheck`), or firewall disablement as workarounds in reusable code.

## 8. Files, paths, encoding, and native commands

- **Construct paths with `Join-Path`:** Never concatenate paths with string interpolation (`"$dir\$file"`).
  - *Compatibility note:* Passing more than two path segments (`Join-Path $Root 'config' 'app.json'`) requires **PowerShell 6.0+**. If targeting Windows PowerShell 5.1, nest `Join-Path` calls (`Join-Path (Join-Path $Root 'config') 'app.json'`).
- **Specify encoding and line endings explicitly:**
  - For cross-platform / modern UTF-8 without BOM: `-Encoding utf8` in PowerShell 6.0+/7+, or `[System.Text.UTF8Encoding]::new($false)` with `[System.IO.File]::WriteAllText()` if supporting Windows PowerShell 5.1.
  - When writing files consumed by legacy Windows tools that require a BOM, use `-Encoding utf8BOM` (PS 6.0+/7+) or `-Encoding utf8` (PS 5.1).
  - Use `[Environment]::NewLine` (or normalize line endings explicitly when parsing external text) rather than assuming CRLF (`` `r`n ``) or LF (`` `n ``) across platforms.
- **Invoke native executables safely:**
  - Pass arguments as an array rather than a single concatenated string so PowerShell handles quoting cleanly:

    ```powershell
    $gitArgs = @('commit', '-m', $CommitMessage, '--', $FilePath)
    $output = & git @gitArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "git commit failed (exit code $LASTEXITCODE): $($output -join [Environment]::NewLine)"
    }
    ```

  - **Inspect `$LASTEXITCODE` immediately** after invoking a native binary. Native executables do not throw PowerShell exceptions on non-zero exit codes, and `$LASTEXITCODE` is the authoritative indicator of the native process's exit status.
  - Note PowerShell 7.3+ `$PSNativeCommandUseErrorActionPreference`: when enabled, non-zero native exit codes generate PowerShell errors, but checking `$LASTEXITCODE` explicitly remains portable across all versions.

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
│   │   ├── Get-Widget.Tests.ps1
│   │   └── Private/
│   │       └── Resolve-WidgetConfig.Tests.ps1
│   ├── Integration/
│   │   └── WidgetWorkflow.Tests.ps1
│   └── Fixtures/
│       └── sample-config.json
├── PSScriptAnalyzerSettings.psd1
└── README.md
```

- **Explicitly declare exports in `.psd1`:** Avoid leaving `FunctionsToExport = '*'` (or `CmdletsToExport = '*'`, `AliasesToExport = '*'`) in production module manifests. Explicitly listing exported commands defines a clear, intentional public API contract, avoids wildcard exports, and lets PowerShell read exported commands directly from the manifest without loading or executing the module first (see Microsoft Learn: *about_Module_Manifests*).
- **Resolve paths relative to `$PSScriptRoot`:** Inside `.psm1` and scripts, load sibling files using `Join-Path -Path $PSScriptRoot -ChildPath 'Public'` rather than `Get-Location` or `.\`.

## 10. Testing and static analysis

- **Static analysis with PSScriptAnalyzer:**
  - Run the repository's configured analyzer settings before considering work complete (for example, `Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./PSScriptAnalyzerSettings.psd1` when a repo settings file exists, or the project's documented CI lint task).
  - Fix warnings rather than suppressing them. When suppression is genuinely justified (e.g., `PSAvoidUsingConvertToSecureStringWithPlainText` inside a test fixture), scope `[Diagnostics.CodeAnalysis.SuppressMessageAttribute()]` to the narrowest function/parameter and include a `Justification` property.
- **Automated testing with Pester (standard: Pester v5):**
  - Standardize new and updated test suites on **Pester v5** (`#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }`), matching the Pester v5 lifecycle hooks and `Should` assertions shown below. Only follow Pester v4 conventions when maintaining a legacy test suite explicitly pinned to Pester v4.
  - Mirror the source layout under `Tests/Unit/` and `Tests/Integration/` using `*.Tests.ps1` filenames, and keep static sample payloads in `Tests/Fixtures/`.
  - Follow Pester v5 scoping rules: place setup in `BeforeAll` / `BeforeEach` blocks, never bare code inside `Describe` / `Context` blocks outside lifecycle hooks.
  - Test **happy paths, boundary inputs, and error conditions** (e.g., missing files, invalid parameter values, non-zero native exit codes, `-WhatIf` behavior).
  - Mock external dependencies (`Mock Invoke-RestMethod { ... }`, `Mock Remove-Item { ... }`) and use Pester's `$TestDrive` for isolated temporary file operations.

  - **Practical Pester v5 unit test example:**

    ```powershell
    BeforeAll {
        Import-Module (Join-Path -Path $PSScriptRoot -ChildPath '..\..\MyModule.psd1') -Force
    }

    Describe 'Get-ServiceEndpoint' {
        BeforeEach {
            $manifestFile = Join-Path -Path $TestDrive -ChildPath 'endpoints.json'
            @{
                Endpoints = @(
                    @{ Name = 'Auth'; Uri = 'https://auth.example.com'; Environment = 'Prod' }
                    @{ Name = 'Billing'; Uri = 'https://billing.dev.example.com'; Environment = 'Dev' }
                )
            } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestFile -Encoding utf8
        }

        It 'filters endpoints by Environment and assigns custom PSTypeName' {
            $result = @(Get-ServiceEndpoint -ManifestPath $manifestFile -Environment 'Prod')

            $result | Should -HaveCount 1
            $result[0].Name | Should -Be 'Auth'
            $result[0].PSTypeNames | Should -Contain 'ServiceEndpointInfo'
        }

        It 'throws a terminating error when ManifestPath does not exist' {
            $missing = Join-Path -Path $TestDrive -ChildPath 'missing.json'
            { Get-ServiceEndpoint -ManifestPath $missing -ErrorAction Stop } |
                Should -Throw -ErrorId 'ManifestNotFound*'
        }
    }
    ```

  - **Running tests:** Use the project's test runner or CI entrypoint if defined (e.g., `build.ps1`, `Invoke-Build`, `psake`, or a `PesterConfiguration` script). Otherwise, invoke Pester v5 directly against the test directory (for example, `Invoke-Pester -Path ./Tests -Output Detailed`).

- **Honest verification reporting:**
  - Run only checks available in the environment. Never install modules or tools implicitly without approval.
  - Report the exact commands executed and their actual pass/fail counts; explicitly disclose if tests or linting could not run.
- See [PowerShell Testing with Pester and PSScriptAnalyzer](powershell-testing-pester-psscriptanalyzer-r1.0.7.md) for detailed configuration and examples.

## 11. Documentation and delivery

- **Comment-based help placement and scope:**
  - **Standalone / entry-point scripts:** Place `#Requires` statements at line 1, followed immediately by the script's comment-based help block (`<# ... #>`), followed by `[CmdletBinding()]` and `param()`.
  - **Public module functions:** Place full comment-based help immediately before the `param()` block (or immediately above `function Name`), including `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER` (for every parameter), `.INPUTS`, `.OUTPUTS`, `.EXAMPLE` (at least one runnable example), and `.NOTES` (minimum PowerShell version, prerequisites, side effects).
  - **Private / internal helper functions:** Full formal comment-based help is optional when the helper is unexported and its purpose is clear from its name and signature; use a concise `.SYNOPSIS` or brief header comment describing any non-obvious assumptions or invariants.
- **Safe, copy-pasteable examples:** Never use real hostnames, IP addresses, usernames, or secrets in examples. Use RFC 2606 domains (`example.com`), RFC 5737 documentation IPs (`192.0.2.0/24`), and clearly mark destructive examples.
- **Maintain a changelog:** Document breaking changes (renamed parameters, altered output properties, raised minimum PowerShell versions), new features, and bug fixes following Keep a Changelog / SemVer conventions.

## 12. Templates

### Script header and guarded write template

```powershell
#Requires -Version 7.0

<#
.SYNOPSIS
    Generates a compliance summary report from JSON audit logs.

.DESCRIPTION
    Reads JSON audit files from the specified input directory, validates schema
    fields, and writes a consolidated summary JSON file to the output path.
    Existing output files are overwritten only when -Overwrite is specified
    and the write passes ShouldProcess. -WhatIf previews the action; a prompt
    depends on ConfirmImpact and the caller's confirmation preferences. Intended for
    single-process execution; use atomic staging/replace for concurrent writers.

.PARAMETER InputDirectory
    Path to the directory containing *.json audit log files.

.PARAMETER OutputPath
    Destination file path for the consolidated report.

.PARAMETER Overwrite
    Allows overwriting OutputPath if it already exists (subject to ShouldProcess).

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
    [switch] $Overwrite
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ((Test-Path -LiteralPath $OutputPath) -and -not $Overwrite) {
    throw "Output file '$OutputPath' already exists. Re-run with -Overwrite to replace it."
}

$summary = [PSCustomObject]@{
    GeneratedAt = [datetime]::UtcNow.ToString('o')
    SourceDir   = (Resolve-Path -LiteralPath $InputDirectory).Path
    RecordCount = 0
}

$parentDir = Split-Path -Path $OutputPath -Parent
if (-not [string]::IsNullOrEmpty($parentDir) -and -not (Test-Path -LiteralPath $parentDir)) {
    if ($PSCmdlet.ShouldProcess($parentDir, 'Create output directory')) {
        $null = New-Item -Path $parentDir -ItemType Directory -Force
    }
}

if ($PSCmdlet.ShouldProcess($OutputPath, 'Write compliance summary report')) {
    $summary | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $OutputPath -Encoding utf8
}
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
        ServiceEndpointInfo (System.Management.Automation.PSCustomObject)

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

            $endpoint = [PSCustomObject]@{
                Name        = $entry.Name
                Uri         = [uri]$entry.Uri
                Environment = $entry.Environment
            }
            $endpoint.PSTypeNames.Insert(0, 'ServiceEndpointInfo')
            $endpoint
        }
    }
}
```

### Inline comment guidelines

- Explain **why**, not **what**: `# Sort descending so the newest token is evaluated first during rotation.`
- Call out non-obvious constraints, upstream API quirks, side effects, and security assumptions.
- Never leave vague comments (`# Fix later`, `# Handle edge case`) or commented-out dead code in committed files.
- Never place credentials, internal tokens, or PII in comments or help examples.

## 13. Rules for AI agents

AI agents working in a PowerShell repository must follow this workflow:

1. **Inspect first:** Read `AGENTS.md`, `README.md`, `.editorconfig`, `PSScriptAnalyzerSettings.psd1`, module manifests, and CI configs. Confirm target PowerShell version(s), OS platforms, and test commands before editing.
2. **Trace before changing:** Inspect callers, parameter sets, output types, and downstream consumers before modifying an interface. Ask for clarification only when a material requirement cannot be resolved from the repo.
3. **Plan a minimal diff:** Identify the exact files and behaviors to change. Do not refactor unrelated code, reformat untouched files, or alter module manifests unnecessarily.
4. **Edit safely:** Preserve existing user work. Never commit secrets, weaken security settings, or execute destructive/remote commands without explicit authorization.
5. **Audit the diff:** Verify there are no unjustified cmdlet aliases, unquoted/unvalidated paths, `Invoke-Expression` calls, `+=` array loops, `$value -eq $null` inversions, PS 7-only syntax in PS 5.1 targets, or accidental formatting churn.
6. **Verify proportionately:** Run `Invoke-ScriptAnalyzer` and Pester tests when available in the environment. Never fabricate test output or claim an unrun check passed.
7. **Report precisely:** Summarize what changed, which files were modified, the exact verification commands run and their outcomes, and any remaining limitations or assumptions.

### Agent guardrails

- **No silent contract breaks:** Never rename public parameters, remove aliases, change output object property names, or alter exit codes without explicit instruction.
- **No error suppression to fake green runs:** Do not add `-ErrorAction SilentlyContinue` or empty `catch` blocks to make failing tests or scripts appear successful.
- **Respect repository overrides:** If local repository guidelines conflict with this general standard, follow the repository's documented standard unless doing so introduces a security vulnerability or data-loss bug—and explicitly note the deviation.

## 14. Guide versioning, sources, and maintenance

### Versioning policy

- **Format (`rMAJOR.MINOR.PATCH`):** Filenames carry an `rX.Y.Z` suffix (e.g., `powershell-best-practices-r1.0.7.md`) matching the `Guide version` header inside the document.
  - **MAJOR (`rX.0.0`):** Fundamental restructuring, breaking changes to agent workflow rules, or shifts in baseline supported PowerShell editions.
  - **MINOR (`r1.Y.0`):** New sections, new rules, or substantive expansions of existing topics.
  - **PATCH (`r1.0.Z`):** Clarifications, technical errata fixes, nuance adjustments, and updated examples without altering core normative requirements.
- **Bump on every review cycle:** Every review and revision cycle bumps the guide version (incrementing `PATCH`, `MINOR`, or `MAJOR` as appropriate) and issues a corresponding `rX.Y.Z` file so revisions remain unambiguously traceable.
- **Recording updates:** Each revision updates the `Guide version` header, updates the companion file reference if a matching companion revision is published, and records changes in the repository's changelog or release notes.

### Authoritative sources

Guidance in this standard aligns with the following primary documentation:

- **PowerShell Language, Cmdlets & Scripting Guidelines:** Microsoft Learn — *PowerShell Documentation* (`learn.microsoft.com/powershell`) and *PowerShell-Docs* (`github.com/MicrosoftDocs/PowerShell-Docs`).
- **Community Style & Engineering Conventions:** *The PowerShell Practice and Style Guide* (`poshcode.gitbook.io/powershell-practice-and-style`).
- **Static Analysis:** *PSScriptAnalyzer* (`github.com/PowerShell/PSScriptAnalyzer`).
- **Testing Framework:** *Pester Documentation* (`pester.dev/docs/quick-start` and `github.com/pester/Pester`).

### Maintenance cadence

- **Release-triggered review:** Review version-sensitive guidance (default encodings, native command error preferences, parameter attributes, Pester/PSScriptAnalyzer rules) whenever a new minor or major version of **PowerShell**, **Pester**, or **PSScriptAnalyzer** reaches General Availability (GA).
- **Scheduled review:** Perform a baseline audit at least **semi-annually** (every 6 months) to prune deprecated patterns, verify external references, and incorporate recurring lessons from repository code reviews.

## 15. Quick checklist

- [ ] Target PowerShell version(s), OS support, and `#Requires` directives (placed above help) match project requirements.
- [ ] Public functions and entry points use `[CmdletBinding()]`, approved `Verb-Noun` names, parameter sets where needed, boundary validation, full comment-based help, and full cmdlet names (no unjustified aliases).
- [ ] Functions return structured objects (`[PSCustomObject]` with `PSTypeNames.Insert(0, ...)` when typed), account for collection unrolling, keep the success stream clean, suppress `.NET` return values intentionally, and place `$null` on the left of comparisons.
- [ ] Collections avoid `+=` inside loops; wide or conditional calls use splatting (`@params`).
- [ ] Errors use `-ErrorAction Stop` inside `try`/`catch`, preserve exception context and `ErrorRecord` details, ensure deterministic non-zero exit codes in CI/automation, and clean up resources in `finally`.
- [ ] State-changing public commands implement `SupportsShouldProcess` (`-WhatIf`/`-Confirm`) where appropriate; paths use `-LiteralPath`, `Join-Path`, explicit overwrite handling, and platform/symlink-aware validation for untrusted paths.
- [ ] Native commands receive argument arrays and have `$LASTEXITCODE` checked immediately.
- [ ] Secrets are never hardcoded, logged, or committed; `Invoke-Expression` is never used.
- [ ] Pester v5 tests and `PSScriptAnalyzer` checks match project conventions and are verified honestly.
