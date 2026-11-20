# PowerShell Testing with Pester

**Guide version:** 1.0.0  
**Purpose:** A practical guide to structuring, writing, running, and reporting PowerShell tests with Pester.

## Table of contents

1. [Testing strategy](#testing-strategy)
2. [Project test layout](#project-test-layout)
3. [Pester v5 discovery and scoping](#pester-v5-discovery-and-scoping)
4. [Writing effective tests](#writing-effective-tests)
5. [Running tests and coverage](#running-tests-and-coverage)
6. [CI and agent workflow](#ci-and-agent-workflow)
7. [Template](#template)
8. [References](#references)

## Testing strategy

Pester executes tests against real or mocked inputs to check observable behavior. Tests can cover output, errors, parameter binding, pipeline behavior, `ShouldProcess` (`-WhatIf` / `-Confirm`), and native command handling. Mocks help isolate external services and side effects.

Tests with mocks do not prove behavior on every supported operating system or PowerShell edition. Validate important paths in the target environments, especially filesystem semantics, native executable invocation, and Windows PowerShell 5.1 versus PowerShell 7+ compatibility.

Follow the repository's pinned Pester version and existing test runner. This guide's examples target Pester v5. Adapt them only when the project uses another version.

## Project test layout

Use the repository's established layout where one exists. A common module layout is:

```text
MyModule/
├── MyModule.psd1
├── MyModule.psm1
├── Public/
├── Private/
└── Tests/
    ├── Unit/
    ├── Integration/
    └── Fixtures/
```

- **Unit tests:** Fast, isolated tests. Mock external I/O, network calls, registry access, and native binaries, or redirect file operations to `$TestDrive`.
- **Integration tests:** Exercise workflows across functions and real dependencies in isolated temporary locations. Mark tests that require services, credentials, or specific platforms.
- **Fixtures:** Keep representative JSON, CSV, XML, or CLI output separate from test logic.
- Use `*.Tests.ps1` filenames so Pester can discover test files.

## Pester v5 discovery and scoping

Pester v5 has **Discovery** and **Run** phases. During discovery, Pester evaluates `Describe` and `Context` blocks to build the test tree. Test bodies and lifecycle hooks run later. Code placed directly inside a `Describe` or `Context`, outside lifecycle hooks and test blocks, runs during discovery; values created there may not be available during the Run phase.

- Put ordinary setup in `BeforeAll` (once for a block/container) or `BeforeEach` (fresh setup per test). Use `AfterEach` and `AfterAll` for cleanup.
- Use `-ForEach` or `-TestCases` to pass data into generated tests:

  ```powershell
  Describe 'Resolve-EndpointUrl' {
      It 'normalizes <InputUrl> to <Expected>' -ForEach @(
          @{ InputUrl = 'https://example.com/'; Expected = 'https://example.com' }
          @{ InputUrl = 'https://example.com/api/'; Expected = 'https://example.com/api' }
      ) {
          Resolve-EndpointUrl -Url $InputUrl | Should -Be $Expected
      }
  }
  ```

- For intentional discovery-time setup, such as enumerating files or loading data to generate tests, use `BeforeDiscovery`, then pass the resulting values to `-ForEach` or `-TestCases`. `BeforeAll` runs later and cannot provide values during discovery.
- To test private module functions, use `InModuleScope` after importing the module:

  ```powershell
  BeforeAll {
      Import-Module (Join-Path $PSScriptRoot '..\..\MyModule.psd1') -Force
  }

  InModuleScope 'MyModule' {
      Describe 'Resolve-EndpointUrl (private)' {
          It 'trims trailing slashes' {
              Resolve-EndpointUrl -Url 'https://example.com/' |
                  Should -Be 'https://example.com'
          }
      }
  }
  ```

## Writing effective tests

For public commands and non-trivial helpers, cover the behavior that matters:

1. **Typical valid inputs:** Check returned objects, properties, types, and custom `PSTypeNames` where part of the contract.
2. **Pipeline behavior:** Check pipeline input by value and by property name, multiple items, and empty input when supported.
3. **Boundaries:** Check empty and single-item collections, whitespace, numeric boundaries, and special path characters such as `[test] file.json`.
4. **Failures:** Check missing files, malformed inputs, native non-zero exit codes, and terminating error behavior.
5. **Side-effect guards:** Verify `-WhatIf` makes no changes. Verify `-Confirm:$false` proceeds without an interactive prompt when that is the intended behavior.

### Mock dependencies at clear boundaries

Mock external commands or wrapper functions rather than duplicating the implementation under test. Use parameter filters and call-count assertions to verify meaningful interactions.

```powershell
It 'deletes only the stale log file' {
    Mock Remove-Item {}
    Mock Get-Item {
        [PSCustomObject]@{
            FullName      = $LiteralPath
            LastWriteTime = (Get-Date).AddDays(-45)
        }
    }
    Mock Test-Path { $true }

    Remove-StaleLog -Path '/var/log/app/old.log' -RetentionDays 30 -Confirm:$false

    Should -Invoke Remove-Item -Times 1 -Exactly -ParameterFilter {
        $LiteralPath -eq '/var/log/app/old.log' -and $Force
    }
}
```

Be cautious mocking native executables directly because argument and exit-code behavior can vary across platforms. Prefer a small private wrapper such as `Invoke-GitCommand`; unit-test callers by mocking the wrapper and separately test the wrapper's native invocation.

### Isolate filesystem tests

Use Pester's `$TestDrive` or `TestDrive:\` for temporary files and directories. Pester creates a clean drive per test container (typically a test file or script block), and tests in the same container may share it. Use unique paths or per-test cleanup when files could collide. Avoid hardcoded temporary names in shared locations and avoid leaving artifacts in the repository.

## Running tests and coverage

Use the repository's configured runner when available. Otherwise, run the tests directly:

```powershell
Invoke-Pester -Path ./Tests -Output Detailed
Invoke-Pester -Path ./Tests/Unit/Public/Get-ServiceEndpoint.Tests.ps1 -Output Detailed
```

Pester v5 configuration can write JUnit test results and JaCoCo coverage reports:

```powershell
$config = New-PesterConfiguration
$config.Run.Path = './Tests'
$config.Run.Exit = $true
$config.Run.PassThru = $true
$config.Output.Verbosity = 'Detailed'

$config.TestResult.Enabled = $true
$config.TestResult.OutputPath = './TestResults/pester-results.xml'
$config.TestResult.OutputFormat = 'JUnitXml'

$config.CodeCoverage.Enabled = $true
$config.CodeCoverage.Path = @('./Public/*.ps1', './Private/*.ps1')
$config.CodeCoverage.OutputPath = './TestResults/coverage.xml'
$config.CodeCoverage.OutputFormat = 'JaCoCo'

Invoke-Pester -Configuration $config
```

Coverage indicates that code ran; it does not show that assertions verified its behavior. Prioritize boundary cases, error paths, and side-effect guards over a coverage percentage target.

## CI and agent workflow

1. Inspect repository workflows, test runner, and Pester version before using ad hoc commands.
2. Check installed tool versions; do not install modules or change module paths implicitly.
3. Run focused tests for changed behavior, then the wider suite when appropriate.
4. Report the PowerShell edition/version, Pester version, exact commands, pass/fail/skip counts, and unrun checks. State separately if platform or credentials prevented integration tests.

## Template

```powershell
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeAll {
    $moduleManifest = Join-Path $PSScriptRoot '..\..\MyModule.psd1'
    Import-Module -Name $moduleManifest -Force
}

Describe 'Get-ServiceEndpoint' {
    BeforeEach {
        $manifestPath = Join-Path $TestDrive 'endpoints.json'
        @{
            Endpoints = @(
                @{ Name = 'Auth'; Uri = 'https://auth.example.com'; Environment = 'Prod' }
                @{ Name = 'Billing'; Uri = 'https://billing.dev.example.com'; Environment = 'Dev' }
            )
        } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath -Encoding utf8
    }

    It 'returns only endpoints matching Environment' {
        $results = @(Get-ServiceEndpoint -ManifestPath $manifestPath -Environment 'Prod')
        $results | Should -HaveCount 1
        $results[0].Name | Should -Be 'Auth'
        $results[0].PSTypeNames | Should -Contain 'ServiceEndpointInfo'
    }
}
```

## References

- [Pester v5 Quick Start](https://pester.dev/docs/v5/quick-start/)
- [Pester v5 Discovery and Run](https://pester.dev/docs/v5/usage/discovery-and-run)
- [Pester v5 data-driven tests](https://pester.dev/docs/v5/usage/data-driven-tests)
- [Pester v5 TestDrive](https://pester.dev/docs/v5/usage/testdrive)
- [Pester v5 configuration](https://pester.dev/docs/v5/usage/configuration)
