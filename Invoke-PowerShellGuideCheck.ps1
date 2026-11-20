#Requires -Version 7.0

<#
.SYNOPSIS
    Runs static checks related to the PowerShell best-practices guide.

.DESCRIPTION
    Runs PSScriptAnalyzer on PowerShell source files and adds AST-based checks
    for selected guide rules. The checks are a mechanical aid, not proof that
    code is safe or correct. Review the guide's semantic and operational rules
    manually and run the project's Pester tests in supported environments.

.PARAMETER Path
    File or directory to analyze. Directories are searched recursively.

.PARAMETER Settings
    Optional PSScriptAnalyzer settings file. If omitted, the script uses
    PSScriptAnalyzerSettings.psd1 in the current directory when present.

.PARAMETER Severity
    PSScriptAnalyzer severities to include. Defaults to Error and Warning.

.EXAMPLE
    ./Invoke-PowerShellGuideCheck.ps1 -Path ./src

.EXAMPLE
    ./Invoke-PowerShellGuideCheck.ps1 -Path . -Settings ./PSScriptAnalyzerSettings.psd1

.NOTES
    Requires PowerShell 7.0+ and PSScriptAnalyzer. Does not install dependencies.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $Path,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $Settings,

    [Parameter()]
    [ValidateSet('Error', 'Warning', 'Information')]
    [string[]] $Severity = @('Error', 'Warning')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
    throw 'PSScriptAnalyzer is not installed. Install it using the repository-approved setup process, then rerun this script.'
}

Import-Module PSScriptAnalyzer -ErrorAction Stop

$resolvedPath = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
if ([System.IO.Directory]::Exists($resolvedPath)) {
    $sourceFiles = @(
        Get-ChildItem -LiteralPath $resolvedPath -Recurse -File |
            Where-Object { $_.Extension -in '.ps1', '.psm1', '.psd1' }
    )
} elseif ([System.IO.Path]::GetExtension($resolvedPath) -in '.ps1', '.psm1', '.psd1') {
    $sourceFiles = @(Get-Item -LiteralPath $resolvedPath)
} else {
    throw "Path must be a PowerShell source file or directory: '$resolvedPath'."
}

if ($sourceFiles.Count -eq 0) {
    Write-Warning "No PowerShell source files found under '$resolvedPath'."
    return
}

if (-not $Settings) {
    $defaultSettings = Join-Path -Path (Get-Location).Path -ChildPath 'PSScriptAnalyzerSettings.psd1'
    if (Test-Path -LiteralPath $defaultSettings -PathType Leaf) {
        $Settings = $defaultSettings
    }
}
if ($Settings) {
    $Settings = (Resolve-Path -LiteralPath $Settings -ErrorAction Stop).Path
}

$analyzerParams = @{
    Path     = @($sourceFiles.FullName)
    Severity = $Severity
}
if ($Settings) {
    $analyzerParams.Settings = $Settings
}

$findings = [System.Collections.Generic.List[object]]::new()
$findings.AddRange([object[]] @(Invoke-ScriptAnalyzer @analyzerParams))

# These AST checks supplement analyzer rules and intentionally report only
# high-confidence patterns. They do not attempt to infer runtime intent.
foreach ($file in $sourceFiles) {
    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        $file.FullName,
        [ref] $tokens,
        [ref] $parseErrors
    )

    foreach ($parseError in $parseErrors) {
        $findings.Add([PSCustomObject]@{
            ScriptName = $file.FullName
            Line       = $parseError.Extent.StartLineNumber
            Column     = $parseError.Extent.StartColumnNumber
            RuleName   = 'GuideParseError'
            Severity   = 'Error'
            Message    = $parseError.Message
        })
    }

    foreach ($command in $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true)) {
        $commandName = $command.GetCommandName()
        if ($commandName -in 'Invoke-Expression', 'iex') {
            $findings.Add([PSCustomObject]@{
                ScriptName = $file.FullName
                Line       = $command.Extent.StartLineNumber
                Column     = $command.Extent.StartColumnNumber
                RuleName   = 'GuideAvoidInvokeExpression'
                Severity   = 'Warning'
                Message    = 'Avoid Invoke-Expression; pass input as structured arguments instead.'
            })
        }
    }

    foreach ($assignment in $ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and
        $node.Operator -eq [System.Management.Automation.Language.TokenKind]::PlusEquals
    }, $true)) {
        if ($assignment.Left -is [System.Management.Automation.Language.VariableExpressionAst]) {
            $findings.Add([PSCustomObject]@{
                ScriptName = $file.FullName
                Line       = $assignment.Extent.StartLineNumber
                Column     = $assignment.Extent.StartColumnNumber
                RuleName   = 'GuideAvoidArrayAppend'
                Severity   = 'Information'
                Message    = "Review '+=' on '$($assignment.Left.VariablePath.UserPath)'. Repeated array appends in loops can be inefficient; use a pipeline assignment or generic list where appropriate."
            })
        }
    }
}

$findings = @($findings | Sort-Object ScriptName, Line, Column, RuleName)
if ($findings.Count -gt 0) {
    $findings | Select-Object ScriptName, Line, Column, Severity, RuleName, Message | Format-Table -Wrap -AutoSize
    $errorCount = @($findings | Where-Object Severity -eq 'Error').Count
    $warningCount = @($findings | Where-Object Severity -eq 'Warning').Count
    $informationCount = @($findings | Where-Object Severity -eq 'Information').Count
    Write-Information "Guide check complete: $errorCount error(s), $warningCount warning(s), $informationCount informational review item(s)." -InformationAction Continue

    if ($errorCount -gt 0 -or $warningCount -gt 0) {
        exit 1
    }
} else {
    Write-Information 'Guide check complete: no findings.' -InformationAction Continue
}
