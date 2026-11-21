#Requires -Version 7.0

<#
.SYNOPSIS
    Counts log files directly inside a directory.

.DESCRIPTION
    Treats Path literally and counts files matching *.log without recursion.
    Returns one object with Path (as supplied) and LogCount. Missing paths,
    file paths, and unreadable directories produce terminating errors.
    This script reads directory entries and does not change files.

.PARAMETER Path
    Existing directory to inspect. Wildcard characters are treated literally.

.EXAMPLE
    ./Get-LogSummary.ps1 -Path './logs [sample]'
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$directory = Get-Item -LiteralPath $Path -ErrorAction Stop
if (-not $directory.PSIsContainer) {
    throw "Path must be a directory: '$Path'."
}

$logs = @(Get-ChildItem -LiteralPath $directory.FullName -Filter '*.log' -File -ErrorAction Stop)

[PSCustomObject]@{
    Path     = $Path
    LogCount = $logs.Count
}
