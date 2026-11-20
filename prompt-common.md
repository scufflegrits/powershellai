# Shared Instructions for PowerShell AI Work

Use these instructions with both [prompt-review.md](prompt-review.md) and [prompt-create.md](prompt-create.md).

## Role and baseline rules

Act as a careful PowerShell engineer. Read [PowerShell Best Practices](powershell-best-practices.md) and follow it, including **§13 Rules for AI agents** and its guardrails: inspect first, trace before changing, keep the diff minimal, edit safely, audit the diff, verify honestly, and report precisely. Those rules are not repeated here; this prompt adds only the workflow on top of them.

Treat guide recommendations as defaults where the guide allows judgment. Explain meaningful exceptions. Avoid speculative or unrelated changes.

## Scale the effort to the task

Choose a workflow tier before starting and state which one you chose and why.

| Tier | Typical task | Workflow |
|------|--------------|----------|
| **Small** | One short script, a focused fix, or a review of under ~200 lines | Work alone. Do a separate verification pass after implementation: re-read the final diff against the checklist with fresh eyes and run the checks. |
| **Medium** | Several related files, a new script with tests, or a change to a public interface | Work alone or with one helper. Have one independent agent (or a clearly separated pass if delegation is unavailable) verify the stable diff. |
| **Large** | A module, cross-cutting changes, security-sensitive code, or multiple components | Use multiple agents as described below for both implementation and verification. |

Move up a tier when the task touches secrets, destructive operations, remote systems, or code that other teams depend on. Do not use extra agents only to appear thorough; more agents on a small input mostly repeat each other.

### Multi-agent workflow (large tier)

The coordinating agent owns the task, integrates changes, resolves conflicts, and is responsible for the final report.

**Work phase**

- Give each agent a distinct, non-overlapping area (for example: compatibility and API review, security and error handling, tests, documentation, or separate files).
- Give each agent the task, acceptance criteria, repository instructions, supported PowerShell targets, and this guide.
- Assign one implementation owner per file; other agents may review but not edit it.
- Ask agents to report findings, proposed edits, files touched, commands run, and open questions.
- The coordinator integrates the work and checks the combined diff before verification.

**Verification phase**

- Once the diff is stable, assign verifiers who did not implement the changes they check, each with a distinct focus (for example: behavior and Pester coverage, PSScriptAnalyzer and guide compliance, compatibility and security, or API and documentation consistency).
- Verifiers inspect the code and run checks independently, report findings with file/line references, severity, evidence, and command results, and do not edit.
- The coordinator triages findings. If fixes are needed, return to the work phase and verify the updated diff again.
- Agreement among agents is not proof. Resolve findings against source, tests, requirements, and documented behavior.

## Optional Mermaid diagram

For complex scripts with multiple branches, loops, external calls, errors, cleanup paths, or state-changing actions, create a Mermaid flowchart showing important decisions, side effects, failures, and cleanup. Skip diagrams for short, linear scripts.

Follow [the Mermaid conventions](reference/mermaid-best-practices.md), including its **For AI agents: verify before you deliver** steps: render the diagram and report whether it was rendered, parsed, or only read. Use one node per decision, side effect, or exit path, and label each branch with its condition (`yes`/`no`, `-WhatIf`, `catch`), so missing paths stand out. If `reference/scripts/audit_mermaid.py` can run, use it as well; otherwise follow the guide's manual checks.

Compare the diagram with the source and tests. Use it to look for unhandled branches, side effects that bypass validation or `ShouldProcess`, errors that skip cleanup, and unclear outcomes. The diagram is a review aid, not a substitute for source inspection or tests. Keep it accurate as code changes.

## Verification

- Use the repository's configured test and lint commands when available.
- Run focused Pester tests, then broader tests when appropriate. Run PSScriptAnalyzer with repository settings and the pinned version.
- Run `Invoke-PowerShellGuideCheck.ps1` if available; it covers only a mechanically verifiable subset of the guide.
- Use mocks, `$TestDrive`, and `-WhatIf` for side-effecting behavior.
- Do not install tools, contact external systems, or alter real services as part of verification unless explicitly authorized.

## Final report

- Summarize files changed and behavior affected.
- List the exact commands run, PowerShell edition/version, Pester and PSScriptAnalyzer versions, and actual outcomes, including pass/fail/skip counts.
- State the workflow tier used.
- State what could not be verified and why; list unresolved risks, assumptions, and decisions needing engineer judgment.

## Shared progress tracker

- [ ] Read the guide (including §13) and repository instructions.
- [ ] Chose a workflow tier and stated why.
- [ ] Confirmed PowerShell targets, platforms, and project conventions.
- [ ] For complex control flow, created and verified a Mermaid diagram; otherwise `N/A`.
- [ ] Ran applicable Pester, PSScriptAnalyzer, and guide checks; recorded exact results.
- [ ] Verified the stable final diff in a separate pass, or with independent agents for medium and large tasks; resolved findings and re-verified after fixes.
- [ ] Reviewed the final diff and reported changes, verification, limitations, and unresolved concerns.

Mark items complete only after doing them. Mark non-applicable items `N/A` with a brief reason, or blocked items `Blocked` with what is needed. Do not leave unchecked items unexplained in the final report.
