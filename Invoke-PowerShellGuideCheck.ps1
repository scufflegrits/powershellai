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
    Optional PSScriptAnalyzer settings file. If omitted, the script searches
    for PSScriptAnalyzerSettings.psd1 starting at Path (or its parent folder
    when Path is a file) and walking up to the repository root, which is the
    first folder containing .git. The nearest file found is used.

.PARAMETER Severity
    Severities to include, for both PSScriptAnalyzer rules and the supplemental
    guide checks. Defaults to Error and Warning. Parse errors are always
    reported.

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
    # Walk up from the target so results do not depend on the caller's working directory.
    $searchDirectory = if ([System.IO.Directory]::Exists($resolvedPath)) {
        [System.IO.DirectoryInfo]::new($resolvedPath)
    } else {
        [System.IO.FileInfo]::new($resolvedPath).Directory
    }
    while ($null -ne $searchDirectory) {
        $candidate = Join-Path -Path $searchDirectory.FullName -ChildPath 'PSScriptAnalyzerSettings.psd1'
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            $Settings = $candidate
            break
        }
        # Stop at the repository root so settings from unrelated parent folders are never applied.
        if (Test-Path -LiteralPath (Join-Path -Path $searchDirectory.FullName -ChildPath '.git')) {
            break
        }
        $searchDirectory = $searchDirectory.Parent
    }
}
if ($Settings) {
    $Settings = (Resolve-Path -LiteralPath $Settings -ErrorAction Stop).Path
    Write-Information "Using analyzer settings: $Settings" -InformationAction Continue
} else {
    Write-Information 'No analyzer settings file found; using PSScriptAnalyzer default rules.' -InformationAction Continue
}

$analyzerParams = @{
    Severity = $Severity
}
if ($Settings) {
    $analyzerParams.Settings = $Settings
}

$findings = [System.Collections.Generic.List[object]]::new()
# Invoke-ScriptAnalyzer -Path accepts a single path, so analyze the filtered file list one file at a time.
foreach ($file in $sourceFiles) {
    $findings.AddRange([object[]] @(Invoke-ScriptAnalyzer -Path $file.FullName @analyzerParams))
}

# These AST checks supplement analyzer rules and intentionally report only
# high-confidence patterns. They do not attempt to infer runtime intent.
# Invoke-Expression is covered by PSScriptAnalyzer's PSAvoidUsingInvokeExpression.
$loopCommandNames = @('ForEach-Object', 'foreach', '%')

function ConvertTo-GuideFinding {
    # Builds a finding with the same shape as PSScriptAnalyzer diagnostics so results sort and print together.
    param(
        [string] $ScriptName,
        [System.Management.Automation.Language.IScriptExtent] $Extent,
        [string] $RuleName,
        [string] $Severity,
        [string] $Message
    )

    [PSCustomObject]@{
        ScriptName = $ScriptName
        Line       = $Extent.StartLineNumber
        Column     = $Extent.StartColumnNumber
        RuleName   = $RuleName
        Severity   = $Severity
        Message    = $Message
    }
}

function Test-InsideLoop {
    # Returns $true when the node runs repeatedly: inside a loop statement or a
    # ForEach-Object script block, without crossing a function boundary.
    param([System.Management.Automation.Language.Ast] $Node)

    $current = $Node.Parent
    while ($null -ne $current) {
        if ($current -is [System.Management.Automation.Language.LoopStatementAst]) {
            return $true
        }
        if ($current -is [System.Management.Automation.Language.ScriptBlockExpressionAst] -and
            $current.Parent -is [System.Management.Automation.Language.CommandAst] -and
            $current.Parent.GetCommandName() -in $loopCommandNames) {
            return $true
        }
        if ($current -is [System.Management.Automation.Language.FunctionDefinitionAst]) {
            return $false
        }
        $current = $current.Parent
    }
    return $false
}

function Get-GuideVariableKey {
    # Function definitions have distinct local variables, even when their names
    # match. Use the nearest function's source offset, or -1 for script-level code.
    param([System.Management.Automation.Language.AssignmentStatementAst] $Assignment)

    $scopeOffset = -1
    $current = $Assignment.Parent
    while ($null -ne $current) {
        if ($current -is [System.Management.Automation.Language.FunctionDefinitionAst]) {
            $scopeOffset = $current.Extent.StartOffset
            break
        }
        $current = $current.Parent
    }
    return ('{0}:{1}' -f $scopeOffset, $Assignment.Left.VariablePath.UserPath)
}

foreach ($file in $sourceFiles) {
    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        $file.FullName,
        [ref] $tokens,
        [ref] $parseErrors
    )

    # Parse errors are always reported because every other result is unreliable without a valid parse.
    foreach ($parseError in $parseErrors) {
        $findings.Add((ConvertTo-GuideFinding -ScriptName $file.FullName -Extent $parseError.Extent -RuleName 'GuideParseError' -Severity 'Error' -Message $parseError.Message))
    }

    if ('Information' -in $Severity) {
        $isVariableAssignment = {
            param($node)
            $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and
            $node.Left -is [System.Management.Automation.Language.VariableExpressionAst]
        }
        $assignments = @($ast.FindAll($isVariableAssignment, $true))

        # Track array initializations separately for the script and each function.
        # This is a lexical heuristic, not runtime type or control-flow analysis.
        $arrayVariables = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($assignment in $assignments) {
            $rightExpression = if ($assignment.Right -is [System.Management.Automation.Language.CommandExpressionAst]) {
                $assignment.Right.Expression
            }
            if ($assignment.Operator -eq [System.Management.Automation.Language.TokenKind]::Equals -and
                ($rightExpression -is [System.Management.Automation.Language.ArrayExpressionAst] -or
                $rightExpression -is [System.Management.Automation.Language.ArrayLiteralAst])) {
                $null = $arrayVariables.Add((Get-GuideVariableKey -Assignment $assignment))
            }
        }

        foreach ($assignment in $assignments) {
            $variableName = $assignment.Left.VariablePath.UserPath
            if ($assignment.Operator -eq [System.Management.Automation.Language.TokenKind]::PlusEquals -and
                $arrayVariables.Contains((Get-GuideVariableKey -Assignment $assignment)) -and
                (Test-InsideLoop -Node $assignment)) {
                $message = "Array '$variableName' is appended with '+=' inside a loop, which copies the array on every iteration. Assign the loop output directly or use a generic list."
                $findings.Add((ConvertTo-GuideFinding -ScriptName $file.FullName -Extent $assignment.Extent -RuleName 'GuideAvoidArrayAppend' -Severity 'Information' -Message $message))
            }
        }
    }
}

$findings = @($findings | Sort-Object ScriptName, Line, Column, RuleName)
if ($findings.Count -gt 0) {
    # One line per finding keeps output readable and searchable regardless of console width.
    foreach ($finding in $findings) {
        '{0}:{1}:{2}: [{3}] {4}: {5}' -f $finding.ScriptName, $finding.Line, $finding.Column, $finding.Severity, $finding.RuleName, $finding.Message
    }
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
