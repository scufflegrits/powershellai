# Changelog

Notable changes to the guides and tools are recorded here.

## [Unreleased]

- Added the Pester and PSScriptAnalyzer focused guides.
- Added `Invoke-PowerShellGuideCheck.ps1` for PSScriptAnalyzer and selected AST checks.
- Added repository navigation, analyzer settings, and Pester tests for the guide-check script.
- Added the `input/` directory used by the script review prompt.
- Renamed guides to stable filenames without version suffixes; versions now live in each guide's `Guide version` header, this changelog, and git tags.
- Removed the combined testing and analysis index; the README and best-practices guide link the focused guides directly.
- Stopped tracking `99_Archive/`; earlier revisions are available from git history.

## [1.0.7] - 2026-11-19

- Published the PowerShell best-practices guide and companion testing/analysis guide revision 1.0.7.
- Clarified script process exit codes, `ShouldProcess` confirmation wording, and encoding defaults.
