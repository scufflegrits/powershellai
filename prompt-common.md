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

## Checked-script header and fingerprint

For an authorized correction or a newly created script, include a checked-script record as the final delivery step. A review-only request does not authorize editing the original or adding a stamp to it. If the source already has a checked record, preserve it in the untouched reference copy. In an edited working copy, replace the active stamp with a clearly historical previous-check record and a current status of `Changed since previous check; re-review required`. Preserve user-authored change notes, but do not treat them as proof of the actual diff. The guide checker and CI do not add stamps automatically; the assistant follows this workflow.

1. Identify the PowerShellAI release actually used. If the working copy is unreleased, identify its commit and disclose local changes. Do not invent a release number or label an unreleased revision as the last published release.
2. Complete source review and the checks required for the agreed verification scope. Resolve blocking findings and failing checks. If required checks are unavailable or incomplete, deliver the report with that limitation and omit the stamp; do not silently narrow the scope to earn it.
3. Merge this record into the corrected/new script's existing comment-based help under `.NOTES`, preserving `#Requires`, other help, and the original script's own version information:

   ```text
   Checked by PowerShellAI <actual release or commit>
   Checked on (UTC): <YYYY-MM-DD>
   Verification report: <report path relative to this script>
   Verification scope: <the checks and environments actually covered>
   ```

   A released version uses wording such as `Checked by PowerShellAI vX.X.X`, with the real release substituted. An unreleased checkout uses `Checked by PowerShellAI commit <commit ID> (unreleased)`, adding `; local changes` when applicable. Record the actual scope, target platform, tool versions, results, and remaining limits in the report. The stamp records completed checks in that scope, not production approval.
4. Repeat the relevant static checks and tests on the final file including its header. If those fail, remove the new stamp, correct the problem, and repeat verification before delivery.
5. Compute SHA-256 over the final file bytes after all script edits and checks. Record that hash in the verification report and in an adjacent `<script filename>.sha256` file containing only the 64 hexadecimal characters (a trailing newline is allowed). Do not put the script's own hash inside the script. Include the PowerShellAI revision in the report; when local changes are involved, preserve the guide/prompt/settings snapshot or diff needed to identify the material used.
6. Deliver the script, tests, report, and fingerprint together. Explain how to compare the current script with the saved fingerprint and keep the reference report/fingerprint in a trusted location. Any subsequent script edit makes the old stamp stale; re-review and re-verify before issuing a refreshed record. Do not overwrite a saved fingerprint merely to make a mismatch disappear.

### Lab changes and re-review

- Lab testing remains a separate required step before production when it is outside the stamped verification scope. Record lab results against the checked file's hash. A completed scoped AI check is not a claim that lab validation has already passed.
- If lab testing requires no script edits, record the results in the external report or lab notes; the checked script and fingerprint stay unchanged. Do not claim successful lab validation without actual results.
- If a user edits a lab working copy, preserve the last checked copy, report, and fingerprint. In the working copy's help, retain the previous checker identity/date as history, mark re-review as required, and record dated changes with reasons and lab observations. Never leave the old stamp presented as a current check of the edited file.
- On a subsequent review, read the edited script, completed request, change notes, previous report, and previous checked copy or Git revision. Compare the actual files; a hash detects a difference but cannot explain it, and annotations may be incomplete. If the baseline is unavailable, state that limitation and review the full current source rather than pretending to reconstruct its changes.
- Apply only authorized corrections. After the required checks pass, issue a fresh active record and final hash for the new revision, retain the previous review records, and return the new copy for lab testing. Do not automatically promote it to production or silently replace the old baseline.

## Final report

- Summarize files changed and behavior affected.
- List the exact commands run, PowerShell edition/version, Pester and PSScriptAnalyzer versions, and actual outcomes, including pass/fail/skip counts.
- State the workflow tier used.
- State what could not be verified and why; list unresolved risks, assumptions, and decisions needing engineer judgment.
- For a checked corrected/new script, give the header identity, final SHA-256, report/fingerprint paths, and scope. Otherwise state why no checked-script record was issued.

## Shared progress tracker

- [ ] Read the guide (including §13) and repository instructions.
- [ ] Chose a workflow tier and stated why.
- [ ] Confirmed PowerShell targets, platforms, and project conventions.
- [ ] For complex control flow, created and verified a Mermaid diagram; otherwise `N/A`.
- [ ] Ran applicable Pester, PSScriptAnalyzer, and guide checks; recorded exact results.
- [ ] Verified the stable final diff in a separate pass, or with independent agents for medium and large tasks; resolved findings and re-verified after fixes.
- [ ] Reviewed the final diff and reported changes, verification, limitations, and unresolved concerns.
- [ ] For an authorized corrected/new script with completed required checks, added the checked header, rechecked the final file, and saved its SHA-256 in the report and adjacent fingerprint file; otherwise explained why no stamp was issued.

Mark items complete only after doing them. Mark non-applicable items `N/A` with a brief reason, or blocked items `Blocked` with what is needed. Do not leave unchecked items unexplained in the final report.
