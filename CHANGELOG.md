# Changelog

Notable changes to the guides and tools are recorded here.

## [Unreleased]

- Consumer instructions now download and run the release-pinned guide checker locally, select the pinned analyzer and Pester versions explicitly, and propagate failing checks instead of showing PSScriptAnalyzer alone.
- Guide checker: array-append detection now keeps script and function variable names separate, preventing false findings on unrelated counters. Added regression tests for sibling and nested functions, nearest and explicit settings, and repository boundaries with `.git` directories or files.
- CI now runs the Mermaid audit tool's unit tests in a separate Ubuntu job using Python 3.13 and pinned PyYAML 6.0.4; browser rendering remains a manual check.
- Added `HANDOFF.md` so a maintainer can resume work from another machine: how to check the current state, working rules, and setup tips.
- README: every section now explains plainly why it exists, with a short glossary of terms; clarified that the Pester tests check the check script, not your scripts; corrected where tool versions are pinned.
- `.gitignore`: files in `input/` are no longer committed, because scripts under review may contain internal names or secrets.
- README: explained that the Mermaid conventions exist so AI agents diagram scripts consistently, making unhandled paths easier to find during code review.
- Added `RELEASING.md` documenting the release process, including running each push as its own command.
- Added `reference/mermaid-best-practices.md` (Mermaid conventions 1.0.12), linked from the README and `prompt-common.md`.
- `prompt-common.md`: the Mermaid section now requires the conventions' agent verification steps, one node per decision, side effect, or exit path, and condition labels on every branch.
- Added optional Mermaid audit scripts in `reference/scripts/`: `audit_mermaid.py`, `opaque_svg.py`, unit tests, and probe fixtures with documented expected results.
- Added top-down Mermaid diagrams: repository overview, AI prompt workflow, guide checker, and reusable workflow in the README; release process in `RELEASING.md`.

## [1.1.0] - 2026-11-19

- Added the Pester and PSScriptAnalyzer focused guides.
- Added `Invoke-PowerShellGuideCheck.ps1` for PSScriptAnalyzer and selected AST checks.
- Added repository navigation, analyzer settings, and Pester tests for the guide-check script.
- Added a cross-platform GitHub Actions workflow for linting, guide checks, and Pester tests.
- Added the `input/` directory used by the script review prompt.
- Renamed guides to stable filenames without version suffixes; versions now live in each guide's `Guide version` header, this changelog, and git tags.
- Removed the combined testing and analysis index; the README and best-practices guide link the focused guides directly.
- Stopped tracking `99_Archive/`; earlier revisions are available from git history.
- Guide checker: removed the duplicate `Invoke-Expression` check (PSScriptAnalyzer's `PSAvoidUsingInvokeExpression` covers it).
- Guide checker: `GuideAvoidArrayAppend` now reports only `+=` on array-initialized variables inside loops or `ForEach-Object` blocks.
- Guide checker: supplemental findings honor `-Severity`; parse errors are always reported.
- Guide checker: the settings file is found by searching upward from the target path to the repository root instead of using the current directory.
- Guide checker: fixed a crash when analyzing more than one file (`Invoke-ScriptAnalyzer -Path` accepts a single path).
- Guide checker: findings print as one `path:line:column: [Severity] Rule: message` line each, so output does not depend on console width.
- Tests: moved `BeforeEach` inside `Describe` (Pester v5 rejects it at the file root) and added a scoped, justified suppression for Pester `BeforeAll` variables.
- Analyzer settings now enable PowerShell 7.0 syntax compatibility and brace, indentation, whitespace, and alignment rules, replacing entries that only re-enabled default rules.
- Prompts: replaced the always-multi-agent workflow with small, medium, and large tiers, and removed rules duplicated from guide §13.
- Best-practices guide §13: added the rule not to commit, push, publish, or deploy unless asked (previously only in the prompt).
- Documented the commands for installing the CI-pinned PSScriptAnalyzer and Pester versions.
- Added a reusable GitHub Actions workflow (`powershell-guide-check.yml`) that other repositories can call at a pinned tag; this repository's CI now uses it.
- CI uses `actions/checkout@v7` (Node.js 24); v4 targeted the deprecated Node.js 20 runtime.
- Added `templates/AGENTS-powershell.md`, a section to copy into other repositories' agent instructions.

## [1.0.7] - 2026-11-19

- Published the PowerShell best-practices guide and companion testing/analysis guide revision 1.0.7.
- Clarified script process exit codes, `ShouldProcess` confirmation wording, and encoding defaults.
