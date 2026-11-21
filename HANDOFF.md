# Handoff

Notes for resuming maintenance of this repository from any machine, by a person or an AI agent. Update this file at the end of a work session when anything below changes; the git log and CI show the live state, so this file records only what they don't.

## Check the current state first

Don't trust a status written here; ask git and GitHub:

```bash
git fetch main --tags
git status
git log --oneline -5
git tag --list 'v*' | sort -V | tail -1
gh run list --branch master --limit 3
```

This repository's remote is named `main`, and the branch is `master`.

Then check whether these notes are current:

```bash
# When were these notes last updated, and what has happened since?
git log -1 --format='%h %ad %s' --date=short -- HANDOFF.md
git log --oneline "$(git log -1 --format=%h -- HANDOFF.md)"..HEAD
```

If the second command lists any commits, this file may be out of date: read those commits before trusting it, and update it when you finish.

## Last session (2026-11-20)

- Released **v1.1.0** (stable guide filenames, checker fixes, analyzer settings, tiered agent workflow, reusable workflow, and `templates/AGENTS-powershell.md`).
- Since v1.1.0, unreleased: `RELEASING.md`; Mermaid conventions 1.0.12 and the audit scripts in `reference/scripts/`; top-down Mermaid diagrams in the README and `RELEASING.md`; a README rewrite so every section explains why it exists; `input/` ignored by git; this file. See `[Unreleased]` in [CHANGELOG.md](CHANGELOG.md).
- No release is scheduled for the unreleased changes. When one is, follow [RELEASING.md](RELEASING.md) exactly.
- Mermaid audit unit tests now have a separate Ubuntu CI job using Python 3.13 and PyYAML 6.0.4. The same install and test commands also work in a Python virtual environment on Debian 13, without browser dependencies.
- Checker boundary tests cover settings precedence, `.git` directory/file boundaries, and function scopes. Array-append detection now keeps script-level and function-local variable names separate; it remains a lexical heuristic rather than runtime type or control-flow analysis.
- Consumer template local commands now use the release-pinned checker and explicitly import the pinned analyzer/Pester versions. Seven consumer scenarios passed on the Debian 13 lab VM: clean code, lint failure, settings discovery, parser failure, informational findings, and passing/failing Pester tests. Downloaded tools stay outside the consumer repository.
- `examples/worked-review/` contains a read-only log-counting review. The same eight tests show four failures on the original and pass on the correction. The repository workflow now uses `pester-path: .` to discover checker and example tests together (31 total); the intentional original failures are run only through an explicit test-container override.
- `examples/pre-production-review/README.md` documents the intake-to-handoff workflow for ignored `input/` scripts. It supplies review/fix requests and report expectations, without implementing a watcher, report generator, or deployment automation.

## Rules the owner has set

- **`99_Archive/` is a local trash bin.** Files are moved there instead of deleted. It is in `.gitignore`: never commit it and never delete anything inside it. It may not exist on every machine.
- **Don't install tools without asking.** Give the owner the install command, and document it in the README if it's missing.
- **Don't commit, push, tag, or release unless asked.** Run each `git push` as its own command, never chained with other commands. Confirm before `gh release create`.
- **Never move a pushed tag.** Fix a published release by releasing a new version.
- **Mermaid diagrams flow top-down.** Use dagre (GitHub's default), with `direction TD` inside the white wrapper subgraph. Follow [reference/mermaid-best-practices.md](reference/mermaid-best-practices.md).
- **The Mermaid material is in scope.** It makes AI agents draw PowerShell flowcharts the same way every time, so missing branches, skipped cleanup, and bypassed `ShouldProcess` are easy to spot.
- **The README is written for readers with little experience.** Every section should say plainly why it exists.

## Setting up a new machine

- PowerShell 7, plus the PSScriptAnalyzer and Pester versions pinned in `.github/workflows/powershell-guide-check.yml`. The README lists the install commands.
- `gh` (GitHub CLI), signed in to the owner's account, to watch CI and create releases.
- Optional, only for diagram work:
  - `mmdc` (`npm install -g @mermaid-js/mermaid-cli`) renders diagrams. If it can't find a browser, point it at an installed Chromium with a Puppeteer config file such as `{"executablePath": "/usr/bin/chromium"}` and pass `-p <file>`.
  - The audit scripts need Python with PyYAML and Playwright. [reference/scripts/README.md](reference/scripts/README.md) has the commands. A virtual environment keeps them separate from the system Python.

## Tips learned the hard way

- For CI job logs, use `gh api repos/scufflegrits/powershellai/actions/jobs/<job-id>/logs`. `gh run view --log` returns nothing for jobs that run the called workflow.
- To check how GitHub renders a diagram, screenshot `iframe[src*="viewscreen"]` with a browser window taller than the diagram, or the capture comes out blank. See "Checking GitHub's rendering" in the Mermaid conventions.
- `Invoke-ScriptAnalyzer -Path` takes only one path, so the check script analyzes files one at a time.
- Pester 5 doesn't allow `BeforeEach` at the root of a test file; put it inside `Describe`.

## Optional ideas (offered, not requested)

- Reorder the README overview diagram so GitHub's zoom buttons don't cover the "This repository's CI" node.
- Add a secret scan (for example gitleaks) to the reusable workflow.
