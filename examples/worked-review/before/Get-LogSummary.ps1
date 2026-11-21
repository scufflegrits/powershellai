#Requires -Version 7.0

<#
.SYNOPSIS
    Original example: counts log entries in a directory.

.DESCRIPTION
    Intentionally contains behavior defects for the worked review. Read-only;
    compare it with the corrected script and run the shared tests.

.PARAMETER Path
    Directory to inspect.

.EXAMPLE
    ./Get-LogSummary.ps1 -Path ./logs
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $Path
)

$logs = @(Get-ChildItem -Path $Path -Filter '*.log')

[PSCustomObject]@{
    Path     = $Path
    LogCount = $logs.Count
}
